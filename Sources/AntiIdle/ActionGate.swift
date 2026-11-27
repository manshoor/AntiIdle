import Foundation

/// Running state that the timer queue can read safely. Main sets it on
/// start and stop; performAction checks it so actions queued before a
/// stop, pause or lock do not run.
final class ActionGate {
    private let lock = NSLock()
    private var _state: RunState = .stopped

    var state: RunState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    func set(_ newState: RunState) {
        lock.lock()
        _state = newState
        lock.unlock()
    }
}
