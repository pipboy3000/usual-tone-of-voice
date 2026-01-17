# Usual Tone of Voice 🎙️

Menu bar voice-to-text helper for macOS that keeps your usual tone and flow.

## Purpose ✨
Capture your spoken thoughts quickly, transcribe them locally, and paste the text wherever you’re typing. Ideal for short notes, drafts, and chat replies without breaking your rhythm.

## Features ✅
- 🎛️ Menu bar app UI (SwiftUI `MenuBarExtra`)
- ⌘⌘ Double-press Command key to start/stop recording
- 🎧 WAV recording (16 kHz, mono)
- 🧠 Local transcription via embedded whisper.cpp
- 📋 Clipboard + optional auto paste
- 🤖 Optional OpenAI post-processing (API key stored in Keychain)

## Swift Package (CLI only) 🧩
Opening `Package.swift` builds a CLI executable (no .app bundle, so Accessibility cannot be granted).
If you just want to try it quickly, this is the easiest path:

```bash
swift run
```

## Build with Xcode 🛠️
Open `UsualToneOfVoiceApp.xcodeproj` in Xcode and run the app target.
The first build will download the prebuilt whisper.cpp XCFramework via Swift Package Manager.
Depending on your signing setup, you may need local signing overrides:
`Configs/Debug.local.xcconfig` and `Configs/Release.local.xcconfig`.

## Direct Distribution (DMG) 📦
This repo includes a one-command DMG builder that also signs, notarizes, and staples the DMG.

Prerequisites:
- Developer ID Application certificate installed in Keychain
- `create-dmg` installed (`brew install create-dmg`)
- A notarytool keychain profile (example name: `AC_PROFILE`)

Create a notarytool profile once:
```bash
xcrun notarytool store-credentials "AC_PROFILE" \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

Build the DMG:
```bash
make dmg
```

Optional overrides:
```bash
APP_PATH="/path/to/UsualToneOfVoice.app" \
DMG_PATH="/path/to/UsualToneOfVoice.dmg" \
VOLNAME="UsualToneOfVoice" \
IDENTITY="Developer ID Application: Your Name (TEAMID)" \
PROFILE="AC_PROFILE" \
./scripts/make-dmg.sh
```

Layout tweaks (no background image by default):
```bash
WINDOW_SIZE="660 400" \
APP_ICON_POS="180 170" \
APPS_LINK_POS="480 170" \
./scripts/make-dmg.sh
```

If `create-dmg` fails with Finder/AppleScript errors, allow your terminal app to control Finder
in System Settings → Privacy & Security → Automation, or skip Finder prettifying:
```bash
SKIP_FINDER_PRETTIFY=1 ./scripts/make-dmg.sh
```

## Required macOS permissions
- Microphone access (recording)
- Accessibility (auto paste)

## Model Download Notice 📦
The app auto-downloads the default whisper.cpp model to:
`~/Library/Application Support/UsualToneOfVoice/Models`.
If the model is missing at transcription time, it will download in the background and report progress in Settings. This requires a network connection on first download.

## OpenAI (optional)
If you enable OpenAI in Settings and enter an API key, the app sends the transcript to OpenAI and pastes the response.
You can select a model and provide a Prompt that is appended to a fixed system prompt (focused on transforming text).
The key is stored in macOS Keychain.

## Third-party notices
This app uses whisper.cpp and Whisper model weights. See `THIRD_PARTY_NOTICES.md`.
