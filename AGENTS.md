# Repository Guidelines

## Project Structure & Module Organization
- `Sources/UsualToneOfVoice` contains the SwiftUI app and core services (recording, transcription, OpenAI client, settings).
- UI lives under `Sources/UsualToneOfVoice/Views`; assets are in `Sources/UsualToneOfVoice/Assets.xcassets` and `Sources/UsualToneOfVoice/assets`.
- App resources (e.g., bundled files) are under `Sources/UsualToneOfVoice/Resources`.
- Tests are in `Tests/UsualToneOfVoiceTests` using XCTest.
- Xcode configuration files live in `Configs` (e.g., `Debug.local.xcconfig`).
- The Xcode project is `UsualToneOfVoiceApp.xcodeproj`; the Swift Package is defined in `Package.swift`.

## Build, Test, and Development Commands
- `swift run` — build and run the CLI executable via Swift Package Manager.
- `swift build` — compile the package without running.
- `swift test` — run XCTest targets under `Tests/`.
- `xcodebuild -project UsualToneOfVoiceApp.xcodeproj -scheme UsualToneOfVoice -configuration Debug build` — build the macOS app target from the Xcode project.
- `xcodebuild -project UsualToneOfVoiceApp.xcodeproj -scheme UsualToneOfVoiceTests -destination 'platform=macOS' test` — run the app test scheme via Xcodebuild.
- `open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/UsualToneOfVoice.app` — launch the built app after an Xcodebuild.
- `xcodebuild -project UsualToneOfVoiceApp.xcodeproj -scheme UsualToneOfVoice -configuration Release -archivePath build/UsualToneOfVoice.xcarchive archive` — create an archive (requires signing configuration).
- Xcode: open `UsualToneOfVoiceApp.xcodeproj` and run the app target for the menu bar UI.
  - First build downloads the prebuilt whisper.cpp XCFramework via SPM.
  - If signing is required, create `Configs/Debug.local.xcconfig` or `Configs/Release.local.xcconfig` overrides.

## Coding Style & Naming Conventions
- Use standard Swift/Xcode formatting (4‑space indentation, one type per file).
- Types in PascalCase (`ModelManager`), methods and properties in camelCase (`startRecording`).
- Test files use the `*Tests.swift` suffix; test methods start with `test...`.
- No linting/formatting tools are configured; keep changes consistent with nearby code.

## Testing Guidelines
- Framework: XCTest.
- Place tests in `Tests/UsualToneOfVoiceTests` and mirror production type names (e.g., `TextNormalizerTests`).
- Run locally with `swift test` or Xcode “Product → Test”.

## Commit & Pull Request Guidelines
- Commit subjects are short, imperative, and descriptive (e.g., “Add Xcode test target and schemes”).
- Prefer one logical change per commit; include context in the body when the why isn’t obvious.
- PRs should include a clear description, testing notes, and screenshots for UI changes.
- Link related issues when applicable.

## Configuration & Runtime Notes
- The app stores OpenAI keys in macOS Keychain (optional feature).
- Whisper models download to `~/Library/Application Support/UsualToneOfVoice/Models` on first use.
- Required macOS permissions: Microphone and Accessibility (for auto paste).
