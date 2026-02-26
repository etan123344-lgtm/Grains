import AVFoundation
import Observation

@Observable
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let varispeed = AVAudioUnitVarispeed()

    private var fullBuffer: AVAudioPCMBuffer?
    private var audioFormat: AVAudioFormat?

    private(set) var isPlaying = false
    private(set) var currentFile: URL?

    init() {
        engine.attach(playerNode)
        engine.attach(varispeed)
    }

    func loadFile(url: URL) throws {
        stop()

        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }
        try audioFile.read(into: buffer)
        
         // Reconnect nodes with the loaded file's format to avoid format mismatch crashes
         engine.disconnectNodeOutput(playerNode)
         engine.disconnectNodeOutput(varispeed)
         engine.connect(playerNode, to: varispeed, format: format)
         engine.connect(varispeed, to: engine.mainMixerNode, format: format)

        fullBuffer = buffer
        audioFormat = format
        currentFile = url
    }

    func play(loopStart: Double, loopEnd: Double, isReversed: Bool, pitchSemitones: Float) {
        guard let fullBuffer, let audioFormat else { return }

        let sampleRate = audioFormat.sampleRate
        let startFrame = AVAudioFramePosition(loopStart * sampleRate)
        let endFrame = AVAudioFramePosition(loopEnd * sampleRate)
        let totalFrames = AVAudioFrameCount(fullBuffer.frameLength)

        let clampedStart = max(0, min(startFrame, AVAudioFramePosition(totalFrames)))
        let clampedEnd = max(clampedStart, min(endFrame, AVAudioFramePosition(totalFrames)))
        let loopFrameCount = AVAudioFrameCount(clampedEnd - clampedStart)

        guard loopFrameCount > 0 else { return }

        guard let loopBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: loopFrameCount) else { return }
        loopBuffer.frameLength = loopFrameCount

        let channelCount = Int(audioFormat.channelCount)
        for ch in 0..<channelCount {
            guard let src = fullBuffer.floatChannelData?[ch],
                  let dst = loopBuffer.floatChannelData?[ch] else { continue }
            if isReversed {
                for i in 0..<Int(loopFrameCount) {
                    dst[i] = src[Int(clampedStart) + Int(loopFrameCount) - 1 - i]
                }
            } else {
                for i in 0..<Int(loopFrameCount) {
                    dst[i] = src[Int(clampedStart) + i]
                }
            }
        }

        varispeed.rate = pow(2.0, pitchSemitones / 12.0)

        playerNode.stop()

        if !engine.isRunning {
            try? engine.start()
        }

        playerNode.scheduleBuffer(loopBuffer, at: nil, options: .loops)
        playerNode.play()
        isPlaying = true
    }

    func stop() {
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
    }

    func setPitch(_ semitones: Float) {
        varispeed.rate = pow(2.0, semitones / 12.0)
    }

    func getFullBuffer() -> AVAudioPCMBuffer? {
        fullBuffer
    }

    func getSampleRate() -> Double? {
        audioFormat?.sampleRate
    }
}

enum AudioEngineError: Error, LocalizedError {
    case bufferCreationFailed

    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        }
    }
}
