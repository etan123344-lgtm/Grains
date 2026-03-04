import Foundation
import SwiftData

@Model
final class Sample {
    var name: String
    var fileName: String
    var loopStart: Double
    var loopEnd: Double
    var isReversed: Bool
    var pitchSemitones: Float
    var duration: Double
    var createdAt: Date

    // Granular synthesis properties
    var isGranularMode: Bool = false
    var grainRate: Float = 10.0
    var grainDuration: Float = 0.1
    var shiftSpeed: Float = 1.0
    var shiftDirectionRaw: Int = 0
    var grainAttack: Float = 0.25
    var grainRelease: Float = 0.25
    var noteAttack: Float = 0.01
    var noteRelease: Float = 0.3

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
        self.isReversed = false
        self.pitchSemitones = 0
        self.duration = duration
        self.createdAt = Date()
    }
}
