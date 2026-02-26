import AVFoundation
import Accelerate

struct WaveformGenerator {
    static func generate(from buffer: AVAudioPCMBuffer, targetSampleCount: Int) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, targetSampleCount > 0 else { return [] }

        let samplesPerPixel = frameCount / targetSampleCount
        guard samplesPerPixel > 0 else {
            // Fewer frames than pixels — return raw magnitudes
            return (0..<frameCount).map { abs(channelData[$0]) }
        }

        var result = [Float](repeating: 0, count: targetSampleCount)

        for i in 0..<targetSampleCount {
            let start = i * samplesPerPixel
            let count = min(samplesPerPixel, frameCount - start)
            guard count > 0 else { break }

            var rms: Float = 0
            var slice = UnsafeBufferPointer(start: channelData + start, count: count)
            vDSP_rmsqv(slice.baseAddress!, 1, &rms, vDSP_Length(count))
            result[i] = rms
        }

        // Normalize to [0, 1]
        guard let maxVal = result.max(), maxVal > 0 else { return result }
        return result.map { $0 / maxVal }
    }

    static func generate(from url: URL, targetSampleCount: Int) -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return [] }
        try? audioFile.read(into: buffer)
        return generate(from: buffer, targetSampleCount: targetSampleCount)
    }
}
