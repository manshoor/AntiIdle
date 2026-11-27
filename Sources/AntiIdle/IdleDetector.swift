import CoreGraphics
import Foundation

final class IdleDetector {
    private let lock = NSLock()
    private var _lastActivityDate = Date()

    // Guarded by lock: the tap thread reads it to re-enable the tap.
    private var _eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoopThread: Thread?
    private var hasLoggedTapFailure = false

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

    /// Starts the event tap if it is not running. Safe to call repeatedly,
    /// e.g. after Accessibility permission is granted. Main thread only.
    func ensureEventTap() {
        guard runLoopThread == nil else {
            return
        }
        startEventTap()
    }

    func isUserActive(within seconds: TimeInterval) -> Bool {
        return Date().timeIntervalSince(lastActivityDate) < seconds
    }

    private func recordActivity() {
        lock.lock()
        _lastActivityDate = Date()
        lock.unlock()
    }

    // macOS disables a tap that is slow or blocked by user input; turn it back on.
    private func reenableEventTap() {
        lock.lock()
        let tap = _eventTap
        lock.unlock()
        guard let tap = tap else {
            return
        }
        CGEvent.tapEnable(tap: tap, enable: true)
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

                // Disable notices are not user input.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    detector.reenableEventTap()
                    return Unmanaged.passUnretained(event)
                }

                // Our own simulated events are not user activity.
                if SyntheticEventTag.isTagged(event) {
                    return Unmanaged.passUnretained(event)
                }

                detector.recordActivity()
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            // Usually missing permission; ensureEventTap retries later. Log once.
            if !hasLoggedTapFailure {
                print("AntiIdle: Could not create event tap. Will retry.")
                hasLoggedTapFailure = true
            }
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            print("AntiIdle: Could not create run loop source for event tap.")
            CFMachPortInvalidate(tap)
            return
        }

        lock.lock()
        _eventTap = tap
        lock.unlock()
        self.runLoopSource = source

        // Capture tap and source so the thread never reads self's properties.
        let thread = Thread {
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
        lock.lock()
        let tap = _eventTap
        _eventTap = nil
        lock.unlock()
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let thread = runLoopThread {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            thread.cancel()
        }
        runLoopSource = nil
        runLoopThread = nil
    }
}
