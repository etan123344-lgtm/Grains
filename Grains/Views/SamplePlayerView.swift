import SwiftUI
import SwiftData

struct SamplePlayerView: View {
    @Bindable var sample: Sample
    @State private var audioEngine = AudioEngineService()
    @State private var waveformSamples: [Float] = []
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isExporting = false
    @State private var exportedFileURL: URL?

    var body: some View {
        TabView {
            samplerTab
                .tabItem {
                    Label("Sampler", systemImage: "waveform")
                }

            GraphicEQView(sample: sample, audioEngine: audioEngine)
                .tabItem {
                    Label("EQ", systemImage: "slider.vertical.3")
                }

            EchoView(sample: sample, audioEngine: audioEngine)
                .tabItem {
                    Label("Echo", systemImage: "arrow.triangle.2.circlepath")
                }

            ReverbView(sample: sample, audioEngine: audioEngine)
                .tabItem {
                    Label("Reverb", systemImage: "waveform.path.ecg")
                }
        }
        .navigationTitle(sample.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    performExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(isExporting)
            }
        }
        .sheet(item: $exportedFileURL) { url in
            ShareSheet(activityItems: [url])
        }
        .onAppear {
            loadAudio()
            syncGrainParameters()
        }
        .onDisappear {
            audioEngine.shutdown()
        }
        .onChange(of: sample.loopStart) {
            if audioEngine.isPlaying {
                restartPlayback()
            }
        }
        .onChange(of: sample.loopEnd) {
            if audioEngine.isPlaying {
                restartPlayback()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private var samplerTab: some View {
        VStack(spacing: 0) {
            WaveformEditorView(
                waveformSamples: waveformSamples,
                loopStart: $sample.loopStart,
                loopEnd: $sample.loopEnd,
                duration: sample.duration
            )
            .padding(.horizontal, DS.hPad)
            .padding(.top, 12)

            HStack {
                Text(formatTime(sample.loopStart))
                    .font(DS.monoSmall)
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Text(formatTime(sample.loopEnd))
                    .font(DS.monoSmall)
                    .foregroundStyle(DS.textSecondary)
            }
            .padding(.horizontal, DS.hPad)
            .padding(.top, 4)

            GranularControlsView(sample: sample, audioEngine: audioEngine)
                .padding(.top, 8)
        }
        .background(DS.bg)
    }

    private func loadAudio() {
        do {
            try audioEngine.loadFile(url: sample.fileURL)
            if let buffer = audioEngine.getFullBuffer() {
                waveformSamples = WaveformGenerator.generateWaveform(from: buffer, targetSampleCount: 200)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func restartPlayback() {
        audioEngine.stop()
        syncGrainParameters()
        audioEngine.playGranular(
            loopStart: sample.loopStart,
            loopEnd: sample.loopEnd,
            pitchSemitones: sample.pitchSemitones
        )
    }

    private func syncGrainParameters() {
        audioEngine.setGrainRate(sample.grainRate)
        audioEngine.setGrainDuration(sample.grainDuration)
        audioEngine.setShiftSpeed(sample.shiftSpeed)
        audioEngine.setShiftDirection(sample.shiftDirection)
        audioEngine.setGrainEnvelope(attack: sample.grainAttack, release: sample.grainRelease)
        audioEngine.setNoteEnvelope(attack: sample.noteAttack, release: sample.noteRelease)
        // Graphic EQ
        audioEngine.setEQEnabled(sample.eqEnabled)
        audioEngine.setAllEQGains(sample.eqGains)
        // Reverb
        audioEngine.setReverbEnabled(sample.reverbEnabled)
        audioEngine.setReverbRoomSize(sample.reverbRoomSize)
        audioEngine.setReverbDamping(sample.reverbDamping)
        audioEngine.setReverbWetDry(sample.reverbWetDry)
        audioEngine.setReverbPreDelay(sample.reverbPreDelay)
    }

    private func performExport() {
        isExporting = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try audioEngine.exportAudio(sample: sample)
                DispatchQueue.main.async {
                    isExporting = false
                    exportedFileURL = url
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    errorMessage = "Export failed: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, ms)
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Identifiable URL for sheet binding

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
