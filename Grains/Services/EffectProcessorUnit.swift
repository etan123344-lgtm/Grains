import AudioToolbox
import AVFoundation

/// Minimal AUAudioUnit subclass that hosts inline DSP (EQ + reverb) as an
/// AVAudioEngine-compatible effect node.
final class EffectProcessorAU: AUAudioUnit {

    /// Called on the real-time render thread to process audio in-place.
    /// Must be set before the engine starts rendering.
    var processBlock: ((_ left: UnsafeMutablePointer<Float>,
                        _ right: UnsafeMutablePointer<Float>,
                        _ frameCount: Int) -> Void)?

    private var _inputBusArray: AUAudioUnitBusArray!
    private var _outputBusArray: AUAudioUnitBusArray!

    // MARK: - Registration

    static let componentDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: fourCC("eqrv"),
        componentManufacturer: fourCC("Grns"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static func register() {
        AUAudioUnit.registerSubclass(
            EffectProcessorAU.self,
            as: componentDescription,
            name: "Grains Effect Processor",
            version: 1
        )
    }

    // MARK: - Init

    override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        _inputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .input,
            busses: [try AUAudioUnitBus(format: fmt)])
        _outputBusArray = AUAudioUnitBusArray(
            audioUnit: self, busType: .output,
            busses: [try AUAudioUnitBus(format: fmt)])
    }

    // MARK: - Bus overrides

    override var inputBusses: AUAudioUnitBusArray { _inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { _outputBusArray }

    // MARK: - Render

    override var internalRenderBlock: AUInternalRenderBlock {
        let process = processBlock
        return { actionFlags, timestamp, frameCount, outputBusNumber, outputData,
                 renderEvent, pullInputBlock in

            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }

            var flags = AudioUnitRenderActionFlags(rawValue: 0)
            let status = pullInputBlock(&flags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }

            if let process {
                let abl = UnsafeMutableAudioBufferListPointer(outputData)
                guard abl.count > 0, let dataL = abl[0].mData else { return noErr }
                let left = dataL.assumingMemoryBound(to: Float.self)
                let right: UnsafeMutablePointer<Float> = abl.count > 1
                    ? (abl[1].mData?.assumingMemoryBound(to: Float.self) ?? left)
                    : left
                process(left, right, Int(frameCount))
            }

            return noErr
        }
    }

    // MARK: - Helpers

    private static func fourCC(_ s: String) -> FourCharCode {
        var r: FourCharCode = 0
        for c in s.utf8.prefix(4) { r = (r << 8) | FourCharCode(c) }
        return r
    }
}
