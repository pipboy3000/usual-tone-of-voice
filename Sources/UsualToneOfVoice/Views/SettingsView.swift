import SwiftUI
import AppKit
import ApplicationServices
import AVFoundation

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var model: AppModel
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("App") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    ))
                    if let message = launchAtLoginManager.statusMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if let error = launchAtLoginManager.lastError, !error.isEmpty {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 4)
            }
            if let status = model.modelDownloadStatusText {
                VStack(alignment: .leading, spacing: 6) {
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                    if let progress = model.modelDownloadProgress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }
                }
                .padding(.bottom, 4)
            }
            GroupBox("Transcription") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Language") {
                        TextField("ja", text: $settings.language)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack(spacing: 8) {
                        Circle()
                            .fill(microphoneStatus == .authorized ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(microphoneStatusText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if microphoneStatus == .notDetermined {
                            Button("Request Permission") {
                                Task {
                                    _ = await model.requestMicrophoneAccess()
                                    refreshPermissionStatus()
                                }
                            }
                        } else if microphoneStatus == .denied || microphoneStatus == .restricted {
                            HStack(spacing: 8) {
                                Button("Open Microphone Settings") {
                                    model.openMicrophoneSettings()
                                }
                                Button("Refresh Status") {
                                    refreshPermissionStatus()
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto Paste", isOn: $settings.autoPaste)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accessibilityTrusted ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(accessibilityTrusted ? "Accessibility: Granted" : "Accessibility: Not granted")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !accessibilityTrusted {
                            Button("Request Permission") {
                                Task {
                                    model.requestAccessibilityPermission()
                                    refreshPermissionStatus()
                                }
                            }
                        }
                    }
                    if settings.autoPaste && !accessibilityTrusted {
                        Text("Auto Paste requires Accessibility permission.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("Open Accessibility Settings") {
                                model.openAccessibilitySettings()
                            }
                            Button("Refresh Status") {
                                refreshPermissionStatus()
                            }
                        }
                    }
                }
            }

            GroupBox("OpenAI") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable OpenAI", isOn: $settings.openAIEnabled)
                    LabeledContent("API Key") {
                        TextField("sk-...", text: $settings.openAIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    if settings.openAIEnabled && settings.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("API key is required.")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    LabeledContent("Model") {
                        Picker("", selection: $settings.openAIModel) {
                            ForEach(OpenAIModel.allCases) { model in
                                Text(model.displayName).tag(model.rawValue)
                            }
                        }
                        .labelsHidden()
                    }
                    HStack {
                        Button("OpenAI Test") {
                            model.runOpenAITest()
                        }
                        Spacer()
                    }
                    Text("Prompt")
                        .font(.system(size: 12, weight: .semibold))
                    InsetTextEditor(text: $settings.openAIUserPrompt, fontSize: 12, inset: 6)
                        .frame(minHeight: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                    HStack {
                        Button("Reset") {
                            settings.resetOpenAIUserPrompt()
                        }
                        .buttonStyle(.link)
                        Spacer()
                    }
                    Divider()
                    HStack(spacing: 8) {
                        Button("Open User Dictionary") {
                            UserDictionary.ensureDefaultFile()
                            NSWorkspace.shared.open(UserDictionary.dictionaryURL())
                        }
                        Button("Open Logs") {
                            model.openLogFile()
                        }
                    }
                    if let message = model.openAITestMessage, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(model.openAITestIsError ? .red : .secondary)
                    }
                    if let error = settings.openAIKeyError, !error.isEmpty {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
            }

        }
        .padding(20)
        .frame(minWidth: 520)
        .onChange(of: settings.autoPaste) { _, _ in
            model.requestAccessibilityPermissionIfNeeded()
            refreshPermissionStatus()
        }
        .onAppear {
            refreshPermissionStatus()
            launchAtLoginManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
            launchAtLoginManager.refresh()
        }
    }

    private func refreshPermissionStatus() {
        accessibilityTrusted = AXIsProcessTrusted()
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized:
            return "Microphone: Granted"
        case .notDetermined:
            return "Microphone: Not requested"
        case .denied, .restricted:
            return "Microphone: Not granted"
        @unknown default:
            return "Microphone: Unknown"
        }
    }
}
