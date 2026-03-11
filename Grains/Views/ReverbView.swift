import SwiftUI

struct ReverbView: View {
    @Bindable var sample: Sample
    var audioEngine: AudioEngineService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DSToggleRow(label: "REVERB", isOn: $sample.reverbEnabled)
                    .onChange(of: sample.reverbEnabled) {
                        audioEngine.setReverbEnabled(sample.reverbEnabled)
                    }

                if sample.reverbEnabled {
                    DSSectionHeader(title: "Parameters")

                    DSParamRow(
                        label: "Room Size",
                        value: $sample.reverbRoomSize,
                        range: 0...1,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setReverbRoomSize(sample.reverbRoomSize)
                    }

                    DSParamRow(
                        label: "Damping",
                        value: $sample.reverbDamping,
                        range: 0...1,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setReverbDamping(sample.reverbDamping)
                    }

                    DSParamRow(
                        label: "Wet / Dry",
                        value: $sample.reverbWetDry,
                        range: 0...1,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setReverbWetDry(sample.reverbWetDry)
                    }

                    DSParamRow(
                        label: "Pre-Delay",
                        value: $sample.reverbPreDelay,
                        range: 0...100,
                        format: "%.0f ms"
                    ) {
                        audioEngine.setReverbPreDelay(sample.reverbPreDelay)
                    }

                    DSDivider()

                    Text("SCHROEDER/MOORER ALGORITHMIC REVERB — 6 LOWPASS-FEEDBACK COMB FILTERS + 2 ALLPASS DIFFUSERS")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.textSecondary)
                        .padding(.horizontal, DS.hPad)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, 32)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bg)
    }
}
