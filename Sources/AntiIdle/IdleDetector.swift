import CoreGraphics
import Foundation

final class IdleDetector {
    private let lock = NSLock()
    private var _lastActivityDate = Date()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoopThread: Thread?

    var lastActivityDate: Date {
        lock.lock()
        defer { lock.unlock() }
        return _lastActivityDate
    }

    init() {
        startEventTap()
    }

    deinit {
        stopEventTap()
    }

    func isUserActive(within seconds: TimeInterval) -> Bool {
        return Date().timeIntervalSince(lastActivityDate) < seconds
    }

    private func recordActivity() {
        lock.lock()
        _lastActivityDate = Date()
        lock.unlock()
    }

    private func startEventTap() {
        let eventMask: CGEventMask = (
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)
        )

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let detector = Unmanaged<IdleDetector>.fromOpaque(userInfo).takeUnretainedValue()
                detector.recordActivity()
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            print("AntiIdle: Could not create event tap. User activity detection disabled.")
            return
        }

        self.eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            print("AntiIdle: Could not create run loop source for event tap.")
            return
        }

        self.runLoopSource = source

        let thread = Thread { [weak self] in
            guard let source = self?.runLoopSource else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "AntiIdle.IdleDetector"
        thread.qualityOfService = .utility
        thread.start()
        self.runLoopThread = thread
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let thread = runLoopThread {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            thread.cancel()
        }
        eventTap = nil
        runLoopSource = nil
        runLoopThread = nil
    }
}
