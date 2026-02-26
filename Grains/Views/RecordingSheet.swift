import SwiftUI

struct RecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorderService()
    @State private var sampleName = ""
    @State private var hasPermission = false
    @State private var permissionChecked = false
    @State private var recordingFinished = false
    @State private var recordingResult: (fileName: String, duration: Double)?
    @State private var errorMessage: String?

    let onSave: (String, String, Double) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !permissionChecked {
                    ProgressView("Checking microphone access...")
                } else if !hasPermission {
                    ContentUnavailableView(
                        "Microphone Access Required",
                        systemImage: "mic.slash",
                        description: Text("Please enable microphone access in Settings to record audio.")
                    )
                } else if recordingFinished {
                    saveView
                } else {
                    recordingView
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.cancelRecording()
                        dismiss()
                    }
                }
            }
            .task {
                hasPermission = await recorder.requestPermission()
                permissionChecked = true
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 64))
                .foregroundStyle(recorder.isRecording ? .red : .primary)
                .symbolEffect(.pulse, isActive: recorder.isRecording)

            Text(recorder.isRecording ? "Recording..." : "Tap to Record")
                .font(.title2)

            Spacer()

            Button {
                if recorder.isRecording {
                    recordingResult = recorder.stopRecording()
                    recordingFinished = true
                } else {
                    do {
                        try recorder.startRecording()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Circle()
                    .fill(recorder.isRecording ? .red : .white)
                    .frame(width: 72, height: 72)
                    .overlay {
                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .overlay {
                        Circle().stroke(.white.opacity(0.3), lineWidth: 3)
                    }
            }
            .padding(.bottom, 40)
        }
    }

    private var saveView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Recording Complete")
                .font(.title2)

            if let result = recordingResult {
                Text(String(format: "Duration: %.1fs", result.duration))
                    .foregroundStyle(.secondary)
            }

            TextField("Sample Name", text: $sampleName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("Save") {
                guard let result = recordingResult else { return }
                let name = sampleName.isEmpty ? "Recording \(Date().formatted(date: .abbreviated, time: .shortened))" : sampleName
                onSave(name, result.fileName, result.duration)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(recordingResult == nil)
        }
    }
}
