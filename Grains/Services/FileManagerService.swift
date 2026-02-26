import Foundation
import AVFoundation

struct FileManagerService {
    static var samplesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Samples", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func importFile(from sourceURL: URL) throws -> (fileName: String, duration: Double) {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let ext = sourceURL.pathExtension.lowercased()
        let validExtension = ["wav", "mp3", "m4a", "aif", "aiff", "caf"].contains(ext) ? ext : "m4a"
        let fileName = UUID().uuidString + "." + validExtension
        let destURL = samplesDirectory.appendingPathComponent(fileName)

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let audioFile = try AVAudioFile(forReading: destURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

        return (fileName, duration)
    }

    static func deleteFile(named fileName: String) {
        let url = samplesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
