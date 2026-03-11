import SwiftUI

struct WaveformEditorView: View {
    let waveformSamples: [Float]
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double

    @State private var viewWidth: CGFloat = 0

    private let handleWidth: CGFloat = 10
    private let waveformHeight: CGFloat = 120
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 1.5

    var body: some View {
        VStack(spacing: 0) {
            // Waveform container with border
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .fill(DS.bg)

                // Waveform canvas
                Canvas { context, size in
                    let step = barWidth + spacing
                    let midY = size.height / 2
                    let loopStartX = xPosition(for: loopStart, in: size.width)
                    let loopEndX = xPosition(for: loopEnd, in: size.width)

                    for (i, sample) in waveformSamples.enumerated() {
                        let x = CGFloat(i) * step
                        let amplitude = max(0, min(1, abs(CGFloat(sample))))
                        let barHeight = max(1, amplitude * (size.height - 8))
                        let rect = CGRect(
                            x: x,
                            y: midY - barHeight / 2,
                            width: barWidth,
                            height: barHeight
                        )
                        let path = RoundedRectangle(cornerRadius: 0.5).path(in: rect)
                        let isInLoop = x >= loopStartX && x <= loopEndX
                        let color = isInLoop ? DS.waveform : DS.waveformDim
                        context.fill(path, with: .color(color))
                    }
                }
                .padding(4)

                // Border
                RoundedRectangle(cornerRadius: DS.cornerRadius)
                    .stroke(DS.border, lineWidth: DS.borderWidth)
            }
            .frame(height: waveformHeight)
            // Loop handles overlay
            .overlay(alignment: .leading) {
                handleView()
                    .offset(x: xPosition(for: loopStart, in: viewWidth) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newTime = timeFromX(value.location.x, in: viewWidth)
                                loopStart = max(0, min(newTime, loopEnd - 0.01))
                            }
                    )
            }
            .overlay(alignment: .leading) {
                handleView()
                    .offset(x: xPosition(for: loopEnd, in: viewWidth) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newTime = timeFromX(value.location.x, in: viewWidth)
                                loopEnd = min(duration, max(newTime, loopStart + 0.01))
                            }
                    )
            }
            .clipped()
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                viewWidth = newWidth
            }
        }
    }

    private func handleView() -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(DS.accent)
            .frame(width: handleWidth, height: waveformHeight)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .padding(.horizontal, -16)
    }

    private func xPosition(for time: Double, in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(time / duration) * width
    }

    private func timeFromX(_ x: CGFloat, in width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(x / width) * duration
    }
}
