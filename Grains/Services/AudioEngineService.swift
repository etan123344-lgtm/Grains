import AVFoundation
import Observation

@Observable
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let varispeed = AVAudioUnitVarispeed()

    private var sourceNode: AVAudioSourceNode?
    let grainEngine = GrainEngine()
    let graphicEQ = GraphicEQEngine()
    let reverbEngine = ReverbEngine()

    private var fullBuffer: AVAudioPCMBuffer?
    private var audioFormat: AVAudioFormat?

    private(set) var isPlaying = false
    private(set) var currentFile: URL?

    init() {
        engine.attach(varispeed)
    }

    // MARK: - Graph Wiring

    private func connectGranularPath(format: AVAudioFormat) {
        // Disconnect and detach old source node if present
        if let src = sourceNode {
            engine.disconnectNodeOutput(src)
            engine.detach(src)
            sourceNode = nil
        }
        engine.disconnectNodeOutput(varispeed)

        let ge = grainEngine
        let eq = graphicEQ
        let rv = reverbEngine
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let outL = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
            let outR = ablPointer.count > 1
                ? ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
                : outL

            _ = ge.render(outputL: outL, outputR: outR, frameCount: Int(frameCount))
            eq.process(inputL: outL, inputR: outR, frameCount: Int(frameCount))
            rv.process(inputL: outL, inputR: outR, frameCount: Int(frameCount))
            return noErr
        }

        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: varispeed, format: format)
        engine.connect(varispeed, to: engine.mainMixerNode, format: format)
    }

    // MARK: - File Loading

    func loadFile(url: URL) throws {
        stop()

        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioEngineError.bufferCreationFailed
        }
        try audioFile.read(into: buffer)

        fullBuffer = buffer
        audioFormat = format
        currentFile = url

        // Configure grain engine with buffer data
        if let channelData = buffer.floatChannelData {
            let chCount = Int(format.channelCount)
            grainEngine.configure(
                sourceL: channelData[0],
                sourceR: chCount > 1 ? channelData[1] : nil,
                frameCount: Int(buffer.frameLength),
                channelCount: chCount,
                sampleRate: Float(format.sampleRate)
            )
        }

        graphicEQ.configure(sampleRate: Float(format.sampleRate))
        reverbEngine.configure(sampleRate: Float(format.sampleRate))
        connectGranularPath(format: format)

        if !engine.isRunning {
            try engine.start()
        }
    }

    // MARK: - Playback

    func playGranular(loopStart: Double, loopEnd: Double, pitchSemitones: Float) {
        guard let audioFormat else { return }

        let sampleRate = audioFormat.sampleRate
        let startFrame = Int(loopStart * sampleRate)
        let endFrame = Int(loopEnd * sampleRate)

        grainEngine.setParameters { params in
            params.startPosition = max(0, startFrame)
            params.endPosition = max(startFrame, endFrame)
        }

        varispeed.rate = pow(2.0, pitchSemitones / 12.0)

        if !engine.isRunning {
            try? engine.start()
        }

        grainEngine.noteOn()
        isPlaying = true
    }

    func stop() {
        grainEngine.noteOff()
        isPlaying = false
    }

    func shutdown() {
        grainEngine.noteOff()
        if let src = sourceNode {
            engine.detach(src)
            sourceNode = nil
        }
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
    }

    // MARK: - Parameter Setters

    func setPitch(_ semitones: Float) {
        varispeed.rate = pow(2.0, semitones / 12.0)
    }

    func setGrainRate(_ rate: Float) {
        grainEngine.setParameters { $0.grainRate = rate }
    }

    func setGrainDuration(_ duration: Float) {
        grainEngine.setParameters { $0.grainDuration = duration }
    }

    func setShiftSpeed(_ speed: Float) {
        grainEngine.setParameters { $0.shiftSpeed = speed }
    }

    func setShiftDirection(_ direction: ShiftDirection) {
        grainEngine.setParameters { $0.shiftDirection = direction }
    }

    func setGrainEnvelope(attack: Float, release: Float) {
        grainEngine.setParameters {
            $0.attackProportion = attack
            $0.releaseProportion = release
        }
    }

    func setNoteEnvelope(attack: Float, release: Float) {
        grainEngine.setParameters {
            $0.noteAttack = attack
            $0.noteRelease = release
        }
    }

    // MARK: - Graphic EQ Parameter Setters

    func setEQEnabled(_ enabled: Bool) {
        graphicEQ.setParameters { $0.isEnabled = enabled }
    }

    func setEQBandGain(band: EQBand, gain: Float) {
        graphicEQ.setParameters { $0.gains[band.rawValue] = gain }
    }

    func setAllEQGains(_ gains: [Float]) {
        graphicEQ.setParameters { $0.gains = gains }
    }

    // MARK: - Reverb Parameter Setters

    func setReverbEnabled(_ enabled: Bool) {
        reverbEngine.setParameters { $0.isEnabled = enabled }
    }

    func setReverbRoomSize(_ size: Float) {
        reverbEngine.setParameters { $0.roomSize = size }
    }

    func setReverbDamping(_ damping: Float) {
        reverbEngine.setParameters { $0.damping = damping }
    }

    func setReverbWetDry(_ mix: Float) {
        reverbEngine.setParameters { $0.wetDry = mix }
    }

    func setReverbPreDelay(_ ms: Float) {
        reverbEngine.setParameters { $0.preDelay = ms }
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
