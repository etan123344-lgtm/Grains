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
