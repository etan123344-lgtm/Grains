import AVFoundation
import Observation

@Observable
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let varispeed = AVAudioUnitVarispeed()

    private var sourceNode: AVAudioSourceNode?
    private var effectNode: AVAudioUnit?
    let grainEngine = GrainEngine()
    let graphicEQ = GraphicEQEngine()
    let reverbEngine = ReverbEngine()

    private var fullBuffer: AVAudioPCMBuffer?
    private var audioFormat: AVAudioFormat?

    private(set) var isPlaying = false
    private(set) var currentFile: URL?

    init() {
        EffectProcessorAU.register()
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
        if let fx = effectNode {
            engine.disconnectNodeOutput(fx)
            engine.detach(fx)
            effectNode = nil
        }
        engine.disconnectNodeOutput(varispeed)

        // Source node: granular synthesis only
        let ge = grainEngine
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let outL = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
            let outR = ablPointer.count > 1
                ? ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
                : outL
            _ = ge.render(outputL: outL, outputR: outR, frameCount: Int(frameCount))
            return noErr
        }
        sourceNode = node
        engine.attach(node)

        // Effect node: EQ + reverb, placed after varispeed so pitch changes
        // don't disrupt the EQ/reverb filter state
        let effect = AVAudioUnitEffect(audioComponentDescription: EffectProcessorAU.componentDescription)
        if let au = effect.auAudioUnit as? EffectProcessorAU {
            let eq = graphicEQ
            let rv = reverbEngine
            au.processBlock = { left, right, frameCount in
                eq.process(inputL: left, inputR: right, frameCount: frameCount)
                rv.process(inputL: left, inputR: right, frameCount: frameCount)
            }
        }
        effectNode = effect
        engine.attach(effect)

        // Chain: sourceNode -> varispeed -> effect (EQ+reverb) -> mainMixer
        engine.connect(node, to: varispeed, format: format)
        engine.connect(varispeed, to: effect, format: format)
        engine.connect(effect, to: engine.mainMixerNode, format: format)
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
        if let fx = effectNode {
            engine.detach(fx)
            effectNode = nil
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

    func setDryWetMix(_ mix: Float) {
        grainEngine.setParameters { $0.dryWetMix = mix }
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

    // MARK: - Offline Export

    func exportAudio(sample: Sample) throws -> URL {
        guard let audioFormat, let fullBuffer,
              let channelData = fullBuffer.floatChannelData else {
            throw AudioEngineError.bufferCreationFailed
        }

        let sampleRate = audioFormat.sampleRate
        let chCount = Int(audioFormat.channelCount)
        let duration = sample.loopEnd - sample.loopStart
        guard duration > 0 else { throw AudioEngineError.bufferCreationFailed }

        let totalFrames = AVAudioFrameCount(duration * sampleRate)
        let maxFrames: AVAudioFrameCount = 512

        // --- Fresh DSP engines with the same parameters ---
        let offlineGrain = GrainEngine()
        offlineGrain.configure(
            sourceL: channelData[0],
            sourceR: chCount > 1 ? channelData[1] : nil,
            frameCount: Int(fullBuffer.frameLength),
            channelCount: chCount,
            sampleRate: Float(sampleRate)
        )
        offlineGrain.setParameters { p in
            p.grainRate = sample.grainRate
            p.grainDuration = sample.grainDuration
            p.shiftSpeed = sample.shiftSpeed
            p.shiftDirection = sample.shiftDirection
            p.attackProportion = sample.grainAttack
            p.releaseProportion = sample.grainRelease
            p.startPosition = Int(sample.loopStart * sampleRate)
            p.endPosition = Int(sample.loopEnd * sampleRate)
            p.noteAttack = sample.noteAttack
            p.noteRelease = 0.01 // minimal release — no tail
            p.dryWetMix = sample.dryWetMix
        }

        let offlineEQ = GraphicEQEngine()
        offlineEQ.configure(sampleRate: Float(sampleRate))
        offlineEQ.setParameters { p in
            p.isEnabled = sample.eqEnabled
            p.gains = sample.eqGains
        }

        let offlineReverb = ReverbEngine()
        offlineReverb.configure(sampleRate: Float(sampleRate))
        offlineReverb.setParameters { p in
            p.isEnabled = sample.reverbEnabled
            p.roomSize = sample.reverbRoomSize
            p.damping = sample.reverbDamping
            p.wetDry = sample.reverbWetDry
            p.preDelay = sample.reverbPreDelay
        }

        // --- Offline AVAudioEngine ---
        let offlineEngine = AVAudioEngine()
        let offlineVarispeed = AVAudioUnitVarispeed()
        offlineEngine.attach(offlineVarispeed)

        let ge = offlineGrain
        let sourceNode = AVAudioSourceNode(format: audioFormat) { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let outL = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
            let outR = ablPointer.count > 1
                ? ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
                : outL
            _ = ge.render(outputL: outL, outputR: outR, frameCount: Int(frameCount))
            return noErr
        }
        offlineEngine.attach(sourceNode)

        let effectNode = AVAudioUnitEffect(audioComponentDescription: EffectProcessorAU.componentDescription)
        if let au = effectNode.auAudioUnit as? EffectProcessorAU {
            let eq = offlineEQ
            let rv = offlineReverb
            au.processBlock = { left, right, frameCount in
                eq.process(inputL: left, inputR: right, frameCount: frameCount)
                rv.process(inputL: left, inputR: right, frameCount: frameCount)
            }
        }
        offlineEngine.attach(effectNode)

        offlineEngine.connect(sourceNode, to: offlineVarispeed, format: audioFormat)
        offlineEngine.connect(offlineVarispeed, to: effectNode, format: audioFormat)
        offlineEngine.connect(effectNode, to: offlineEngine.mainMixerNode, format: audioFormat)

        try offlineEngine.enableManualRenderingMode(.offline, format: audioFormat, maximumFrameCount: maxFrames)
        offlineVarispeed.rate = pow(2.0, sample.pitchSemitones / 12.0)
        try offlineEngine.start()

        offlineGrain.noteOn()

        // --- Output file ---
        let exportName = sample.name
            .replacingOccurrences(of: "[^a-zA-Z0-9_\\- ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(exportName)_export.wav")
        // Remove stale file if present
        try? FileManager.default.removeItem(at: outputURL)

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: audioFormat.settings)

        // --- Render loop ---
        var framesRendered: AVAudioFrameCount = 0
        let fadeOutFrames: AVAudioFrameCount = min(AVAudioFrameCount(0.02 * sampleRate), totalFrames)
        let fadeStart = totalFrames - fadeOutFrames

        while framesRendered < totalFrames {
            let framesToRender = min(maxFrames, totalFrames - framesRendered)
            guard let renderBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: framesToRender) else {
                throw AudioEngineError.bufferCreationFailed
            }

            let status = try offlineEngine.renderOffline(framesToRender, to: renderBuffer)
            guard status == .success else { break }

            // Apply fade-out near the end to prevent clicks
            if framesRendered + framesToRender > fadeStart {
                if let chData = renderBuffer.floatChannelData {
                    for frame in 0..<Int(renderBuffer.frameLength) {
                        let globalFrame = framesRendered + AVAudioFrameCount(frame)
                        if globalFrame >= fadeStart {
                            let fadeProgress = Float(totalFrames - globalFrame) / Float(fadeOutFrames)
                            for ch in 0..<chCount {
                                chData[ch][frame] *= fadeProgress
                            }
                        }
                    }
                }
            }

            try outputFile.write(from: renderBuffer)
            framesRendered += framesToRender
        }

        offlineGrain.noteOff()
        offlineEngine.stop()

        return outputURL
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
