import SwiftUI
import SwiftData

struct SamplePlayerView: View {
    @Bindable var sample: Sample
    @State private var audioEngine = AudioEngineService()
    @State private var waveformData: [Float] = []
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 0) {
            // Waveform editor
            WaveformEditorView(
                waveformData: waveformData,
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
                    .foregroundStyle(.green)
                Spacer()
                Text(formatTime(sample.loopEnd))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

            // Controls
            VStack(spacing: 20) {
                // Play/Stop
                Button {
                    if audioEngine.isPlaying {
                        audioEngine.stop()
                    } else {
                        audioEngine.play(
                            loopStart: sample.loopStart,
                            loopEnd: sample.loopEnd,
                            isReversed: sample.isReversed,
                            pitchSemitones: sample.pitchSemitones
                        )
                    }
                } label: {
                    Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 44))
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                // Reverse toggle
                Toggle(isOn: $sample.isReversed) {
                    Label("Reverse", systemImage: "arrow.left.arrow.right")
                }
                .padding(.horizontal, 32)
                .onChange(of: sample.isReversed) {
                    if audioEngine.isPlaying {
                        restartPlayback()
                    }
                }

                // Pitch slider
                VStack(spacing: 4) {
                    HStack {
                        Text("Pitch")
                        Spacer()
                        Text(String(format: "%+.1f st", sample.pitchSemitones))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)

                    Slider(value: $sample.pitchSemitones, in: -12...12, step: 0.5)
                        .padding(.horizontal, 32)
                        .onChange(of: sample.pitchSemitones) {
                            audioEngine.setPitch(sample.pitchSemitones)
                        }

                    // Reset pitch button
                    if sample.pitchSemitones != 0 {
                        Button("Reset Pitch") {
                            sample.pitchSemitones = 0
                            audioEngine.setPitch(0)
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(sample.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAudio()
        }
        .onDisappear {
            audioEngine.stop()
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
                waveformData = WaveformGenerator.generate(from: buffer, targetSampleCount: 300)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func restartPlayback() {
        audioEngine.stop()
        audioEngine.play(
            loopStart: sample.loopStart,
            loopEnd: sample.loopEnd,
            isReversed: sample.isReversed,
            pitchSemitones: sample.pitchSemitones
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, ms)
    }
}
