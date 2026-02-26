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
                    }
                    .onDelete(perform: deleteSamples)
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

    private func deleteSamples(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let sample = samples[index]
                FileManagerService.deleteFile(named: sample.fileName)
                modelContext.delete(sample)
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }
}
