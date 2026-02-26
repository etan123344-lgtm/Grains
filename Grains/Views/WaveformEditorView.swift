import SwiftUI

struct WaveformEditorView: View {
    let waveformData: [Float]
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double

    private let handleWidth: CGFloat = 12
    private let waveformColor = Color.white
    private let activeColor = Color.white.opacity(0.9)
    private let dimmedColor = Color.white.opacity(0.15)
    private let loopStartColor = Color.green
    private let loopEndColor = Color.red

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .leading) {
                // Waveform
                Canvas { context, size in
                    drawWaveform(context: context, size: size)
                }

                // Dimmed overlay — before loop start
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: xPosition(for: loopStart, in: width))

                // Dimmed overlay — after loop end
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: width - xPosition(for: loopEnd, in: width))
                    .offset(x: xPosition(for: loopEnd, in: width))

                // Loop start handle
                handleView(color: loopStartColor)
                    .offset(x: xPosition(for: loopStart, in: width) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newTime = timeFromX(value.location.x, in: width)
                                loopStart = max(0, min(newTime, loopEnd - 0.01))
                            }
                    )

                // Loop end handle
                handleView(color: loopEndColor)
                    .offset(x: xPosition(for: loopEnd, in: width) - handleWidth / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newTime = timeFromX(value.location.x, in: width)
                                loopEnd = min(duration, max(newTime, loopStart + 0.01))
                            }
                    )
            }
            .clipped()
        }
        .frame(height: 150)
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        guard !waveformData.isEmpty else { return }

        let midY = size.height / 2
        let barWidth = size.width / CGFloat(waveformData.count)

        for (index, sample) in waveformData.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(sample) * midY

            let time = (Double(index) / Double(waveformData.count)) * duration
            let isInLoop = time >= loopStart && time <= loopEnd
            let color = isInLoop ? activeColor : dimmedColor

            let rect = CGRect(
                x: x,
                y: midY - barHeight,
                width: max(barWidth - 0.5, 0.5),
                height: barHeight * 2
            )
            context.fill(Path(rect), with: .color(color))
        }
    }

    private func handleView(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: handleWidth, height: 150)
            .shadow(radius: 2)
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
