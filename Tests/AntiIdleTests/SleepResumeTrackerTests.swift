import XCTest
@testable import AntiIdle

final class SleepResumeTrackerTests: XCTestCase {

    // Lock pauses; the later display-sleep event must not erase that.
    func testLockThenDisplaySleepThenUnlockResumes() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.handle(.lock, .running), .pause)
        XCTAssertEqual(tracker.handle(.sleep, .stopped), .none)
        XCTAssertEqual(tracker.handle(.unlock, .stopped), .resume)
    }

    // Display wake at the lock screen must not resume; unlock does.
    func testWakeWhileLockedWaitsForUnlock() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.handle(.lock, .running), .pause)
        XCTAssertEqual(tracker.handle(.sleep, .stopped), .none)
        XCTAssertEqual(tracker.handle(.wake, .stopped), .none)
        XCTAssertEqual(tracker.handle(.unlock, .stopped), .resume)
    }

    // System sleep with no lock: wake resumes.
    func testSleepThenWakeWithoutLockResumes() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.handle(.sleep, .running), .pause)
        XCTAssertEqual(tracker.handle(.wake, .stopped), .resume)
    }

    // A second wake after resuming does nothing.
    func testResumesOnlyOnce() {
        var tracker = SleepResumeTracker()
        _ = tracker.handle(.sleep, .running)
        XCTAssertEqual(tracker.handle(.wake, .stopped), .resume)
        XCTAssertEqual(tracker.handle(.wake, .running), .none)
    }

    // Paused by the user before locking: stay paused.
    func testStoppedBeforeLockStaysStopped() {
        var tracker = SleepResumeTracker()
        XCTAssertEqual(tracker.handle(.lock, .stopped), .none)
        XCTAssertEqual(tracker.handle(.unlock, .stopped), .none)
    }

    // Manual toggle while locked cancels the pending resume.
    func testResetCancelsPendingResume() {
        var tracker = SleepResumeTracker()
        _ = tracker.handle(.lock, .running)
        tracker.reset()
        XCTAssertEqual(tracker.handle(.unlock, .stopped), .none)
    }
}
