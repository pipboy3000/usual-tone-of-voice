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
    @Published var openAITestMessage: String? = nil
    @Published var openAITestIsError: Bool = false

    let settings: SettingsStore
    let logger: LogStore

    private let recorder = Recorder()
    private let whisperCppTranscriber = WhisperCppTranscriber()
    private let dispatcher = Dispatcher()
    private let openAIClient = OpenAIClient()
    private var hotKeyMonitor: HotKeyMonitor?
    private let modelManager = ModelManager.shared
    private var iconTimer: DispatchSourceTimer?
    private var silenceMonitorTimer: DispatchSourceTimer?
    private var continuousSilenceDuration: TimeInterval = 0
    private var hasPromptedForCurrentSilence = false
    private var isSilencePromptVisible = false

    init() {
        self.settings = SettingsStore()
        self.logger = LogStore()
        requestNotificationAccess()
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
        guard await requestMicrophoneAccess() else {
            fail("Microphone access denied", notify: true)
            return
        }
        do {
            try recorder.start()
            status = .recording
            startSilenceMonitor()
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
        stopSilenceMonitor()
        status = .transcribing
        let audioURL = recorder.stop()
        SoundPlayer.playStop()
        log("Recording stopped")

        guard let audioURL else {
            status = .idle
            fail("No audio file captured", notify: true)
            return
        }

        if shouldIgnoreSilentRecording(at: audioURL) {
            try? FileManager.default.removeItem(at: audioURL)
            status = .idle
            lastError = nil
            log("Ignored recording: no speech detected")
            notify(title: "録音を破棄", body: "音声が検出されなかったため処理しませんでした。")
            return
        }

        let language = settings.language.isEmpty ? nil : settings.language
        let autoPaste = settings.autoPaste
        let openAIEnabled = settings.openAIEnabled
        let openAIKey = settings.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIModel = settings.openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIUserPrompt = settings.openAIUserPrompt
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

        Task.detached(priority: .userInitiated) { [whisperCppTranscriber, dispatcher, openAIClient] in
            do {
                let rawText = try whisperCppTranscriber.transcribe(
                    audioURL: audioURL,
                    modelPath: whisperCppModelPath,
                    language: language,
                    initialPrompt: "",
                    chunkDuration: 0,
                    bestOf: bestOf,
                    beamSize: beamSize,
                    temperature: temperature,
                    temperatureIncrement: temperatureIncrement,
                    noFallback: noFallback
                )
                let text = TextNormalizer.normalize(rawText)
                var outputText = text
                var openAIErrorMessage: String? = nil

                if openAIEnabled {
                    if openAIKey.isEmpty {
                        openAIErrorMessage = "OpenAI enabled but API key is missing"
                        await MainActor.run {
                            self.notify(title: "OpenAI Error", body: "OpenAI is enabled but no API key is set.")
                            self.log(openAIErrorMessage ?? "")
                        }
                    } else {
                        let resolvedModel = OpenAIModel(rawValue: openAIModel)?.rawValue ?? OpenAIClient.defaultModel
                        let trimmedUserPrompt = openAIUserPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        let combinedSystemPrompt: String
                        if trimmedUserPrompt.isEmpty {
                            combinedSystemPrompt = OpenAIClient.defaultSystemPrompt
                        } else {
                            combinedSystemPrompt = OpenAIClient.defaultSystemPrompt + "\n\n追加の指示:\n" + trimmedUserPrompt
                        }
                        await MainActor.run {
                            self.log("Requesting OpenAI response...")
                        }
                        let temperature = OpenAIClient.supportsTemperature(model: resolvedModel)
                            ? OpenAIClient.defaultTemperature
                            : nil
                        let maxOutputTokens = OpenAIClient.prefersUnboundedOutput(model: resolvedModel)
                            ? nil
                            : OpenAIClient.defaultMaxOutputTokens
                        do {
                            outputText = try await openAIClient.generateResponse(
                                input: text,
                                apiKey: openAIKey,
                                model: resolvedModel,
                                systemPrompt: combinedSystemPrompt,
                                maxOutputTokens: maxOutputTokens,
                                temperature: temperature
                            )
                        } catch {
                            openAIErrorMessage = "OpenAI failed: \(error.localizedDescription)"
                            await MainActor.run {
                                self.notify(title: "OpenAI Error", body: error.localizedDescription)
                                self.log("OpenAI failed: \(error.localizedDescription). Using transcript.")
                            }
                        }
                    }
                }

                try? FileManager.default.removeItem(at: audioURL)

                await MainActor.run {
                    self.lastTranscript = outputText
                    self.status = .idle
                    self.lastError = openAIErrorMessage
                    self.log("Output ready (\(outputText.count) chars)")
                    do {
                        let result = try dispatcher.dispatch(text: outputText, autoPaste: autoPaste)
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
        hotKeyMonitor = HotKeyMonitor(triggerProvider: { [weak self] in
            self?.settings.recordingHotKey ?? .doubleCommand
        }) { [weak self] in
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

    func requestAccessibilityPermissionIfNeeded() {
        guard settings.autoPaste else { return }
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else { return }
        NSWorkspace.shared.open(url)
    }

    func openLogFile() {
        logger.add("Opened log file")
        NSWorkspace.shared.activateFileViewerSelecting([logger.logFileURL()])
    }

    func runOpenAITest() {
        let openAIKey = settings.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIModel = settings.openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIUserPrompt = settings.openAIUserPrompt

        openAITestIsError = false
        openAITestMessage = "Testing OpenAI..."

        guard !openAIKey.isEmpty else {
            openAITestIsError = true
            openAITestMessage = "OpenAI API key is missing."
            return
        }

        let resolvedModel = OpenAIModel(rawValue: openAIModel)?.rawValue ?? OpenAIClient.defaultModel
        let trimmedUserPrompt = openAIUserPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedSystemPrompt: String
        if trimmedUserPrompt.isEmpty {
            combinedSystemPrompt = OpenAIClient.defaultSystemPrompt
        } else {
            combinedSystemPrompt = OpenAIClient.defaultSystemPrompt + "\n\n追加の指示:\n" + trimmedUserPrompt
        }

        Task.detached(priority: .userInitiated) { [openAIClient, logger] in
            do {
                let temperature = OpenAIClient.supportsTemperature(model: resolvedModel)
                    ? 0.0
                    : nil
                let maxOutputTokens = OpenAIClient.prefersUnboundedOutput(model: resolvedModel)
                    ? nil
                    : 80
                let response = try await openAIClient.generateResponse(
                    input: "えーと、今日のやることなんだけど、まず `Sources/UsualToneOfVoice/AppModel.swift` を見直してOpenAI Testの結果を確認する。それから `xcodebuild -project UsualToneOfVoiceApp.xcodeproj -scheme UsualToneOfVoice build` を一回通して、問題なければノートに貼りたい。",
                    apiKey: openAIKey,
                    model: resolvedModel,
                    systemPrompt: combinedSystemPrompt,
                    maxOutputTokens: maxOutputTokens,
                    temperature: temperature
                )
                await MainActor.run {
                    self.openAITestIsError = false
                    self.openAITestMessage = "Success: \(response)"
                    logger.add("OpenAI test succeeded")
                }
            } catch {
                await MainActor.run {
                    self.openAITestIsError = true
                    self.openAITestMessage = "Error: \(error.localizedDescription)"
                    logger.add("OpenAI test failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func warmupDaemonIfNeeded() {
        // openai-whisper daemon no longer used in whisper.cpp-only mode
    }

    func requestMicrophoneAccess() async -> Bool {
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

    private func startSilenceMonitor() {
        stopSilenceMonitor()
        continuousSilenceDuration = 0
        hasPromptedForCurrentSilence = false
        isSilencePromptVisible = false

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(
            deadline: .now() + SilenceMonitoring.pollInterval,
            repeating: SilenceMonitoring.pollInterval
        )
        timer.setEventHandler { [weak self] in
            self?.checkForLongSilence()
        }
        silenceMonitorTimer = timer
        timer.resume()
    }

    private func stopSilenceMonitor() {
        silenceMonitorTimer?.cancel()
        silenceMonitorTimer = nil
        continuousSilenceDuration = 0
        hasPromptedForCurrentSilence = false
        isSilencePromptVisible = false
    }

    private func checkForLongSilence() {
        guard status == .recording else { return }
        guard let averagePower = recorder.averagePower() else { return }

        if averagePower <= SilenceMonitoring.silenceThresholdDB {
            continuousSilenceDuration += SilenceMonitoring.pollInterval
        } else {
            continuousSilenceDuration = 0
            hasPromptedForCurrentSilence = false
        }

        guard continuousSilenceDuration >= SilenceMonitoring.promptAfter,
              !hasPromptedForCurrentSilence,
              !isSilencePromptVisible
        else {
            return
        }

        hasPromptedForCurrentSilence = true
        promptToStopLongSilenceRecording()
    }

    private func promptToStopLongSilenceRecording() {
        guard status == .recording else { return }
        isSilencePromptVisible = true
        defer { isSilencePromptVisible = false }

        let silenceMinutes = Int(continuousSilenceDuration / 60)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "無音の録音が続いています"
        if silenceMinutes > 0 {
            alert.informativeText = "\(silenceMinutes)分以上ほぼ無音です。録音を停止しますか？"
        } else {
            alert.informativeText = "しばらく無音です。録音を停止しますか？"
        }
        alert.addButton(withTitle: "停止する")
        alert.addButton(withTitle: "続ける")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            Task { await stopRecording() }
        } else {
            continuousSilenceDuration = 0
            hasPromptedForCurrentSilence = false
        }
    }

    private func shouldIgnoreSilentRecording(at audioURL: URL) -> Bool {
        do {
            let analysis = try AudioSilenceAnalyzer.analyze(
                url: audioURL,
                silenceThresholdDB: SilenceMonitoring.silenceThresholdDB
            )
            return analysis.activeDuration < SilenceMonitoring.minSpeechDuration
        } catch {
            log("Audio silence analysis failed: \(error.localizedDescription)")
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

private enum SilenceMonitoring {
    static let silenceThresholdDB: Float = -45
    static let minSpeechDuration: TimeInterval = 0.35
    static let promptAfter: TimeInterval = 90
    static let pollInterval: TimeInterval = 1
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
