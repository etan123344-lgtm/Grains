import AVFoundation
import Accelerate

struct WaveformGenerator {
    static func generateWaveform(from buffer: AVAudioPCMBuffer, targetSampleCount: Int) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, targetSampleCount > 0 else { return [] }

        let samplesPerBin = frameCount / targetSampleCount
        guard samplesPerBin > 0 else { return [] }

        var result = [Float](repeating: 0, count: targetSampleCount)
        for i in 0..<targetSampleCount {
            let start = i * samplesPerBin
            let count = min(samplesPerBin, frameCount - start)
            guard count > 0 else { break }
            var rms: Float = 0
            vDSP_rmsqv(channelData.advanced(by: start), 1, &rms, vDSP_Length(count))
            result[i] = rms
        }

        // Normalize to 0...1
        var peak: Float = 0
        vDSP_maxv(result, 1, &peak, vDSP_Length(result.count))
        if peak > 0 {
            vDSP_vsdiv(result, 1, &peak, &result, 1, vDSP_Length(result.count))
        }
        return result
    }
}
