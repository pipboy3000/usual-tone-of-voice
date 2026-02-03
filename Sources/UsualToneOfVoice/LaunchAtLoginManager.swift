import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String? = nil

    init() {
        let status = SMAppService.mainApp.status
        self.status = status
        self.isEnabled = status == .enabled
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        self.status = status
        self.isEnabled = status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    var statusMessage: String? {
        switch status {
        case .requiresApproval:
            return "Approval required in System Settings → General → Login Items."
        case .notFound:
            return "Login item not found. Move the app to /Applications and try again."
        default:
            return nil
        }
    }
}
