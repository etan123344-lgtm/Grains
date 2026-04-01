import SwiftUI

struct GraphicEQView: View {
    @Bindable var sample: Sample
    var audioEngine: AudioEngineService

    var body: some View {
        VStack(spacing: 16) {
            // Enable toggle
            DSToggleRow(label: "GRAPHIC EQ", isOn: $sample.eqEnabled)
                .onChange(of: sample.eqEnabled) {
                    audioEngine.setEQEnabled(sample.eqEnabled)
                }

            if sample.eqEnabled {
                // dB scale labels
                HStack {
                    Text("+12 dB")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, DS.hPad)

                // Band sliders
                HStack(alignment: .center, spacing: 0) {
                    ForEach(EQBand.allCases, id: \.rawValue) { band in
                        bandSlider(band: band)
                    }
                }
                .padding(.horizontal, 8)

                HStack {
                    Text("-12 dB")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, DS.hPad)

                // Reset button
                Button {
                    for band in EQBand.allCases {
                        sample.setEQGain(band: band, gain: 0)
                    }
                    syncAllBands()
                } label: {
                    Text("FLAT")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.cornerRadius)
                                .stroke(DS.accent, lineWidth: DS.borderWidth)
                        )
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DS.bg)
    }

    @ViewBuilder
    private func bandSlider(band: EQBand) -> some View {
        let binding = Binding<Float>(
            get: { sample.eqGain(for: band) },
            set: { newValue in
                sample.setEQGain(band: band, gain: newValue)
                audioEngine.setEQBandGain(band: band, gain: newValue)
            }
        )

        VStack(spacing: 4) {
            Text(String(format: "%+.0f", binding.wrappedValue))
                .font(DS.monoSmall)
                .foregroundStyle(DS.textSecondary)
                .frame(height: 14)

            verticalSlider(value: binding, range: -12...12)
                .frame(height: 200)

            Text(band.displayName)
                .font(DS.monoSmall)
                .foregroundStyle(DS.text)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func verticalSlider(value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        GeometryReader { geo in
            let height = geo.size.height
            let normalized = CGFloat((value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
            let yPos = height * (1 - normalized)
            let centerY = height * 0.5

            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.surface)
                    .frame(width: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(DS.border, lineWidth: 0.5)
                    )

                // Center line (0 dB)
                Rectangle()
                    .fill(DS.border)
                    .frame(width: 14, height: DS.borderWidth)
                    .position(x: geo.size.width / 2, y: centerY)

                // Fill from center
                let fillTop = min(yPos, centerY)
                let fillBottom = max(yPos, centerY)
                let fillHeight = fillBottom - fillTop

                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.accent.opacity(0.7))
                    .frame(width: 4, height: fillHeight)
                    .position(x: geo.size.width / 2, y: fillTop + fillHeight / 2)

                // Thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(DS.border, lineWidth: DS.borderWidth)
                    )
                    .position(x: geo.size.width / 2, y: yPos)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = 1 - (drag.location.y / height)
                        let clamped = min(max(Float(fraction), 0), 1)
                        value.wrappedValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                    }
            )
        }
    }

    private func syncAllBands() {
        for band in EQBand.allCases {
            audioEngine.setEQBandGain(band: band, gain: sample.eqGain(for: band))
        }
    }
}
