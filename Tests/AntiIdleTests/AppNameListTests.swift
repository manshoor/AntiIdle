import XCTest
@testable import AntiIdle

final class AppNameListTests: XCTestCase {

    // Names with inner spaces survive; outer spaces are trimmed.
    func testParseKeepsInnerSpaces() {
        XCTAssertEqual(AppNameList.parse(" Safari ,  VS Code "), ["Safari", "VS Code"])
    }

    // Trailing and repeated commas give no empty names.
    func testParseDropsEmptyEntries() {
        XCTAssertEqual(AppNameList.parse("Safari,,Slack,"), ["Safari", "Slack"])
    }

    func testParseEmptyText() {
        XCTAssertEqual(AppNameList.parse("   "), [])
    }

    func testFormatJoinsWithCommaSpace() {
        XCTAssertEqual(AppNameList.format(["Safari", "VS Code"]), "Safari, VS Code")
    }
}
