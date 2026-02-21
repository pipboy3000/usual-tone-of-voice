import AppKit

final class HotKeyMonitor {
    private let triggerProvider: () -> RecordingHotKey
    private let action: () -> Void
    private var lastTriggerDown: TimeInterval = 0
    private let threshold: TimeInterval = 0.35

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(triggerProvider: @escaping () -> RecordingHotKey, action: @escaping () -> Void) {
        self.triggerProvider = triggerProvider
        self.action = action
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        let trigger = triggerProvider()
        let relevantFlags = event.modifierFlags.intersection([.command, .option, .shift, .control, .function])
        guard relevantFlags == [trigger.modifierFlag] else { return }
        guard trigger.keyCodes.contains(event.keyCode) else { return }

        let isDown = event.modifierFlags.contains(trigger.modifierFlag)
        guard isDown else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTriggerDown < threshold {
            lastTriggerDown = 0
            action()
        } else {
            lastTriggerDown = now
        }
    }
}

private extension RecordingHotKey {
    var modifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .doubleCommand:
            return .command
        case .doubleOption:
            return .option
        case .doubleControl:
            return .control
        case .doubleShift:
            return .shift
        }
    }

    var keyCodes: Set<UInt16> {
        switch self {
        case .doubleCommand:
            return [54, 55]
        case .doubleOption:
            return [58, 61]
        case .doubleControl:
            return [59, 62]
        case .doubleShift:
            return [56, 60]
        }
    }
}
