import Foundation
import AVFoundation
import UserNotifications
import AppKit
import ApplicationServices

@MainActor
final class AppModel: ObservableObject {
    @Published var status: AppStatus = .idle {
        didSet { updateIconAnimation() }
    }
    @Published var lastTranscript: String = ""
    @Published var lastError: String? = nil
    @Published var statusLine: String = "Idle"
    @Published var modelDownloadStatusText: String? = nil
    @Published var modelDownloadProgress: Double? = nil
    @Published var iconPhase: Bool = false

    let settings: SettingsStore
    let logger: LogStore

    private let recorder = Recorder()
    private let whisperCppTranscriber = WhisperCppTranscriber()
    private let dispatcher = Dispatcher()
    private var hotKeyMonitor: HotKeyMonitor?
    private let modelManager = ModelManager.shared
    private var iconTimer: DispatchSourceTimer?

    init() {
        self.settings = SettingsStore()
        self.logger = LogStore()
        requestNotificationAccess()
        ensureAccessibilityPermissionIfNeeded()
        startHotKeyMonitor()
        _ = UserDictionaryStore.shared
        configureModelManager()
    }

    private func configureModelManager() {
        modelManager.onStatus = { [weak self] status in
            Task { @MainActor in
                switch status {
                case .idle:
                    self?.statusLine = "Idle"
                    self?.modelDownloadStatusText = nil
                    self?.modelDownloadProgress = nil
                case .downloading(let progress):
                    let percent = Int(progress * 100)
                    self?.statusLine = "Downloading model \(percent)%"
                    self?.modelDownloadStatusText = "Downloading model \(percent)%"
                    self?.modelDownloadProgress = progress
                case .ready(let path):
                    self?.statusLine = "Model ready"
                    self?.modelDownloadStatusText = nil
                    self?.modelDownloadProgress = nil
                    self?.lastError = nil
                    self?.log("Model ready: \(path)")
                case .failed(let message):
                    self?.statusLine = "Model download failed"
                    self?.modelDownloadStatusText = "Model download failed"
                    self?.modelDownloadProgress = nil
                    self?.lastError = message
                    self?.log("Model download failed: \(message)")
                }
            }
        }

        let modelPath = ModelManager.defaultModelPath()
        modelManager.ensureModel(at: modelPath, downloadURL: ModelManager.defaultModelURL)
    }

    func toggleRecording() {
        switch status {
        case .idle:
            Task { await startRecording() }
        case .recording:
            Task { await stopRecording() }
        case .transcribing:
            log("Ignoring hotkey: transcription in progress")
        }
    }

    func showSettings() {
        SettingsWindowController.shared.show(model: self)
    }

    func startRecording() async {
        guard status == .idle else { return }
        guard await ensureMicrophoneAccess() else {
            fail("Microphone access denied", notify: true)
            return
        }
        do {
            try recorder.start()
            status = .recording
            lastError = nil
            log("Recording started")
            SoundPlayer.playStart()
            notify(title: "Recording", body: "Recording started")
        } catch {
            fail("Failed to start recording: \(error.localizedDescription)", notify: true)
        }
    }

