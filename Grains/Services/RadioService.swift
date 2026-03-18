import AVFoundation
import Observation

@Observable
final class RadioService {
    var stations: [RadioStation] = []
    var currentStation: RadioStation?
    var isPlaying = false
    var isCapturing = false
    var captureSeconds: Double = 0
    var isLoading = false
    var errorMessage: String?

    private var player: AVPlayer?
    private var captureDelegate: StreamCaptureDelegate?
    private var captureSession: URLSession?
    private var captureDataTask: URLSessionDataTask?
    private var captureStartTime: Date?
    private var captureTimer: Timer?

    // MARK: - Station Discovery

    func fetchStations(search: String = "") async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var components = URLComponents(string: "https://de1.api.radio-browser.info/json/stations/search")!
        var queryItems = [
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "hidebroken", value: "true"),
        ]
        if search.isEmpty {
            queryItems.append(URLQueryItem(name: "tag", value: "music"))
        } else {
            queryItems.append(URLQueryItem(name: "name", value: search))
        }
        components.queryItems = queryItems

        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([RadioStation].self, from: data)
            stations = decoded.filter { !$0.url_resolved.isEmpty }
        } catch {
            if !Task.isCancelled {
                errorMessage = "Failed to load stations"
            }
        }
    }

    // MARK: - Playback

    func play(station: RadioStation) {
        stop()
        guard let url = URL(string: station.url_resolved) else { return }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        currentStation = station
        isPlaying = true
    }

    func stop() {
        cancelCapture()
        player?.pause()
        player = nil
        isPlaying = false
        currentStation = nil
    }

    // MARK: - Soundbite Capture

    func startCapture() {
        guard let station = currentStation,
              let url = URL(string: station.url_resolved) else { return }

        captureSeconds = 0
        captureStartTime = Date()
        isCapturing = true

        // UI timer for capture duration display
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.captureStartTime else { return }
            self.captureSeconds = Date().timeIntervalSince(start)
        }

        // Stream radio data via URLSession delegate (receives chunks efficiently)
        let delegate = StreamCaptureDelegate()
        self.captureDelegate = delegate
        let config = URLSessionConfiguration.default
        captureSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        captureDataTask = captureSession?.dataTask(with: url)
        captureDataTask?.resume()
    }

    func stopCapture() -> (fileName: String, duration: Double)? {
        captureDataTask?.cancel()
        captureDataTask = nil
        captureSession?.invalidateAndCancel()
        captureSession = nil
        captureTimer?.invalidate()
        captureTimer = nil

        let wasCapturing = isCapturing
        isCapturing = false

        guard wasCapturing, let delegate = captureDelegate else { return nil }

        let capturedData = delegate.data
        captureDelegate = nil

        return saveCapturedData(capturedData)
    }

    // MARK: - Private

    private func cancelCapture() {
        captureDataTask?.cancel()
        captureDataTask = nil
        captureSession?.invalidateAndCancel()
        captureSession = nil
        captureTimer?.invalidate()
        captureTimer = nil
        captureDelegate = nil
        isCapturing = false
        captureSeconds = 0
    }

    private func saveCapturedData(_ capturedData: Data) -> (fileName: String, duration: Double)? {
        guard !capturedData.isEmpty else {
            errorMessage = "No audio data captured"
            return nil
        }

        // Pick extension based on station codec
        let ext: String
        if let codec = currentStation?.codec.lowercased() {
            if codec.contains("aac") { ext = "aac" }
            else if codec.contains("ogg") || codec.contains("vorbis") { ext = "ogg" }
            else { ext = "mp3" }
        } else {
            ext = "mp3"
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)

        do {
            try capturedData.write(to: tempURL)

            // Validate and get duration
            let audioFile = try AVAudioFile(forReading: tempURL)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

            guard duration > 0.1 else {
                try? FileManager.default.removeItem(at: tempURL)
                errorMessage = "Capture too short"
                return nil
            }

            // Move to samples directory
            let fileName = UUID().uuidString + "." + ext
            let destURL = FileManagerService.samplesDirectory.appendingPathComponent(fileName)
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            return (fileName, duration)
        } catch {
            errorMessage = "Could not save soundbite: \(error.localizedDescription)"
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
}

// MARK: - Stream Capture Delegate

private class StreamCaptureDelegate: NSObject, URLSessionDataDelegate {
    private let lock = NSLock()
    private var _data = Data()

    var data: Data {
        lock.withLock { _data }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock { _data.append(data) }
    }
}
