import Accelerate
import os

// MARK: - Supporting Types

enum ShiftDirection: Int, Codable, CaseIterable {
    case forward = 0
    case backward = 1
    case random = 2
}

// MARK: - GrainEngine

final class GrainEngine {

    struct Parameters {
        var grainRate: Float = 10.0          // grains per second
        var grainDuration: Float = 0.1       // seconds
        var shiftSpeed: Float = 1.0          // multiplier
        var shiftDirection: ShiftDirection = .forward
        var attackProportion: Float = 0.25   // 0–0.5
        var releaseProportion: Float = 0.25  // 0–0.5
        var startPosition: Int = 0           // frames
        var endPosition: Int = 0             // frames
        var noteAttack: Float = 0.01         // seconds
        var noteRelease: Float = 0.3         // seconds
    }

    // MARK: - Public readable state

    var density: Float {
        lock.withLock { activeParams.grainDuration * activeParams.grainRate }
    }

    // MARK: - Private state

    private static let maxVoices = 32

    private var voices = [GrainVoice](repeating: GrainVoice(), count: maxVoices)
    private var nextBirthOrder: UInt64 = 0

    // Source buffer pointers (set while engine is stopped)
    private var sourceL: UnsafePointer<Float>?
    private var sourceR: UnsafePointer<Float>?
    private var sourceFrameCount: Int = 0
    private var sourceChannelCount: Int = 0
    private var sampleRate: Float = 44100

    // Playback head (frame position within source, float for sub-frame precision)
    private var playbackHead: Float = 0

    // Grain clock
    private var grainClockCounter: Int = 0
    private var grainClockPeriod: Int = 4410  // frames between grain triggers

    // Note envelope
    private var notePhase: NoteEnvelopePhase = .idle
    private var noteLevel: Float = 0
    private var noteAttackIncrement: Float = 0
    private var noteReleaseDecrement: Float = 0

    // Thread-safe parameter swap
    private var activeParams = Parameters()
    private var pendingParams = Parameters()
    private var hasPending = false
    private let lock = OSAllocatedUnfairLock()

    // Temp buffer for vvtanhf
    private var tanhBuffer = [Float]()

    // MARK: - Configuration (main thread, engine stopped)

    func configure(
        sourceL: UnsafePointer<Float>,
        sourceR: UnsafePointer<Float>?,
        frameCount: Int,
        channelCount: Int,
        sampleRate: Float
    ) {
        self.sourceL = sourceL
        self.sourceR = sourceR
        self.sourceFrameCount = frameCount
        self.sourceChannelCount = channelCount
        self.sampleRate = sampleRate
    }

    // MARK: - Thread-safe parameter update (main thread)

    func setParameters(_ block: (inout Parameters) -> Void) {
        lock.withLock {
            block(&pendingParams)
            hasPending = true
        }
    }

    // MARK: - Note control (main thread)

    func noteOn() {
        lock.withLock {
            // Snapshot pending into active before starting
            if hasPending {
                activeParams = pendingParams
                hasPending = false
            }
        }
        // Reset playback state
        playbackHead = Float(activeParams.startPosition)
        grainClockCounter = 0
        grainClockPeriod = max(1, Int(sampleRate / max(activeParams.grainRate, 0.01)))
        nextBirthOrder = 0

        // Deactivate all voices
        for i in 0..<GrainEngine.maxVoices {
            voices[i].isActive = false
        }

        // Compute note envelope increments
        let attackFrames = max(1, activeParams.noteAttack * sampleRate)
        noteAttackIncrement = 1.0 / attackFrames
        let releaseFrames = max(1, activeParams.noteRelease * sampleRate)
        noteReleaseDecrement = 1.0 / releaseFrames
        noteLevel = 0
        notePhase = .attack
    }

    func noteOff() {
        notePhase = .release
    }

    // MARK: - Render (audio thread)

