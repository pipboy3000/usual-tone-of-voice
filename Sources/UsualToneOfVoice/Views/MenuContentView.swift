import SwiftUI
import AppKit
import ApplicationServices

struct MenuContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(model.status.label)
                    .font(.system(size: 12, weight: .semibold))
            }
            Text(statusLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Divider()

            Button(model.status == .recording ? "Stop Recording" : "Start Recording") {
                model.toggleRecording()
            }

            if !model.lastTranscript.isEmpty {
                Button("Copy & Paste Last Output") {
                    do {
                        _ = try Dispatcher().dispatch(text: model.lastTranscript, autoPaste: model.settings.autoPaste)
                    } catch {
                        model.lastError = error.localizedDescription
                    }
                }
            }

            Divider()
            Button("Settings") {
                model.showSettings()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private var statusLine: String {
        if settings.autoPaste && !AXIsProcessTrusted() {
            return "Auto Paste needs Accessibility permission"
        }
        return model.statusLine
    }

    private var statusColor: Color {
        switch model.status {
        case .idle: return .gray
        case .recording: return .red
        case .transcribing: return .orange
        }
    }
}
