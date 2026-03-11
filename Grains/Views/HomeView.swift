import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sample.createdAt, order: .reverse) private var samples: [Sample]

    @State private var showingRecordingSheet = false
    @State private var showingFileImporter = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var sampleToRename: Sample?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DS.bg.ignoresSafeArea()

                if samples.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32, weight: .thin, design: .monospaced))
                            .foregroundStyle(DS.border)
                        Text("NO SAMPLES")
                            .font(DS.monoLarge)
                            .foregroundStyle(DS.textSecondary)
                        Text("RECORD OR IMPORT AN AUDIO FILE")
                            .font(DS.monoSmall)
                            .foregroundStyle(DS.textSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(samples) { sample in
                                NavigationLink(destination: SamplePlayerView(sample: sample)) {
                                    sampleRow(sample)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        renameText = sample.name
                                        sampleToRename = sample
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        FileManagerService.deleteFile(named: sample.fileName)
                                        modelContext.delete(sample)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingRecordingSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mic")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("REC")
                                    .font(DS.monoSmall)
                            }
                            .foregroundStyle(DS.accent)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.cornerRadius)
                                    .stroke(DS.accent, lineWidth: DS.borderWidth)
                            )
                        }

                        Button {
                            showingFileImporter = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("IMPORT")
                                    .font(DS.monoSmall)
                            }
                            .foregroundStyle(DS.text)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.cornerRadius)
                                    .stroke(DS.border, lineWidth: DS.borderWidth)
                            )
                        }
                    }
                }
            }
            .toolbarBackground(DS.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingRecordingSheet) {
                RecordingSheet { name, fileName, duration in
                    let sample = Sample(name: name, fileName: fileName, duration: duration)
                    modelContext.insert(sample)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Rename Sample", isPresented: Binding(
                get: { sampleToRename != nil },
                set: { if !$0 { sampleToRename = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    sampleToRename = nil
                }
                Button("Rename") {
                    if let sample = sampleToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        sample.name = renameText.trimmingCharacters(in: .whitespaces)
                    }
                    sampleToRename = nil
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Sample Row

    private func sampleRow(_ sample: Sample) -> some View {
        HStack(spacing: 12) {
            // Waveform icon
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .fill(DS.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(DS.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius)
                        .stroke(DS.border, lineWidth: DS.borderWidth)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(sample.name.uppercased())
                    .font(DS.mono)
                    .foregroundStyle(DS.text)
                    .lineLimit(1)
                Text(formatDuration(sample.duration))
                    .font(DS.monoSmall)
                    .foregroundStyle(DS.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.border)
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

    // MARK: - Helpers

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let (fileName, duration) = try FileManagerService.importFile(from: url)
                let name = url.deletingPathExtension().lastPathComponent
                let sample = Sample(name: name, fileName: fileName, duration: duration)
                modelContext.insert(sample)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
}
