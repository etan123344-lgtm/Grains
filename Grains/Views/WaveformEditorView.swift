import SwiftUI

struct WaveformEditorView: View {
    @Environment(\.colorScheme) private var colorScheme

    let waveformSamples: [Float]
    @Binding var loopStart: Double
    @Binding var loopEnd: Double
    let duration: Double

    @State private var viewWidth: CGFloat = 0

    private let handleWidth: CGFloat = 12
    private let loopStartColor = Color.black
    private let loopEndColor = Color.black
    private let waveformHeight: CGFloat = 150
    private let barWidth: CGFloat = 2
    private let spacing: CGFloat = 2

    // DEBUG toggles for quick diagnosis
    private let DEBUG_forceFullOpacityBars = false      // Set true to force all bars to full white
    private let DEBUG_useDynamicStepToFitWidth = false // Set true to scale bars to fit available width
    private let DEBUG_normalizeSamples = true          // Set true to use |sample| clamped to [0,1]

    var body: some View {
        Canvas { context, size in
            // Choose step: either fixed barWidth+spacing, or dynamic to fit width
            let step: CGFloat = DEBUG_useDynamicStepToFitWidth
                ? max(1, size.width / CGFloat(max(1, waveformSamples.count)))
                : (barWidth + spacing)

            // Choose base waveform color based on color scheme (black on light backgrounds, white on dark)
            let barBaseColor: Color = (colorScheme == .light) ? .black : .white

            // DEBUG: Log geometry and counts once per draw
            #if DEBUG
            print("Waveform samples: \(waveformSamples.count), step: \(step), estimated total width: \(CGFloat(waveformSamples.count) * step), canvas width: \(size.width)")
            #endif

            let midY = size.height / 2
            let loopStartX = xPosition(for: loopStart, in: size.width)
            let loopEndX = xPosition(for: loopEnd, in: size.width)

            for (i, sample) in waveformSamples.enumerated() {
                let x = CGFloat(i) * step
                let amplitude: CGFloat = {
                    if DEBUG_normalizeSamples {
                        return max(0, min(1, abs(CGFloat(sample))))
                    } else {
                        return CGFloat(sample)
                    }
                }()
                let barHeight = max(1, amplitude * size.height)
                let currentBarWidth: CGFloat = DEBUG_useDynamicStepToFitWidth ? max(1, step - 1) : barWidth
                let rect = CGRect(x: x, y: midY - barHeight / 2, width: currentBarWidth, height: barHeight)
                let path = RoundedRectangle(cornerRadius: 1).path(in: rect)

                let isInLoop = x >= loopStartX && x <= loopEndX
                let color: Color = DEBUG_forceFullOpacityBars
                    ? barBaseColor
                    : (isInLoop ? barBaseColor.opacity(0.9) : barBaseColor.opacity(0.3))
                context.fill(path, with: .color(color))
            }
        }
        .frame(height: waveformHeight)
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

