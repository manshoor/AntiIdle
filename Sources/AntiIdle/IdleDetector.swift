import CoreGraphics
import Foundation

final class IdleDetector {
    private let lock = NSLock()
    private var _lastActivityDate = Date()

    // Guarded by lock: the tap thread reads it to re-enable the tap.
    private var _eventTap: CFMachPort?
    // Guarded by lock: the tap thread's run loop, so teardown can stop it.
    private var _tapRunLoop: CFRunLoop?
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

    /// Starts the event tap if it is not running, and re-enables or
    /// rebuilds one macOS turned off. Safe to call repeatedly, e.g. after
    /// Accessibility permission is granted. Main thread only.
    func ensureEventTap() {
        if let tap = currentTap() {
            guard !CGEvent.tapIsEnabled(tap: tap) else {
                return
            }
            CGEvent.tapEnable(tap: tap, enable: true)
            guard !CGEvent.tapIsEnabled(tap: tap) else {
                return
            }
            // Re-enable failed (e.g. permission revoked, then granted): rebuild.
            stopEventTap()
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

    private func currentTap() -> CFMachPort? {
        lock.lock()
        defer { lock.unlock() }
        return _eventTap
    }

    // macOS disables a tap that is slow or blocked by user input; turn it back on.
    private func reenableEventTap() {
        guard let tap = currentTap() else {
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

        // Capture tap and source so the thread never reads self's properties;
        // record this thread's run loop so teardown can stop it.
        let thread = Thread { [weak self] in
            guard let runLoop = CFRunLoopGetCurrent() else {
                return
            }
            self?.storeTapRunLoop(runLoop)
            CFRunLoopAddSource(runLoop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "AntiIdle.IdleDetector"
        thread.qualityOfService = .utility
        thread.start()
        self.runLoopThread = thread
    }

    private func storeTapRunLoop(_ runLoop: CFRunLoop) {
        lock.lock()
        _tapRunLoop = runLoop
        lock.unlock()
    }

    // Disable and invalidate the tap, then stop its thread's run loop.
    // Invalidating the port also removes its source, so CFRunLoopRun
    // returns even if the stop arrives before the loop starts.
    private func stopEventTap() {
        lock.lock()
        let tap = _eventTap
        let runLoop = _tapRunLoop
        _eventTap = nil
        _tapRunLoop = nil
        lock.unlock()

        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoop = runLoop {
            CFRunLoopStop(runLoop)
        }
        runLoopSource = nil
        runLoopThread = nil
    }
}
