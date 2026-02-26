# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

This is an Xcode project (no SPM Package.swift). Use `xcodebuild` from the command line:

```bash
# Build
xcodebuild build -scheme Grains -destination 'platform=iOS Simulator,name=iPhone 16'

# Run all tests (unit + UI)
xcodebuild test -scheme Grains -destination 'platform=iOS Simulator,name=iPhone 16'

# Run unit tests only
xcodebuild test -scheme Grains -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GrainsTests

# Run UI tests only
xcodebuild test -scheme Grains -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GrainsUITests
```

No linter or formatter is configured.

## Architecture

- **Language**: Swift 5.0, iOS 17.5+ deployment target
- **UI**: SwiftUI with `NavigationStack` for push-based navigation
- **Persistence**: SwiftData (not Core Data) — models use `@Model` macro, views use `@Query` for data binding and `@Environment(\.modelContext)` for mutations
- **Audio**: AVFoundation (`AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioUnitTimePitch`) for playback with pitch shifting; `AVAudioRecorder` for recording
- **Waveform Rendering**: Accelerate framework (`vDSP`) for RMS-based waveform generation, SwiftUI `Canvas` for drawing
- **No external dependencies** — pure Apple frameworks (SwiftUI, SwiftData, AVFoundation, Accelerate, UniformTypeIdentifiers)

### Source Layout

- `Grains/GrainsApp.swift` — App entry point; configures `ModelContainer` with the `Sample` schema and sets up the audio session
- `Grains/Models/Sample.swift` — SwiftData model representing an audio sample (name, fileName, loopStart/loopEnd, isReversed, pitchSemitones, duration)
- `Grains/Views/HomeView.swift` — Main view listing all samples with options to record or import audio files
- `Grains/Views/RecordingSheet.swift` — Modal sheet for recording audio via the microphone
- `Grains/Views/SamplePlayerView.swift` — Playback view with waveform display, transport controls, pitch slider, and loop region editing
- `Grains/Views/WaveformEditorView.swift` — Interactive waveform view with draggable loop start/end handles
- `Grains/Services/AudioEngineService.swift` — `@Observable` service wrapping `AVAudioEngine` for sample loading, playback, looping, and pitch shifting
- `Grains/Services/AudioRecorderService.swift` — `@Observable` service wrapping `AVAudioRecorder` for microphone recording
- `Grains/Services/FileManagerService.swift` — Utility for managing the `Samples/` directory in app documents and importing audio files
- `Grains/Services/WaveformGenerator.swift` — Generates normalized waveform data from `AVAudioPCMBuffer` using Accelerate
- `GrainsTests/` — XCTest unit tests
- `GrainsUITests/` — XCUITest UI tests (includes launch screenshot tests)
