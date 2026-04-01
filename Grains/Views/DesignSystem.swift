import SwiftUI

// MARK: - Rams/TE Design System

enum DS {
    // Colors
    static let bg = Color(red: 0.96, green: 0.95, blue: 0.93)        // warm off-white
    static let surface = Color(red: 0.92, green: 0.91, blue: 0.89)   // slightly darker surface
    static let border = Color(red: 0.78, green: 0.77, blue: 0.75)    // mid gray border
    static let text = Color(red: 0.12, green: 0.12, blue: 0.12)      // near-black
    static let textSecondary = Color(red: 0.45, green: 0.44, blue: 0.42)
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.0)      // TE orange #FF6B00
    static let waveform = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let waveformDim = Color(red: 0.12, green: 0.12, blue: 0.12).opacity(0.25)

    // Typography
    static let mono = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let monoSmall = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let monoLarge = Font.system(size: 14, weight: .semibold, design: .monospaced)
    static let monoTitle = Font.system(size: 11, weight: .bold, design: .monospaced)
    static let monoValue = Font.system(size: 11, weight: .regular, design: .monospaced)

    // Dimensions
    static let cornerRadius: CGFloat = 4
    static let borderWidth: CGFloat = 1
    static let hPad: CGFloat = 20
}

// MARK: - Styled Parameter Row

struct DSParamRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float? = nil
    var format: String = "%.2f"
    var displayMultiplier: Float = 1
    var hint: String? = nil
    var onChange: () -> Void = {}

    @State private var showingHint = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label.uppercased())
                    .font(DS.monoSmall)
                    .foregroundStyle(DS.textSecondary)
                if let hint {
                    DSHintButton(text: hint)
                }
                Spacer()
                Text(String(format: format, value * displayMultiplier))
                    .font(DS.monoValue)
                    .foregroundStyle(DS.text)
            }

            DSSlider(value: $value, range: range, step: step, onChange: onChange)
        }
        .padding(.horizontal, DS.hPad)
    }
}

// MARK: - Hint Button

struct DSHintButton: View {
    let text: String
    @State private var showing = false

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(DS.textSecondary)
        }
        .popover(isPresented: $showing, arrowEdge: .top) {
            Text(text)
                .font(DS.mono)
                .foregroundStyle(DS.text)
                .padding(12)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Custom Slider (hardware-style)

struct DSSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float? = nil
    var onChange: () -> Void = {}

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let normalized = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = normalized * (width - thumbSize)

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.surface)
                    .frame(height: trackHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(DS.border, lineWidth: DS.borderWidth)
                    )

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.accent)
                    .frame(width: thumbX + thumbSize / 2, height: trackHeight)

                // Thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(DS.border, lineWidth: DS.borderWidth)
                    )
                    .offset(x: thumbX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = Float((drag.location.x - thumbSize / 2) / (width - thumbSize))
                        let clamped = min(max(fraction, 0), 1)
                        var newValue = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        if let step {
                            newValue = (newValue / step).rounded() * step
                        }
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onChange()
                    }
            )
        }
        .frame(height: thumbSize)
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(DS.accent)
                .frame(width: 3, height: 12)
            Text(title.uppercased())
                .font(DS.monoTitle)
                .foregroundStyle(DS.text)
            Spacer()
        }
        .padding(.horizontal, DS.hPad)
    }
}

// MARK: - Segmented Picker

struct DSSegmentedPicker: View {
    let labels: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<labels.count, id: \.self) { i in
                Button {
                    selection = i
                } label: {
                    Text(labels[i].uppercased())
                        .font(DS.monoSmall)
                        .foregroundStyle(selection == i ? Color.white : DS.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection == i ? DS.accent : Color.clear)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .stroke(DS.border, lineWidth: DS.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius))
        .padding(.horizontal, DS.hPad)
    }
}

// MARK: - Divider

// MARK: - Toggle Row

struct DSToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(DS.monoLarge)
                .foregroundStyle(DS.text)
            Spacer()
            Button {
                isOn.toggle()
            } label: {
                Text(isOn ? "ON" : "OFF")
                    .font(DS.monoSmall)
                    .foregroundStyle(isOn ? .white : DS.textSecondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .fill(isOn ? DS.accent : DS.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.cornerRadius)
                            .stroke(isOn ? DS.accent : DS.border, lineWidth: DS.borderWidth)
                    )
            }
        }
        .padding(.horizontal, DS.hPad)
    }
}

// MARK: - Divider

struct DSDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.border)
            .frame(height: DS.borderWidth)
            .padding(.horizontal, DS.hPad)
    }
}
