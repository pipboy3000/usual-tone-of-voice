import SwiftUI
import AppKit
import ApplicationServices

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                }
                .padding(.top, 4)
            }

            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Auto Paste", isOn: $settings.autoPaste)
                    if settings.autoPaste && !AXIsProcessTrusted() {
                        Text("Auto Paste requires Accessibility permission.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Button("Open Accessibility Settings") {
                            model.openAccessibilitySettings()
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
                        Button("OpenAI Test") {
                            model.runOpenAITest()
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
            model.ensureAccessibilityPermissionIfNeeded()
        }
    }
}
