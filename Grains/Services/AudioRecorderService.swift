import AVFoundation
import Observation

@Observable
final class AudioRecorderService {
    private var recorder: AVAudioRecorder?
    private(set) var isRecording = false
    private(set) var currentFileName: String?

    var recordingURL: URL? {
        guard let currentFileName else { return nil }
        return FileManagerService.samplesDirectory.appendingPathComponent(currentFileName)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record)
        try session.setActive(true)

        let fileName = UUID().uuidString + ".m4a"
        let url = FileManagerService.samplesDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        currentFileName = fileName
        isRecording = true
    }

    func stopRecording() -> (fileName: String, duration: Double)? {
        guard let recorder, let currentFileName else { return nil }
        recorder.stop()
        isRecording = false

        let duration = recorder.currentTime
        self.recorder = nil

        // Switch back to playback
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        // Get accurate duration from file
        let url = FileManagerService.samplesDirectory.appendingPathComponent(currentFileName)
        if let audioFile = try? AVAudioFile(forReading: url) {
            let fileDuration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            let result = (fileName: currentFileName, duration: fileDuration)
            self.currentFileName = nil
            return result
        }

        let result = (fileName: currentFileName, duration: duration)
        self.currentFileName = nil
        return result
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        isRecording = false
        currentFileName = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
