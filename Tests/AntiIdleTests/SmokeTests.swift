import XCTest
@testable import AntiIdle

// Proves the executable target links under test. Touches only a pure enum.
final class SmokeTests: XCTestCase {
    func testActionTypesExist() {
        XCTAssertFalse(ActionType.allCases.isEmpty)
    }
}