    func render(outputL: UnsafeMutablePointer<Float>,
                outputR: UnsafeMutablePointer<Float>,
                frameCount: Int) -> Float {

        guard sourceL != nil, sourceFrameCount > 0 else {
            // Silence
            memset(outputL, 0, frameCount * MemoryLayout<Float>.size)
            memset(outputR, 0, frameCount * MemoryLayout<Float>.size)
            return 0
        }

        // Snapshot params
        lock.withLock {
            if hasPending {
                activeParams = pendingParams
                hasPending = false
            }
        }

        let params = activeParams

        // Update grain clock period from rate
        grainClockPeriod = max(1, Int(sampleRate / max(params.grainRate, 0.01)))

        let regionLength = max(1, params.endPosition - params.startPosition)
        let grainLengthFrames = max(1, Int(params.grainDuration * sampleRate))
        let attackFrames = max(1, Int(params.attackProportion * Float(grainLengthFrames)))
        let releaseFrames = max(1, Int(params.releaseProportion * Float(grainLengthFrames)))

        // Zero output buffers
        memset(outputL, 0, frameCount * MemoryLayout<Float>.size)
        memset(outputR, 0, frameCount * MemoryLayout<Float>.size)

        // Frame-by-frame rendering
        for frame in 0..<frameCount {
            // Advance note envelope
            switch notePhase {
            case .idle:
                break
            case .attack:
                noteLevel = min(1.0, noteLevel + noteAttackIncrement)
                if noteLevel >= 1.0 {
                    notePhase = .sustain
                }
            case .sustain:
                noteLevel = 1.0
            case .release:
                noteLevel = max(0.0, noteLevel - noteReleaseDecrement)
                if noteLevel <= 0.0 {
                    notePhase = .idle
                    // Deactivate all voices
                    for i in 0..<GrainEngine.maxVoices {
                        voices[i].isActive = false
                    }
                }
            }

            if notePhase == .idle { continue }

            // Grain clock — trigger new grain
            if grainClockCounter <= 0 {
                triggerGrain(
                    grainLength: grainLengthFrames,
                    attackFrames: attackFrames,
                    releaseFrames: releaseFrames,
                    regionLength: regionLength,
                    params: params
                )
                grainClockCounter = grainClockPeriod
            }
            grainClockCounter -= 1

            // Sum all active voices
            var sampleL: Float = 0
            var sampleR: Float = 0

            for i in 0..<GrainEngine.maxVoices {
                guard voices[i].isActive else { continue }

                // Per-grain trapezoidal envelope
                let cf = voices[i].currentFrame
                let gl = voices[i].grainLength
                var env: Float = 1.0

                if cf < voices[i].attackFrames {
                    env = Float(cf + 1) / Float(voices[i].attackFrames)
                } else if cf >= gl - voices[i].releaseFrames {
                    let framesFromEnd = gl - cf
                    env = Float(framesFromEnd) / Float(voices[i].releaseFrames)
                }

                // Read source at voice position
                var readPos = voices[i].sourcePosition + (voices[i].playbackDirection == 1 ? cf : -cf)

                // Wrap within region
                if regionLength > 0 {
                    let start = params.startPosition
                    readPos = start + ((readPos - start) % regionLength + regionLength) % regionLength
                }

                // Clamp to source bounds
                let clampedPos = max(0, min(readPos, sourceFrameCount - 1))

                let gain = env * noteLevel
                sampleL += sourceL![clampedPos] * gain
                if let srcR = sourceR, sourceChannelCount > 1 {
                    sampleR += srcR[clampedPos] * gain
                } else {
                    sampleR += sourceL![clampedPos] * gain
                }

                // Advance voice
                voices[i].currentFrame += 1
                if voices[i].currentFrame >= voices[i].grainLength {
                    voices[i].isActive = false
                }
            }

            outputL[frame] = sampleL
            outputR[frame] = sampleR
        }

        // Soft limiter via tanh
        if tanhBuffer.count < frameCount {
            tanhBuffer = [Float](repeating: 0, count: frameCount)
        }

        var countL = Int32(frameCount)
        vvtanhf(outputL, outputL, &countL)
        var countR = Int32(frameCount)
        vvtanhf(outputR, outputR, &countR)

        // Return peak for metering
        var peak: Float = 0
        vDSP_maxv(outputL, 1, &peak, vDSP_Length(frameCount))
        var peakR: Float = 0
        vDSP_maxv(outputR, 1, &peakR, vDSP_Length(frameCount))
        return max(peak, peakR)
    }

    // MARK: - Grain Trigger (audio thread)

    private func triggerGrain(
        grainLength: Int,
        attackFrames: Int,
        releaseFrames: Int,
        regionLength: Int,
        params: Parameters
    ) {
        // Find free voice or steal oldest
        var targetIndex = -1
        var oldestBirth: UInt64 = .max

        for i in 0..<GrainEngine.maxVoices {
            if !voices[i].isActive {
                targetIndex = i
                break
            }
            if voices[i].birthOrder < oldestBirth {
                oldestBirth = voices[i].birthOrder
                targetIndex = i
            }
        }

        guard targetIndex >= 0 else { return }

        let direction: Int
        switch params.shiftDirection {
        case .forward:
            direction = 1
        case .backward:
            direction = -1
        case .random:
            direction = Bool.random() ? 1 : -1
        }

        var grainStart = Int(playbackHead)

        if params.shiftDirection == .random {
            // Randomize position within region
            grainStart = params.startPosition + Int.random(in: 0..<max(1, regionLength))
        }

        voices[targetIndex] = GrainVoice(
            isActive: true,
            sourcePosition: grainStart,
            grainLength: grainLength,
            currentFrame: 0,
            attackFrames: attackFrames,
            releaseFrames: releaseFrames,
            birthOrder: nextBirthOrder,
            playbackDirection: direction
        )
        nextBirthOrder += 1

        // Advance playback head
        let advance = params.shiftSpeed * Float(grainLength)
        switch params.shiftDirection {
        case .forward:
            playbackHead += advance
        case .backward:
            playbackHead -= advance
        case .random:
            playbackHead += advance // still advances for random, position randomized per grain
        }

        // Wrap head within region
        let startF = Float(params.startPosition)
        let regionF = Float(regionLength)
        if regionF > 0 {
            playbackHead = startF + (playbackHead - startF).truncatingRemainder(dividingBy: regionF)
            if playbackHead < startF {
                playbackHead += regionF
            }
        }
    }
}

// MARK: - GrainVoice

private struct GrainVoice {
    var isActive: Bool = false
    var sourcePosition: Int = 0
    var grainLength: Int = 0
    var currentFrame: Int = 0
    var attackFrames: Int = 0
    var releaseFrames: Int = 0
    var birthOrder: UInt64 = 0
    var playbackDirection: Int = 1  // 1 = forward, -1 = backward
}

// MARK: - NoteEnvelopePhase

private enum NoteEnvelopePhase {
    case idle
    case attack
    case sustain
    case release
}
