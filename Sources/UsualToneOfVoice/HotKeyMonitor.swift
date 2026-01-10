import AppKit

final class HotKeyMonitor {
    private let action: () -> Void
    private var lastCommandDown: TimeInterval = 0
    private let threshold: TimeInterval = 0.35

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(action: @escaping () -> Void) {
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
        let relevantFlags = event.modifierFlags.intersection([.command, .option, .shift, .control, .function])
        guard relevantFlags == [.command] else { return }
        guard event.keyCode == 54 || event.keyCode == 55 else { return }

        let isDown = event.modifierFlags.contains(.command)
        guard isDown else { return }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastCommandDown < threshold {
            lastCommandDown = 0
            action()
        } else {
            lastCommandDown = now
        }
    }
}
