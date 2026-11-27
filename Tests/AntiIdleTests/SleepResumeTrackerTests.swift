import XCTest
@testable import AntiIdle

final class SleepResumeTrackerTests: XCTestCase {

    // Lock pauses; the later display-sleep event must not erase that.
    func testLockThenDisplaySleepThenUnlockResumes() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.onSleep(.running), .pause)
        XCTAssertEqual(tracker.onSleep(.stopped), .none)
        XCTAssertEqual(tracker.onWake(), .resume)
    }

    // A second wake after resuming does nothing.
    func testResumesOnlyOnce() {
        var tracker = SleepResumeTracker()
        _ = tracker.onSleep(.running)
        XCTAssertEqual(tracker.onWake(), .resume)
        XCTAssertEqual(tracker.onWake(), .none)
    }

    // Paused by the user before locking: stay paused.
    func testStoppedBeforeSleepStaysStopped() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.onSleep(.stopped), .none)
        XCTAssertEqual(tracker.onWake(), .none)
    }

    // Manual toggle while locked cancels the pending resume.
    func testResetCancelsPendingResume() {
        var tracker = SleepResumeTracker()
        _ = tracker.onSleep(.running)
        tracker.reset()
        XCTAssertEqual(tracker.onWake(), .none)
    }
}
