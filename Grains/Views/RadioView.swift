import SwiftUI
import SwiftData

struct RadioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var radio = RadioService()
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var savedSampleName: String?

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.textSecondary)
                    TextField("SEARCH STATIONS", text: $searchText)
                        .font(DS.mono)
                        .foregroundStyle(DS.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { triggerSearch() }
                        .onChange(of: searchText) { triggerSearch() }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius)
                        .stroke(DS.border, lineWidth: DS.borderWidth)
                )
                .padding(.horizontal, DS.hPad)
                .padding(.top, 8)

                // Station list
                if radio.isLoading && radio.stations.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(DS.accent)
                    Text("LOADING STATIONS...")
                        .font(DS.monoSmall)
                        .foregroundStyle(DS.textSecondary)
                        .padding(.top, 8)
                    Spacer()
                } else if radio.stations.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "radio")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundStyle(DS.border)
                        Text("NO STATIONS FOUND")
                            .font(DS.monoLarge)
                            .foregroundStyle(DS.textSecondary)
                        Text("TRY A DIFFERENT SEARCH")
                            .font(DS.monoSmall)
                            .foregroundStyle(DS.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(radio.stations) { station in
                                Button {
                                    radio.play(station: station)
                                } label: {
                                    stationRow(station)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                        // Extra padding at bottom for now-playing bar
                        .padding(.bottom, radio.isPlaying ? 160 : 0)
                    }
                }

                // Now playing / capture bar
                if radio.isPlaying {
                    nowPlayingBar
                }
            }
        }
        .navigationTitle("RADIO")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            Task { await radio.fetchStations() }
        }
        .onDisappear {
            radio.stop()
        }
        .alert("Error", isPresented: Binding(
            get: { radio.errorMessage != nil },
            set: { if !$0 { radio.errorMessage = nil } }
        )) {
            Button("OK") { radio.errorMessage = nil }
        } message: {
            Text(radio.errorMessage ?? "")
        }
        .overlay {
            if let name = savedSampleName {
                savedOverlay(name: name)
            }
        }
    }

    // MARK: - Station Row

    private func stationRow(_ station: RadioStation) -> some View {
        let isActive = radio.currentStation?.id == station.id

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(isActive ? DS.accent.opacity(0.15) : DS.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: isActive ? "antenna.radiowaves.left.and.right" : "radio")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(isActive ? DS.accent : DS.textSecondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius)
                        .stroke(isActive ? DS.accent : DS.border, lineWidth: DS.borderWidth)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name.uppercased())
                    .font(DS.mono)
                    .foregroundStyle(isActive ? DS.accent : DS.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !station.country.isEmpty {
                        Text(station.country.uppercased())
                            .font(DS.monoSmall)
                            .foregroundStyle(DS.textSecondary)
                    }
                    if !station.bitrateLabel.isEmpty {
                        Text(station.bitrateLabel)
                            .font(DS.monoSmall)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
            }

            Spacer()

            if isActive {
                // Animated "playing" indicator
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(DS.accent)
                            .frame(width: 3, height: .random(in: 6...14))
                    }
                }
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 10)
        .background(DS.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DS.border.opacity(0.5))
                .frame(height: 0.5)
                .padding(.leading, DS.hPad + 52)
        }
    }

    // MARK: - Now Playing Bar

    private var nowPlayingBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DS.border)
                .frame(height: DS.borderWidth)

            VStack(spacing: 12) {
                // Station info
                if let station = radio.currentStation {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.accent)
                        Text(station.name.uppercased())
                            .font(DS.mono)
                            .foregroundStyle(DS.text)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            radio.stop()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.textSecondary)
                                .padding(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.cornerRadius)
                                        .stroke(DS.border, lineWidth: DS.borderWidth)
                                )
                        }
                    }
                }

                // Capture controls
                if radio.isCapturing {
                    HStack(spacing: 12) {
                        // Recording indicator
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)

                        Text(formatCaptureDuration(radio.captureSeconds))
                            .font(DS.monoLarge)
                            .foregroundStyle(DS.text)
                            .monospacedDigit()

                        Spacer()

                        Button {
                            finishCapture()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("SAVE")
                                    .font(DS.monoSmall)
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: DS.cornerRadius)
                                    .fill(Color.red)
                            )
                        }
                    }
                } else {
                    Button {
                        radio.startCapture()
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("CAPTURE SOUNDBITE")
                                .font(DS.monoLarge)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: DS.cornerRadius)
                                .fill(DS.accent)
                        )
                    }
                }
            }
            .padding(.horizontal, DS.hPad)
            .padding(.vertical, 12)
            .background(DS.surface)
        }
    }

    // MARK: - Saved Overlay

    private func savedOverlay(name: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(DS.accent)
            Text("SOUNDBITE SAVED")
                .font(DS.monoLarge)
                .foregroundStyle(DS.text)
            Text(name.uppercased())
                .font(DS.monoSmall)
                .foregroundStyle(DS.textSecondary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: DS.cornerRadius * 2)
                .fill(DS.bg)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius * 2)
                .stroke(DS.border, lineWidth: DS.borderWidth)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Helpers

    private func triggerSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await radio.fetchStations(search: searchText)
        }
    }

    private func finishCapture() {
        guard let result = radio.stopCapture() else { return }

        let stationName = radio.currentStation?.name ?? "Radio"
        let name = "\(stationName) Soundbite"
        let sample = Sample(name: name, fileName: result.fileName, duration: result.duration)
        modelContext.insert(sample)

        savedSampleName = name
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { savedSampleName = nil }
        }
    }

    private func formatCaptureDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let tenths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}
