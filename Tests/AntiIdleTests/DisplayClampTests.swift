import XCTest
@testable import AntiIdle

final class DisplayClampTests: XCTestCase {
    private let margin: CGFloat = 10

    // Main 1920x1080 at origin, a 1440x900 display to its left, and a
    // 1920x1080 display above it.
    private let main = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
    private let above = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
    private var displays: [CGRect] { [main, left, above] }

    func testPointOnLeftDisplayStays() {
        let p = CGPoint(x: -700, y: 400)
        XCTAssertEqual(DisplayClamp.clamp(p, to: displays, margin: margin), p)
    }

    func testPointOnDisplayAboveStays() {
        let p = CGPoint(x: 500, y: -500)
        XCTAssertEqual(DisplayClamp.clamp(p, to: displays, margin: margin), p)
    }

    // Inside the left display's margin: pulled in from its left edge.
    func testMarginOnNegativeOriginDisplay() {
        let p = CGPoint(x: -1438, y: 400)
        XCTAssertEqual(DisplayClamp.clamp(p, to: displays, margin: margin), CGPoint(x: -1430, y: 400))
    }

    // Below the shorter left display, in no display: clamp to the nearest.
    func testPointInGapGoesToNearestDisplay() {
        let p = CGPoint(x: -700, y: 1000)
        XCTAssertEqual(DisplayClamp.clamp(p, to: displays, margin: margin), CGPoint(x: -700, y: 890))
    }

    func testMarginOnMainDisplay() {
        let p = CGPoint(x: 5, y: 1078)
        XCTAssertEqual(DisplayClamp.clamp(p, to: displays, margin: margin), CGPoint(x: 10, y: 1070))
    }

    func testNoDisplaysReturnsPoint() {
        let p = CGPoint(x: -5, y: -5)
        XCTAssertEqual(DisplayClamp.clamp(p, to: [], margin: margin), p)
    }
}
