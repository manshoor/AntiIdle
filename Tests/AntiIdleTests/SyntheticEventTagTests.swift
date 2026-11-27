import XCTest
import CoreGraphics
@testable import AntiIdle

// Events are created but never posted.
final class SyntheticEventTagTests: XCTestCase {

    func testUntaggedEventIsNotSynthetic() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        XCTAssertFalse(SyntheticEventTag.isTagged(event))
    }

    func testTaggedEventIsSynthetic() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        SyntheticEventTag.apply(to: event)
        XCTAssertTrue(SyntheticEventTag.isTagged(event))
    }

    // Another app's user data must not count as ours.
    func testOtherUserDataIsNotSynthetic() throws {
        let event = try XCTUnwrap(CGEvent(source: nil))
        event.setIntegerValueField(.eventSourceUserData, value: 42)
        XCTAssertFalse(SyntheticEventTag.isTagged(event))
    }
}
