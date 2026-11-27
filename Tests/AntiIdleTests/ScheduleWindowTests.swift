import XCTest
@testable import AntiIdle

final class ScheduleWindowTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int) -> Date {
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private let window = ScheduleWindow(startHour: 9, endHour: 18, days: .weekdays)

    // 2026-11-25 is a Wednesday.
    func testInsideHoursOnWeekday() {
        XCTAssertTrue(window.contains(date(2026, 11, 25, hour: 9), calendar: calendar))
        XCTAssertTrue(window.contains(date(2026, 11, 25, hour: 17), calendar: calendar))
    }

    // End hour is exclusive.
    func testOutsideHoursOnWeekday() {
        XCTAssertFalse(window.contains(date(2026, 11, 25, hour: 8), calendar: calendar))
        XCTAssertFalse(window.contains(date(2026, 11, 25, hour: 18), calendar: calendar))
    }

    // 2026-11-28 is a Saturday, 2026-11-29 a Sunday.
    func testWeekendExcludedWhenWeekdaysOnly() {
        XCTAssertFalse(window.contains(date(2026, 11, 28, hour: 10), calendar: calendar))
        XCTAssertFalse(window.contains(date(2026, 11, 29, hour: 10), calendar: calendar))
    }

    func testWeekendIncludedWhenAllDays() {
        let allDays = ScheduleWindow(startHour: 9, endHour: 18, days: .everyDay)
        XCTAssertTrue(allDays.contains(date(2026, 11, 28, hour: 10), calendar: calendar))
    }
}
