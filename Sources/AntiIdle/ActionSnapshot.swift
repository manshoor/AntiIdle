import Foundation

/// Which days the schedule allows.
enum ScheduleDays {
    case weekdays
    case everyDay
}

/// Active hours, checked when an action fires. Pure so it can run off the
/// main thread and be tested.
struct ScheduleWindow {
    private static let sunday = 1
    private static let saturday = 7

    let startHour: Int
    let endHour: Int
    let days: ScheduleDays

    /// True when `date` falls in [startHour, endHour) on an allowed day.
    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)

        if days == .weekdays && (weekday == Self.sunday || weekday == Self.saturday) {
            return false
        }

        return hour >= startHour && hour < endHour
    }
}

/// Main-thread state an action needs, copied before the action runs on
/// the timer queue so that queue never reads shared mutable state.
struct ActionSnapshot {
    let config: ActionConfig
    /// nil when the schedule is off.
    let schedule: ScheduleWindow?
}
