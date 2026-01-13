import Foundation
import AppKit
import ApplicationServices

struct DispatchResult {
    let didPaste: Bool
}

final class Dispatcher {
    func dispatch(text: String, autoPaste: Bool) throws -> DispatchResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard autoPaste else {
            return DispatchResult(didPaste: false)
        }

        guard AXIsProcessTrusted() else {
            throw DispatchError.accessibilityDenied
        }

        sendPasteCommand()
        return DispatchResult(didPaste: true)
    }

    private func sendPasteCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode: CGKeyCode = 9 // v

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

enum DispatchError: LocalizedError {
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required for auto paste"
        }
    }
}
