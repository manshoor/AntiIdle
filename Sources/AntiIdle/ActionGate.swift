import Foundation

/// Running state that the timer queue can read safely. Main sets it on
/// start and stop. dispatchAction takes a ticket; performAction runs
/// only if the ticket is still admitted, so actions queued before a
/// stop, pause or lock do not run, even after a later start.
final class ActionGate {
    /// Proof of which start an action was queued under.
    struct Ticket {
        fileprivate let generation: UInt64
    }

    private let lock = NSLock()
    private var _state: RunState = .stopped
    private var generation: UInt64 = 0

    var state: RunState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    func set(_ newState: RunState) {
        // Every start and stop invalidates tickets issued before it.
        lock.lock()
        _state = newState
        generation &+= 1
        lock.unlock()
    }

    func ticket() -> Ticket {
        lock.lock()
        defer { lock.unlock() }
        return Ticket(generation: generation)
    }

    func admits(_ ticket: Ticket) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _state == .running && ticket.generation == generation
    }
}
