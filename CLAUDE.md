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
- **UI**: SwiftUI with `NavigationSplitView` for master-detail layout
- **Persistence**: SwiftData (not Core Data) — models use `@Model` macro, views use `@Query` for data binding and `@Environment(\.modelContext)` for mutations
- **No external dependencies** — pure Apple frameworks (SwiftUI, SwiftData, Foundation)

### Source Layout

- `Grains/GrainsApp.swift` — App entry point; configures `ModelContainer` with the `Item` schema
- `Grains/ContentView.swift` — Main view with list display, add/delete operations
- `Grains/Item.swift` — SwiftData model (currently just a `timestamp: Date` property)
- `GrainsTests/` — XCTest unit tests
- `GrainsUITests/` — XCUITest UI tests (includes launch screenshot tests)
