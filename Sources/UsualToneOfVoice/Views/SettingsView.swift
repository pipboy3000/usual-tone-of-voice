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
                    Text("Initial Prompt")
                        .font(.system(size: 12, weight: .semibold))
                    Text("用語や口調に寄せるための弱いヒントです。効果は保証されず、要約や書き換えには向きません。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    InsetTextEditor(text: $settings.initialPrompt, fontSize: 12, inset: 6)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2))
                        )
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

            Button("Open User Dictionary") {
                UserDictionary.ensureDefaultFile()
                NSWorkspace.shared.open(UserDictionary.dictionaryURL())
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .onChange(of: settings.autoPaste) { _, _ in
            model.ensureAccessibilityPermissionIfNeeded()
        }
    }
}
