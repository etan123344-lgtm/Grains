import Foundation
import os

// MARK: - Schroeder/Moorer Reverb Engine

final class ReverbEngine {

    struct Parameters {
        var isEnabled: Bool = false
        var roomSize: Float = 0.5      // 0–1 (scales comb delay times)
        var damping: Float = 0.5       // 0–1 (lowpass in comb feedback)
        var wetDry: Float = 0.3        // 0–1 (0 = fully dry, 1 = fully wet)
        var preDelay: Float = 20       // 0–100 ms
    }

    // MARK: - Private State

    private var activeParams = Parameters()
    private var pendingParams = Parameters()
    private var hasPending = false
    private let lock = OSAllocatedUnfairLock()

    private var sampleRate: Float = 44100

    // 6 lowpass-feedback comb filters (Moorer style) — stereo
    private static let combCount = 6
    // Base delay times in ms (Moorer-inspired, prime-ish spacing)
    private static let baseDelaysMs: [Float] = [29.7, 37.1, 41.1, 43.7, 47.0, 50.3]

    private var combsL = [CombFilter]()
    private var combsR = [CombFilter]()

    // 2 allpass filters in series — stereo
    private static let allpassCount = 2
    private static let allpassDelaysMs: [Float] = [5.0, 1.7]
    private static let allpassGain: Float = 0.7

    private var allpassesL = [AllpassFilter]()
    private var allpassesR = [AllpassFilter]()

    // Pre-delay line — stereo
    private var preDelayL = DelayLine()
    private var preDelayR = DelayLine()

    // MARK: - Configuration

    func configure(sampleRate: Float) {
        self.sampleRate = sampleRate

        // Allocate comb filters with max delay (roomSize=1 scales to 1.5x base)
        combsL = ReverbEngine.baseDelaysMs.map { ms in
            let maxSamples = Int(ms * 1.5 * sampleRate / 1000.0) + 1
            return CombFilter(maxDelay: maxSamples)
        }
        combsR = ReverbEngine.baseDelaysMs.map { ms in
            let maxSamples = Int(ms * 1.5 * sampleRate / 1000.0) + 1
            return CombFilter(maxDelay: maxSamples)
        }

        // Slightly detune right channel comb delays for stereo width
        // (applied when computing delay lengths in process)

        // Allocate allpass filters
        allpassesL = ReverbEngine.allpassDelaysMs.map { ms in
            let samples = Int(ms * sampleRate / 1000.0) + 1
            return AllpassFilter(maxDelay: samples)
        }
        allpassesR = ReverbEngine.allpassDelaysMs.map { ms in
            let samples = Int(ms * sampleRate / 1000.0) + 1
            return AllpassFilter(maxDelay: samples)
        }

        // Pre-delay: max 100ms
        let maxPreDelay = Int(0.1 * sampleRate) + 1
        preDelayL = DelayLine(maxDelay: maxPreDelay)
        preDelayR = DelayLine(maxDelay: maxPreDelay)
    }

    // MARK: - Thread-safe parameter update

    func setParameters(_ block: (inout Parameters) -> Void) {
        lock.withLock {
            block(&pendingParams)
            hasPending = true
        }
    }

    // MARK: - Process (audio thread)

