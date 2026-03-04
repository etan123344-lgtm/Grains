import SwiftUI

struct GranularControlsView: View {
    @Bindable var sample: Sample
    var audioEngine: AudioEngineService

    private var density: Float {
        sample.grainRate
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Play/Stop
                Button {
                    if audioEngine.isPlaying {
                        audioEngine.stop()
                    } else {
                        audioEngine.playGranular(
                            loopStart: sample.loopStart,
                            loopEnd: sample.loopEnd,
                            pitchSemitones: sample.pitchSemitones
                        )
                    }
                } label: {
                    Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 44))
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(.ultraThinMaterial))
                }

                // Density (controls grain rate)
                VStack(spacing: 4) {
                    HStack {
                        Text("Density")
                        Spacer()
                        Text(String(format: "%.1fx", density))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)

                    Slider(value: $sample.grainRate, in: 1...32)
                        .padding(.horizontal, 32)
                        .onChange(of: sample.grainRate) {
                            audioEngine.setGrainRate(sample.grainRate)
                        }
                }

                // Grain Size
                parameterSlider(
                    label: "Grain Size",
                    value: $sample.grainDuration,
                    range: 0.01...1.0,
                    format: "%.2f s"
                ) {
                    audioEngine.setGrainDuration(sample.grainDuration)
                }

                // Shift Speed
                parameterSlider(
                    label: "Shift Speed",
                    value: $sample.shiftSpeed,
                    range: 0...10,
                    format: "%.1fx"
                ) {
                    audioEngine.setShiftSpeed(sample.shiftSpeed)
                }

                // Shift Direction
                VStack(spacing: 4) {
                    Text("Shift Direction")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)

                    Picker("Direction", selection: $sample.shiftDirectionRaw) {
                        Text("Forward").tag(0)
                        Text("Backward").tag(1)
                        Text("Random").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .onChange(of: sample.shiftDirectionRaw) {
                        audioEngine.setShiftDirection(sample.shiftDirection)
                    }
                }

                Divider().padding(.horizontal, 32)

                // Grain Envelope header
                Text("Grain Envelope")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)

                // Attack
                parameterSlider(
                    label: "Attack",
                    value: $sample.grainAttack,
                    range: 0.01...0.5,
                    format: "%.0f%%",
                    displayMultiplier: 100
                ) {
                    audioEngine.setGrainEnvelope(attack: sample.grainAttack, release: sample.grainRelease)
                }

                // Release
                parameterSlider(
                    label: "Release",
                    value: $sample.grainRelease,
                    range: 0.01...0.5,
                    format: "%.0f%%",
                    displayMultiplier: 100
                ) {
                    audioEngine.setGrainEnvelope(attack: sample.grainAttack, release: sample.grainRelease)
                }

                Divider().padding(.horizontal, 32)

                // Note Envelope header
                Text("Note Envelope")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)

                // Note Attack
                parameterSlider(
                    label: "Note Attack",
                    value: $sample.noteAttack,
                    range: 0.001...2.0,
                    format: "%.3f s"
                ) {
                    audioEngine.setNoteEnvelope(attack: sample.noteAttack, release: sample.noteRelease)
                }

                // Note Release
                parameterSlider(
                    label: "Note Release",
                    value: $sample.noteRelease,
                    range: 0.01...5.0,
                    format: "%.2f s"
                ) {
                    audioEngine.setNoteEnvelope(attack: sample.noteAttack, release: sample.noteRelease)
                }

                // Pitch
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
    }

    // MARK: - Reusable Slider Builder

    @ViewBuilder
    private func parameterSlider(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        displayMultiplier: Float = 1,
        onChange: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: format, value.wrappedValue * displayMultiplier))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Slider(value: value, in: range)
                .padding(.horizontal, 32)
                .onChange(of: value.wrappedValue) {
                    onChange()
                }
        }
    }
}
