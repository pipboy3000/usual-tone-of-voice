# Usual Tone of Voice

Menu bar voice-to-Codex helper for macOS.

## What's included
- Menu bar app UI (SwiftUI `MenuBarExtra`)
- Double-press Command key hotkey to start/stop recording
- WAV recording (16 kHz, mono)
- Whisper CLI transcription
- Clipboard + optional auto paste
- Notifications + recent log lines

## Run (Swift Package)
Open the folder in Xcode and run the executable target, or from Terminal:

```bash
swift run
```

## Required macOS permissions
- Microphone access (recording)
- Accessibility (auto paste)

If you package this as an .app in Xcode, add these to the app target:
- `NSMicrophoneUsageDescription` in Info.plist
- App Sandbox > Audio Input (if sandboxed)
- Accessibility permission (System Settings -> Privacy & Security -> Accessibility)

## Whisper CLI
The app uses `whisper-cli` (whisper.cpp) and looks in:
- Bundled app resources (if you package the binary)
- `/opt/homebrew/bin/whisper-cli` or `/opt/homebrew/bin/whisper-cpp`
- `/usr/local/bin/whisper-cli` or `/usr/local/bin/whisper-cpp`

There is currently no UI setting for the CLI path.

## Models
The app auto-downloads the default whisper.cpp model to:
`~/Library/Application Support/UsualToneOfVoice/Models`.
If the model is missing at transcription time, it will download in the background and report progress in Settings.

## Notes
- Hotkey: double-press Command (Cmd+Cmd)
- Output mode: Clipboard + Auto Paste (toggle in menu)
