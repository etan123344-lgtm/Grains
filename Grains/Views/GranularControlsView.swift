import SwiftUI

struct GranularControlsView: View {
    @Bindable var sample: Sample
    var audioEngine: AudioEngineService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
                    HStack(spacing: 8) {
                        Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                        Text(audioEngine.isPlaying ? "STOP" : "PLAY")
                            .font(DS.monoLarge)
                    }
                    .foregroundStyle(audioEngine.isPlaying ? DS.text : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .fill(audioEngine.isPlaying ? DS.surface : DS.accent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(audioEngine.isPlaying ? DS.border : DS.accent, lineWidth: DS.borderWidth)
                    )
                }
                .padding(.horizontal, DS.hPad)

                DSSectionHeader(title: "Granular")

                DSParamRow(
                    label: "Density",
                    value: $sample.grainRate,
                    range: 1...32,
                    format: "%.1fx"
                ) {
                    audioEngine.setGrainRate(sample.grainRate)
                }

                DSParamRow(
                    label: "Grain Size",
                    value: $sample.grainDuration,
                    range: 0.01...1.0,
                    format: "%.2f s"
                ) {
                    audioEngine.setGrainDuration(sample.grainDuration)
                }

                DSParamRow(
                    label: "Shift Speed",
                    value: $sample.shiftSpeed,
                    range: 0...10,
                    format: "%.1fx"
                ) {
                    audioEngine.setShiftSpeed(sample.shiftSpeed)
                }

                // Shift Direction
                VStack(spacing: 6) {
                    Text("SHIFT DIRECTION")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.hPad)

                    DSSegmentedPicker(
                        labels: ["FWD", "BWD", "RND"],
                        selection: $sample.shiftDirectionRaw
                    )
                    .onChange(of: sample.shiftDirectionRaw) {
                        audioEngine.setShiftDirection(sample.shiftDirection)
                    }
                }

                DSParamRow(
                    label: "Dry / Wet",
                    value: $sample.dryWetMix,
                    range: 0...1,
                    format: "%.0f%%",
                    displayMultiplier: 100
                ) {
                    audioEngine.setDryWetMix(sample.dryWetMix)
                }

                DSDivider()

                DSSectionHeader(title: "Grain Envelope")

                DSParamRow(
                    label: "Attack",
                    value: $sample.grainAttack,
                    range: 0.01...0.5,
                    format: "%.0f%%",
                    displayMultiplier: 100
                ) {
                    audioEngine.setGrainEnvelope(attack: sample.grainAttack, release: sample.grainRelease)
                }

                DSParamRow(
                    label: "Release",
                    value: $sample.grainRelease,
                    range: 0.01...0.5,
                    format: "%.0f%%",
                    displayMultiplier: 100
                ) {
                    audioEngine.setGrainEnvelope(attack: sample.grainAttack, release: sample.grainRelease)
                }

                DSDivider()

                DSSectionHeader(title: "Note Envelope")

                DSParamRow(
                    label: "Attack",
                    value: $sample.noteAttack,
                    range: 0.001...2.0,
                    format: "%.3f s"
                ) {
                    audioEngine.setNoteEnvelope(attack: sample.noteAttack, release: sample.noteRelease)
                }

                DSParamRow(
                    label: "Release",
                    value: $sample.noteRelease,
                    range: 0.01...5.0,
                    format: "%.2f s"
                ) {
                    audioEngine.setNoteEnvelope(attack: sample.noteAttack, release: sample.noteRelease)
                }

                DSDivider()

                DSSectionHeader(title: "Pitch")

                DSParamRow(
                    label: "Semitones",
                    value: $sample.pitchSemitones,
                    range: -12...12,
                    step: 0.5,
                    format: "%+.1f st"
                ) {
                    audioEngine.setPitch(sample.pitchSemitones)
                }

                if sample.pitchSemitones != 0 {
                    Button {
                        sample.pitchSemitones = 0
                        audioEngine.setPitch(0)
                    } label: {
                        Text("RESET PITCH")
                            .font(DS.monoSmall)
                            .foregroundStyle(DS.accent)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.cornerRadius)
                                    .stroke(DS.accent, lineWidth: DS.borderWidth)
                            )
                    }
                }
            }
            .padding(.bottom, 32)
        }
    }
}
