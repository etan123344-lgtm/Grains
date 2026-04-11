import Foundation
import os

// MARK: - Stereo Delay / Echo Engine

final class EchoEngine {

    struct Parameters {
        var isEnabled: Bool = false
        var delayTime: Float = 300      // ms (1–2000)
        var feedback: Float = 0.4       // 0–0.95
        var wetDry: Float = 0.3         // 0 = fully dry, 1 = fully wet
        var stereoSpread: Float = 0.0   // 0–1, right channel delay offset
        var tone: Float = 0.5           // 0–1, lowpass darkening on repeats (0 = dark, 1 = bright)
    }

    // MARK: - Private State

    private var activeParams = Parameters()
    private var pendingParams = Parameters()
    private var hasPending = false
    private let lock = OSAllocatedUnfairLock()

    private var sampleRate: Float = 44100

    // Max delay: 2 seconds
    private static let maxDelaySeconds: Float = 2.0

    private var delayL = DelayLine()
    private var delayR = DelayLine()

    // One-pole lowpass state in the feedback path (per channel)
    private var lpStateL: Float = 0
    private var lpStateR: Float = 0

    // MARK: - Configuration

    func configure(sampleRate: Float) {
        self.sampleRate = sampleRate

        let maxSamples = Int(EchoEngine.maxDelaySeconds * sampleRate) + 1
        delayL = DelayLine(maxDelay: maxSamples)
        delayR = DelayLine(maxDelay: maxSamples)

        lpStateL = 0
        lpStateR = 0
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

        // Clamp feedback to keep the loop stable
        let feedback = min(max(params.feedback, 0), 0.95)

        // Tone -> lowpass coefficient. tone=1 (bright) => damp=0, tone=0 (dark) => damp~0.95
        let damp = (1.0 - min(max(params.tone, 0), 1)) * 0.95

        // Delay times in samples
        let delayMs = min(max(params.delayTime, 1), EchoEngine.maxDelaySeconds * 1000)
        let delaySamplesL = Int(delayMs * sampleRate / 1000.0)

        // Right channel offset: spread of 1.0 lengthens R delay by up to 50%
        let spread = min(max(params.stereoSpread, 0), 1)
        let delaySamplesR = Int(delayMs * (1.0 + spread * 0.5) * sampleRate / 1000.0)

        delayL.delayLength = min(delaySamplesL, delayL.maxDelay)
        delayR.delayLength = min(delaySamplesR, delayR.maxDelay)

        for frame in 0..<frameCount {
            let inL = inputL[frame]
            let inR = inputR[frame]

            // Read delayed samples
            let delayedL = delayL.read()
            let delayedR = delayR.read()

            // One-pole lowpass on the delayed signal (in feedback path)
            lpStateL = delayedL * (1.0 - damp) + lpStateL * damp
            lpStateR = delayedR * (1.0 - damp) + lpStateR * damp

            // Guard against NaN/Inf corrupting the feedback loop permanently
            if !lpStateL.isFinite { lpStateL = 0 }
            if !lpStateR.isFinite { lpStateR = 0 }

            // Write input + filtered feedback into the delay line
            delayL.write(sample: inL + lpStateL * feedback)
            delayR.write(sample: inR + lpStateR * feedback)

            // Mix dry + wet (wet = the delayed/filtered signal)
            inputL[frame] = dry * inL + wet * lpStateL
            inputR[frame] = dry * inR + wet * lpStateR
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

        mutating func read() -> Float {
            var readIndex = writeIndex - delayLength
            if readIndex < 0 { readIndex += buffer.count }
            return buffer[readIndex]
        }

        mutating func write(sample: Float) {
            buffer[writeIndex] = sample
            writeIndex += 1
            if writeIndex >= buffer.count { writeIndex = 0 }
        }
    }
}
