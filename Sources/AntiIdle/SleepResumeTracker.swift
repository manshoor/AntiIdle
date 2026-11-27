import Foundation

/// Whether simulation is running when a power event arrives.
enum RunState {
    case running
    case stopped
}

/// Sleep, wake and screen-lock notifications, as the tracker sees them.
enum PowerEvent {
    /// Screen locked.
    case lock
    /// Screen unlocked.
    case unlock
    /// Display or system sleep.
    case sleep
    /// Display or system wake.
    case wake
}

/// What the manager should do in response to a power event.
enum PowerAction {
    case pause
    case resume
    case none
}

/// Remembers whether a power event paused the app, so the matching
/// unlock or wake can resume it. Several events can arrive for one
/// absence; while the screen is locked only unlock resumes:
///
///   lock ──► pause (flag set)
///   display sleep ──► already stopped, flag kept
///   display wake ──► still locked, ignored
///   unlock ──► resume (flag cleared)
struct SleepResumeTracker {
    private var pausedBySleep = false
    private var isLocked = false

    mutating func handle(_ event: PowerEvent, _ state: RunState) -> PowerAction {
        switch event {
        case .lock:
            isLocked = true
            return pause(state)
        case .sleep:
            return pause(state)
        case .unlock:
            isLocked = false
            return resume()
        case .wake:
            // Display wake at the lock screen: wait for unlock.
            guard !isLocked else {
                return .none
            }
            return resume()
        }
    }

    /// A manual toggle overrides any pending auto-resume. The lock state
    /// is kept: it reflects the real screen.
    mutating func reset() {
        pausedBySleep = false
    }

    // Already stopped: keep any flag an earlier event set.
    private mutating func pause(_ state: RunState) -> PowerAction {
        guard state == .running else {
            return .none
        }
        pausedBySleep = true
        return .pause
    }

    private mutating func resume() -> PowerAction {
        guard pausedBySleep else {
            return .none
        }
        pausedBySleep = false
        return .resume
    }
}
