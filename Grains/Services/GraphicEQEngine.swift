import Foundation
import os

// MARK: - Graphic EQ Band Definitions

enum EQBand: Int, CaseIterable {
    case hz60 = 0, hz170, hz310, hz600, khz1, khz3, khz6, khz12

    var frequency: Float {
        switch self {
        case .hz60: return 60
        case .hz170: return 170
        case .hz310: return 310
        case .hz600: return 600
        case .khz1: return 1000
        case .khz3: return 3000
        case .khz6: return 6000
        case .khz12: return 12000
        }
    }

    var displayName: String {
        switch self {
        case .hz60: return "60"
        case .hz170: return "170"
        case .hz310: return "310"
        case .hz600: return "600"
        case .khz1: return "1K"
        case .khz3: return "3K"
        case .khz6: return "6K"
        case .khz12: return "12K"
        }
    }

    var q: Float {
        // Slightly narrower Q at extremes, broader in the mids — typical graphic EQ
        switch self {
        case .hz60: return 1.4
        case .hz170: return 1.4
        case .hz310: return 1.5
        case .hz600: return 1.5
        case .khz1: return 1.5
        case .khz3: return 1.5
        case .khz6: return 1.4
        case .khz12: return 1.4
        }
    }
}

// MARK: - GraphicEQEngine

final class GraphicEQEngine {

    static let bandCount = 8

    struct Parameters {
        var isEnabled: Bool = false
        var gains: [Float] = [Float](repeating: 0, count: bandCount)  // -12 to +12 dB per band
    }

    // MARK: - Private State

    private var activeParams = Parameters()
    private var pendingParams = Parameters()
    private var hasPending = false
    private let lock = OSAllocatedUnfairLock()

    private var sampleRate: Float = 44100

    // Biquad filter states — stereo, one per band
    private var statesL = [BiquadState](repeating: BiquadState(), count: bandCount)
    private var statesR = [BiquadState](repeating: BiquadState(), count: bandCount)
    private var coeffs = [BiquadCoeffs](repeating: BiquadCoeffs.passthrough(), count: bandCount)

    // MARK: - Configuration

    func configure(sampleRate: Float) {
        self.sampleRate = sampleRate
        resetState()
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
        updateCoefficients(params: params)

        for frame in 0..<frameCount {
            var sampleL = inputL[frame]
            var sampleR = inputR[frame]

            for s in 0..<GraphicEQEngine.bandCount {
                sampleL = biquadProcess(sample: sampleL, state: &statesL[s], coeffs: coeffs[s])
                sampleR = biquadProcess(sample: sampleR, state: &statesR[s], coeffs: coeffs[s])
            }

            inputL[frame] = sampleL
            inputR[frame] = sampleR
        }
    }

    // MARK: - Coefficient Calculation

    private func updateCoefficients(params: Parameters) {
        for band in EQBand.allCases {
            let i = band.rawValue
            let gain = params.gains[i]
            if abs(gain) > 0.05 {
                coeffs[i] = makePeakingCoeffs(freq: band.frequency, gainDB: gain, q: band.q, sampleRate: sampleRate)
            } else {
                coeffs[i] = BiquadCoeffs.passthrough()
            }
        }
    }

    // MARK: - Biquad Filter

    private struct BiquadState {
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0
    }

    private struct BiquadCoeffs {
        var b0: Float = 1, b1: Float = 0, b2: Float = 0
        var a1: Float = 0, a2: Float = 0

        static func passthrough() -> BiquadCoeffs {
            BiquadCoeffs(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)
        }
    }

    private func biquadProcess(sample: Float, state: inout BiquadState, coeffs: BiquadCoeffs) -> Float {
        let y = coeffs.b0 * sample + coeffs.b1 * state.x1 + coeffs.b2 * state.x2
              - coeffs.a1 * state.y1 - coeffs.a2 * state.y2
        state.x2 = state.x1
        state.x1 = sample
        state.y2 = state.y1
        state.y1 = y
        return y
    }

    // MARK: - Peaking EQ (Audio EQ Cookbook)

    private func makePeakingCoeffs(freq: Float, gainDB: Float, q: Float, sampleRate: Float) -> BiquadCoeffs {
        let A = powf(10.0, gainDB / 40.0)
        let omega = 2.0 * Float.pi * freq / sampleRate
        let sinW = sinf(omega)
        let cosW = cosf(omega)
        let alpha = sinW / (2.0 * q)

        let a0 = 1.0 + alpha / A
        let a1v = -2.0 * cosW
        let a2v = 1.0 - alpha / A
        let b0v = 1.0 + alpha * A
        let b1v = -2.0 * cosW
        let b2v = 1.0 - alpha * A

        return BiquadCoeffs(
            b0: b0v / a0, b1: b1v / a0, b2: b2v / a0,
            a1: a1v / a0, a2: a2v / a0
        )
    }

    // MARK: - State Reset

    private func resetState() {
        for i in 0..<GraphicEQEngine.bandCount {
            statesL[i] = BiquadState()
            statesR[i] = BiquadState()
            coeffs[i] = BiquadCoeffs.passthrough()
        }
    }
}
