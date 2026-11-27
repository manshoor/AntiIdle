import XCTest
@testable import AntiIdle

final class ActionGateTests: XCTestCase {

    func testStartsStopped() {
        XCTAssertEqual(ActionGate().state, .stopped)
    }

    // An action queued before stop sees the gate closed when it runs.
    func testStopClosesGateForQueuedWork() {
        let gate = ActionGate()
        gate.set(.running)
        let queue = DispatchQueue(label: "test.gate")
        let ran = expectation(description: "queued work ran")
        var seen: RunState?

        queue.async {
            usleep(50_000)
            seen = gate.state
            ran.fulfill()
        }
        gate.set(.stopped)

        wait(for: [ran], timeout: 1)
        XCTAssertEqual(seen, .stopped)
    }
}

final class ActionGateTicketTests: XCTestCase {

    func testTicketAdmittedWhileRunning() {
        let gate = ActionGate()
        gate.set(.running)
        XCTAssertTrue(gate.admits(gate.ticket()))
    }

    func testTicketRejectedAfterStop() {
        let gate = ActionGate()
        gate.set(.running)
        let ticket = gate.ticket()
        gate.set(.stopped)
        XCTAssertFalse(gate.admits(ticket))
    }

    // Stop then start while an action is queued: the stale action must not run.
    func testTicketRejectedAfterStopThenStart() {
        let gate = ActionGate()
        gate.set(.running)
        let stale = gate.ticket()
        gate.set(.stopped)
        gate.set(.running)
        XCTAssertFalse(gate.admits(stale))
        XCTAssertTrue(gate.admits(gate.ticket()))
    }
}
