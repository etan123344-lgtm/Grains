import SwiftUI
import WaveformScrubber

struct WaveformEditorView: View {
    let audioURL: URL
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double

    @State private var progress: CGFloat = 0
    @State private var viewWidth: CGFloat = 0

    private let handleWidth: CGFloat = 12
    private let loopStartColor = Color.green
    private let loopEndColor = Color.red
    private let waveformHeight: CGFloat = 150

    var body: some View {
        WaveformScrubber(
            config: ScrubberConfig(
                activeTint: Color.white.opacity(0.9),
                inactiveTint: Color.white.opacity(0.3)
            ),
            drawer: BarDrawer(config: .init(barWidth: 2, spacing: 2, cornerRadius: 1)),
            url: audioURL,
            progress: $progress
        )
        .frame(height: waveformHeight)
        .overlay(alignment: .leading) {
            // Dimmed overlay — before loop start
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: xPosition(for: loopStart, in: viewWidth))
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            // Dimmed overlay — after loop end
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: viewWidth - xPosition(for: loopEnd, in: viewWidth))
                .offset(x: xPosition(for: loopEnd, in: viewWidth))
                .allowsHitTesting(false)
        }
        .overlay(alignment: .leading) {
            // Loop start handle
            handleView(color: loopStartColor)
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
            // Loop end handle
            handleView(color: loopEndColor)
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

    private func handleView(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: handleWidth, height: waveformHeight)
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
