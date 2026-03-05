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
            List {
                if samples.isEmpty {
                    ContentUnavailableView(
                        "No Samples",
                        systemImage: "waveform",
                        description: Text("Record or import an audio file to get started.")
                    )
                } else {
                    ForEach(samples) { sample in
                        NavigationLink(destination: SamplePlayerView(sample: sample)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sample.name)
                                    .font(.headline)
                                Text(formatDuration(sample.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                FileManagerService.deleteFile(named: sample.fileName)
                                modelContext.delete(sample)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                renameText = sample.name
                                sampleToRename = sample
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Grains")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingRecordingSheet = true
                        } label: {
                            Label("Record", systemImage: "mic")
                        }
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Import File", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
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
