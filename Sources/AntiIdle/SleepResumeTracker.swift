import Foundation

/// Whether simulation is running when a power event arrives.
enum RunState {
    case running
    case stopped
}

/// What the manager should do in response to a power event.
enum PowerAction {
    case pause
    case resume
    case none
}

/// Remembers whether a sleep/lock event paused the app, so the matching
/// wake/unlock can resume it. Lock, display sleep and system sleep can
/// all arrive for one absence:
///
///   lock ──► pause (flag set)
///   display sleep ──► already stopped, flag kept
///   unlock ──► resume (flag cleared)
struct SleepResumeTracker {
    private var pausedBySleep = false

    mutating func onSleep(_ state: RunState) -> PowerAction {
        // Already stopped: keep any flag an earlier event set.
        guard state == .running else {
            return .none
        }
        pausedBySleep = true
        return .pause
    }

    mutating func onWake() -> PowerAction {
        guard pausedBySleep else {
            return .none
        }
        pausedBySleep = false
        return .resume
    }

    /// A manual toggle overrides any pending auto-resume.
    mutating func reset() {
        pausedBySleep = false
    }
}
