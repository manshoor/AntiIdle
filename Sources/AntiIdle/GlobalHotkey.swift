import AppKit

final class GlobalHotkey {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let action: () -> Void

    private let targetKeyCode: UInt16 = 0x28
    private let targetModifiers: NSEvent.ModifierFlags = [.command, .shift]

    init(action: @escaping () -> Void) {
        self.action = action
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isTargetShortcut(event) == true {
                self?.action()
                return nil
            }
            return event
        }
    }

    private func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if isTargetShortcut(event) {
            action()
        }
    }

    private func isTargetShortcut(_ event: NSEvent) -> Bool {
        guard event.keyCode == targetKeyCode else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(targetModifiers)
    }
}
