import SwiftUI
import SwiftData

struct SamplePlayerView: View {
    @Bindable var sample: Sample
    @State private var audioEngine = AudioEngineService()
    @State private var waveformSamples: [Float] = []
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            // Waveform editor
            WaveformEditorView(
                waveformSamples: waveformSamples,
                loopStart: $sample.loopStart,
                loopEnd: $sample.loopEnd,
                duration: sample.duration
            )
            .padding(.horizontal)
            .padding(.top, 16)

            // Loop time labels
            HStack {
                Text(formatTime(sample.loopStart))
                    .font(.caption)
                    .foregroundStyle(.black)
                Spacer()
                Text(formatTime(sample.loopEnd))
                    .font(.caption)
                    .foregroundStyle(.black)
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

            GranularControlsView(sample: sample, audioEngine: audioEngine)
        }
        .navigationTitle(sample.name)
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, ms)
    }
}