    func process(inputL: UnsafeMutablePointer<Float>,
                 inputR: UnsafeMutablePointer<Float>,
                 frameCount: Int) {

        lock.withLock {
            if hasPending {
                activeParams = pendingParams
                hasPending = false
            }
        }

        guard activeParams.isEnabled else { return }

        let params = activeParams
        let wet = params.wetDry
        let dry = 1.0 - wet

        // Compute comb filter parameters from room size + damping
        let roomScale = 0.5 + params.roomSize * 1.0  // 0.5x to 1.5x base delay
        let feedback = 0.7 + params.roomSize * 0.25   // 0.7 to 0.95
        let damp = params.damping

        // Pre-delay in samples
        let preDelaySamples = Int(params.preDelay * sampleRate / 1000.0)

        // Set comb delay lengths
        for i in 0..<ReverbEngine.combCount {
            let baseMs = ReverbEngine.baseDelaysMs[i]
            let delaySamplesL = Int(baseMs * roomScale * sampleRate / 1000.0)
            // Slight stereo offset on right channel (+~3% longer)
            let delaySamplesR = Int(baseMs * roomScale * 1.03 * sampleRate / 1000.0)
            combsL[i].delayLength = min(delaySamplesL, combsL[i].maxDelay)
            combsR[i].delayLength = min(delaySamplesR, combsR[i].maxDelay)
            combsL[i].feedback = feedback
            combsR[i].feedback = feedback
            combsL[i].damping = damp
            combsR[i].damping = damp
        }

        // Set allpass delay lengths
        for i in 0..<ReverbEngine.allpassCount {
            let ms = ReverbEngine.allpassDelaysMs[i]
            let samples = Int(ms * sampleRate / 1000.0)
            allpassesL[i].delayLength = min(samples, allpassesL[i].maxDelay)
            allpassesR[i].delayLength = min(samples, allpassesR[i].maxDelay)
        }

        preDelayL.delayLength = min(preDelaySamples, preDelayL.maxDelay)
        preDelayR.delayLength = min(preDelaySamples, preDelayR.maxDelay)

        for frame in 0..<frameCount {
            let inL = inputL[frame]
            let inR = inputR[frame]

            // Pre-delay
            let pdL = preDelayL.process(sample: inL)
            let pdR = preDelayR.process(sample: inR)

            // Sum of parallel comb filters
            var combSumL: Float = 0
            var combSumR: Float = 0
            for i in 0..<ReverbEngine.combCount {
                combSumL += combsL[i].process(sample: pdL)
                combSumR += combsR[i].process(sample: pdR)
            }

            // Scale down the comb sum
            let scale: Float = 1.0 / Float(ReverbEngine.combCount)
            combSumL *= scale
            combSumR *= scale

            // Series allpass filters for diffusion
            var wetL = combSumL
            var wetR = combSumR
            for i in 0..<ReverbEngine.allpassCount {
                wetL = allpassesL[i].process(sample: wetL, gain: ReverbEngine.allpassGain)
                wetR = allpassesR[i].process(sample: wetR, gain: ReverbEngine.allpassGain)
            }

            // Mix dry + wet
            inputL[frame] = dry * inL + wet * wetL
            inputR[frame] = dry * inR + wet * wetR
        }
    }

    // MARK: - Delay Line

    private struct DelayLine {
        var buffer: [Float]
        var writeIndex: Int = 0
        var delayLength: Int = 0
        let maxDelay: Int

        init(maxDelay: Int = 1) {
            self.maxDelay = maxDelay
            self.buffer = [Float](repeating: 0, count: maxDelay + 1)
        }

        mutating func process(sample: Float) -> Float {
            buffer[writeIndex] = sample
            var readIndex = writeIndex - delayLength
            if readIndex < 0 { readIndex += buffer.count }
            let output = buffer[readIndex]
            writeIndex += 1
            if writeIndex >= buffer.count { writeIndex = 0 }
            return output
        }
    }

    // MARK: - Lowpass-Feedback Comb Filter (Moorer)

    private struct CombFilter {
        var buffer: [Float]
        var writeIndex: Int = 0
        var delayLength: Int = 0
        let maxDelay: Int
        var feedback: Float = 0.8
        var damping: Float = 0.5
        var lpState: Float = 0  // one-pole lowpass state in feedback path

        init(maxDelay: Int) {
            self.maxDelay = maxDelay
            self.buffer = [Float](repeating: 0, count: maxDelay + 1)
        }

        mutating func process(sample: Float) -> Float {
            var readIndex = writeIndex - delayLength
            if readIndex < 0 { readIndex += buffer.count }
            let delayed = buffer[readIndex]

            // One-pole lowpass in feedback loop: y = (1-damp)*x + damp*y_prev
            lpState = delayed * (1.0 - damping) + lpState * damping

            // Guard against NaN/Inf corrupting the feedback loop permanently
            if !lpState.isFinite { lpState = 0 }

            // Write input + filtered feedback back into the delay line
            buffer[writeIndex] = sample + lpState * feedback

            writeIndex += 1
            if writeIndex >= buffer.count { writeIndex = 0 }

            // Return only the filtered feedback (not the delayed input),
            // so at 100% wet the direct signal is fully removed
            return lpState * feedback
        }
    }

    // MARK: - Allpass Filter

    private struct AllpassFilter {
        var buffer: [Float]
        var writeIndex: Int = 0
        var delayLength: Int = 0
        let maxDelay: Int

        init(maxDelay: Int) {
            self.maxDelay = maxDelay
            self.buffer = [Float](repeating: 0, count: maxDelay + 1)
        }

        mutating func process(sample: Float, gain: Float) -> Float {
            var readIndex = writeIndex - delayLength
            if readIndex < 0 { readIndex += buffer.count }
            let delayed = buffer[readIndex]

            let output = -gain * sample + delayed
            buffer[writeIndex] = sample + gain * delayed

            writeIndex += 1
            if writeIndex >= buffer.count { writeIndex = 0 }
            return output
        }
    }
}