    func stopRecording() async {
        guard status == .recording else { return }
        status = .transcribing
        let audioURL = recorder.stop()
        SoundPlayer.playStop()
        log("Recording stopped")

        guard let audioURL else {
            status = .idle
            fail("No audio file captured", notify: true)
            return
        }

        let language = settings.language.isEmpty ? nil : settings.language
        let autoPaste = settings.autoPaste
        let initialPrompt = settings.initialPrompt
        let whisperCppModelPath = ModelManager.defaultModelPath().path
        let beamSize = 8
        let bestOf = 8
        let temperature = 0.0
        let temperatureIncrement = 0.2
        let noFallback = false

        guard FileManager.default.fileExists(atPath: whisperCppModelPath) else {
            status = .idle
            fail("Model not ready. Downloading...", notify: true)
            modelManager.ensureModel(at: URL(fileURLWithPath: whisperCppModelPath), downloadURL: ModelManager.defaultModelURL)
            return
        }

        Task.detached(priority: .userInitiated) { [whisperCppTranscriber, dispatcher] in
            do {
                let rawText = try whisperCppTranscriber.transcribe(
                    audioURL: audioURL,
                    modelPath: whisperCppModelPath,
                    language: language,
                    initialPrompt: initialPrompt,
                    chunkDuration: 0,
                    bestOf: bestOf,
                    beamSize: beamSize,
                    temperature: temperature,
                    temperatureIncrement: temperatureIncrement,
                    noFallback: noFallback
                )
                let text = TextNormalizer.normalize(rawText)

                try? FileManager.default.removeItem(at: audioURL)

                await MainActor.run {
                    self.lastTranscript = text
                    self.status = .idle
                    self.lastError = nil
                    self.log("Transcription complete (\(text.count) chars)")
                    do {
                        let result = try dispatcher.dispatch(text: text, autoPaste: autoPaste)
                        if result.didPaste {
                            self.notify(title: "Transcribed", body: "Pasted into the active app")
                        } else {
                            self.notify(title: "Transcribed", body: "Copied to clipboard")
                        }
                    } catch {
                        self.fail("Paste failed: \(error.localizedDescription)", notify: true)
                    }
                }
            } catch {
                try? FileManager.default.removeItem(at: audioURL)
                await MainActor.run {
                    self.status = .idle
                    self.fail("Transcription failed: \(error.localizedDescription)", notify: true)
                }
            }
        }
    }

    private func startHotKeyMonitor() {
        hotKeyMonitor = HotKeyMonitor { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
        hotKeyMonitor?.start()
    }

    private func requestNotificationAccess() {
        guard isAppBundle else {
            log("Notifications skipped (not running from app bundle)")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func ensureAccessibilityPermissionIfNeeded() {
        guard settings.autoPaste else { return }
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func warmupDaemonIfNeeded() {
        // openai-whisper daemon no longer used in whisper.cpp-only mode
    }

    private func ensureMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func log(_ message: String) {
        logger.add(message)
        statusLine = formatStatusLine(message)
    }

    private func fail(_ message: String, notify shouldNotify: Bool) {
        lastError = message
        log(message)
        if shouldNotify {
            notify(title: "Usual Tone of Voice", body: message)
        }
    }

    private func notify(title: String, body: String) {
        guard isAppBundle else {
            log("Notification skipped: \(title) - \(body)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private func updateIconAnimation() {
        switch status {
        case .recording, .transcribing:
            if iconTimer == nil {
                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                timer.schedule(deadline: .now(), repeating: 0.9)
                timer.setEventHandler { [weak self] in
                    guard let self else { return }
                    self.iconPhase.toggle()
                }
                iconTimer = timer
                timer.resume()
            }
        case .idle:
            iconTimer?.cancel()
            iconTimer = nil
            iconPhase = false
        }
    }

    var menuIconName: String {
        if lastError != nil && status == .idle {
            return "exclamationmark.triangle"
        }
        switch status {
        case .idle:
            return "waveform.circle"
        case .recording:
            return iconPhase ? "waveform.circle.fill" : "waveform.circle"
        case .transcribing:
            return iconPhase ? "waveform.circle.fill" : "waveform.circle"
        }
    }

    var shouldShowSystemIcon: Bool {
        lastError != nil && status == .idle
    }

    private func formatStatusLine(_ message: String) -> String {
        let firstLine = message.split(whereSeparator: \.isNewline).first ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 120 {
            return String(trimmed.prefix(120)) + "..."
        }
        return trimmed.isEmpty ? status.label : trimmed
    }
}

enum AppStatus: String {
    case idle
    case recording
    case transcribing

    var menuIcon: String {
        switch self {
        case .idle: return "waveform.circle"
        case .recording: return "waveform.circle.fill"
        case .transcribing: return "waveform.badge.exclamationmark"
        }
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        }
    }
}
