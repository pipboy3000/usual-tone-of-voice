# Usual Tone of Voice 🎙️

Menu bar voice-to-text helper for macOS that keeps your usual tone and flow.

## Purpose ✨
Capture your spoken thoughts quickly, transcribe them locally, and paste the text wherever you’re typing. Ideal for short notes, drafts, and chat replies without breaking your rhythm.

## Features ✅
- 🎛️ Menu bar app UI (SwiftUI `MenuBarExtra`)
- ⌘⌘ Double-press Command key to start/stop recording
- 🎧 WAV recording (16 kHz, mono)
- 🧠 Local transcription via embedded whisper.cpp
- 📝 Customizable transcription prompt (弱いヒント / 要約や書き換えには不向き)
- 📋 Clipboard + optional auto paste

## Build with Xcode 🛠️
Open `UsualToneOfVoiceApp.xcodeproj` in Xcode and run the app target.
The first build will download the prebuilt whisper.cpp XCFramework via Swift Package Manager.

## Swift Package (CLI only) 🧩
Opening `Package.swift` builds a CLI executable (no .app bundle, so Accessibility cannot be granted).
If you still want to run the CLI target:

```bash
swift run
```

## Required macOS permissions
- Microphone access (recording)
- Accessibility (auto paste)

## Model Download Notice 📦
The app auto-downloads the default whisper.cpp model to:
`~/Library/Application Support/UsualToneOfVoice/Models`.
If the model is missing at transcription time, it will download in the background and report progress in Settings. This requires a network connection on first download.

## Initial Prompt の期待値
Initial Prompt は、用語や書式の傾向に寄せるための「弱いヒント」です。効果は保証されず、要約・書き換え・厳密なルールの強制には向きません。

## Third-party notices
This app uses whisper.cpp and Whisper model weights. See `THIRD_PARTY_NOTICES.md`.
