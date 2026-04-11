import SwiftUI

struct EchoView: View {
    @Bindable var sample: Sample
    var audioEngine: AudioEngineService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DSToggleRow(label: "ECHO", isOn: $sample.echoEnabled)
                    .onChange(of: sample.echoEnabled) {
                        audioEngine.setEchoEnabled(sample.echoEnabled)
                    }

                if sample.echoEnabled {
                    DSSectionHeader(title: "Parameters")

                    DSParamRow(
                        label: "Delay Time",
                        value: $sample.echoDelayTime,
                        range: 1...2000,
                        format: "%.0f ms"
                    ) {
                        audioEngine.setEchoDelayTime(sample.echoDelayTime)
                    }

                    DSParamRow(
                        label: "Feedback",
                        value: $sample.echoFeedback,
                        range: 0...0.95,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setEchoFeedback(sample.echoFeedback)
                    }

                    DSParamRow(
                        label: "Wet / Dry",
                        value: $sample.echoWetDry,
                        range: 0...1,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setEchoWetDry(sample.echoWetDry)
                    }

                    DSParamRow(
                        label: "Tone",
                        value: $sample.echoTone,
                        range: 0...1,
                        format: "%.0f%%",
                        displayMultiplier: 100
                    ) {
                        audioEngine.setEchoTone(sample.echoTone)
                    }

                    DSDivider()

                    Text("STEREO FEEDBACK DELAY — LOWPASS-DAMPED REPEATS")
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
