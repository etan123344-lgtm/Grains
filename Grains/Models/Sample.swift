import Foundation
import SwiftData

@Model
final class Sample {
    var name: String
    var fileName: String
    var loopStart: Double
    var loopEnd: Double
    var pitchSemitones: Float
    var duration: Double
    var createdAt: Date

    // Granular synthesis properties
    var grainRate: Float = 10.0
    var grainDuration: Float = 0.1
    var shiftSpeed: Float = 1.0
    var shiftDirectionRaw: Int = 0
    var grainAttack: Float = 0.25
    var grainRelease: Float = 0.25
    var noteAttack: Float = 0.01
    var noteRelease: Float = 0.3

    // Graphic EQ properties (8-band: 60, 170, 310, 600, 1K, 3K, 6K, 12K)
    var eqEnabled: Bool = false
    var eqGain0: Float = 0   // 60 Hz
    var eqGain1: Float = 0   // 170 Hz
    var eqGain2: Float = 0   // 310 Hz
    var eqGain3: Float = 0   // 600 Hz
    var eqGain4: Float = 0   // 1 kHz
    var eqGain5: Float = 0   // 3 kHz
    var eqGain6: Float = 0   // 6 kHz
    var eqGain7: Float = 0   // 12 kHz

    func eqGain(for band: EQBand) -> Float {
        switch band {
        case .hz60: return eqGain0
        case .hz170: return eqGain1
        case .hz310: return eqGain2
        case .hz600: return eqGain3
        case .khz1: return eqGain4
        case .khz3: return eqGain5
        case .khz6: return eqGain6
        case .khz12: return eqGain7
        }
    }

    func setEQGain(band: EQBand, gain: Float) {
        switch band {
        case .hz60: eqGain0 = gain
        case .hz170: eqGain1 = gain
        case .hz310: eqGain2 = gain
        case .hz600: eqGain3 = gain
        case .khz1: eqGain4 = gain
        case .khz3: eqGain5 = gain
        case .khz6: eqGain6 = gain
        case .khz12: eqGain7 = gain
        }
    }

    var eqGains: [Float] {
        [eqGain0, eqGain1, eqGain2, eqGain3, eqGain4, eqGain5, eqGain6, eqGain7]
    }

    // Reverb properties
    var reverbEnabled: Bool = false
    var reverbRoomSize: Float = 0.5
    var reverbDamping: Float = 0.5
    var reverbWetDry: Float = 0.3
    var reverbPreDelay: Float = 20

    var shiftDirection: ShiftDirection {
        get { ShiftDirection(rawValue: shiftDirectionRaw) ?? .forward }
        set { shiftDirectionRaw = newValue.rawValue }
    }

    var fileURL: URL {
        FileManagerService.samplesDirectory.appendingPathComponent(fileName)
    }

    init(name: String, fileName: String, duration: Double) {
        self.name = name
        self.fileName = fileName
        self.loopStart = 0
        self.loopEnd = duration
        self.pitchSemitones = 0
        self.duration = duration
        self.createdAt = Date()
    }
}
