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
