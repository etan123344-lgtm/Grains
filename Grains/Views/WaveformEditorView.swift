import SwiftUI
import WaveformScrubber

struct WaveformEditorView: View {
    let audioURL: URL
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double

    @State private var progress: CGFloat = 0

    private let handleWidth: CGFloat = 12
    private let loopStartColor = Color.green
    private let loopEndColor = Color.red

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                WaveformScrubber(
                    config: ScrubberConfig(
                        activeTint: Color.white.opacity(0.9),
                        inactiveTint: Color.white.opacity(0.3)
                    ),
                    drawer: BarDrawer(config: .init(barWidth: 2, spacing: 2, cornerRadius: 1)),
                    url: audioURL,
                    progress: $progress
                )

                // Dimmed overlay — before loop start
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: xPosition(for: loopStart, in: width))
                    .allowsHitTesting(false)

                // Dimmed overlay — after loop end
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: width - xPosition(for: loopEnd, in: width))
                    .offset(x: xPosition(for: loopEnd, in: width))
                    .allowsHitTesting(false)

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
