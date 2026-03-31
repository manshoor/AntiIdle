import CoreGraphics
import ApplicationServices
import Foundation

enum ActivitySimulator {
    static func simulateMouseJitter() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let currentPos = CGEvent(source: nil)?.location else { return nil }

        let offsets: [CGFloat] = [-2, -1, 1, 2]
        let dx = offsets.randomElement()!
        let dy = offsets.randomElement()!
        let jitteredPos = CGPoint(x: currentPos.x + dx, y: currentPos.y + dy)

        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: jitteredPos,
            mouseButton: .left
        ) else { return nil }
        moveEvent.post(tap: .cghidEventTap)

        let delayMicroseconds = UInt32.random(in: 50_000...100_000)
        usleep(delayMicroseconds)

        guard let returnEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: currentPos,
            mouseButton: .left
        ) else { return nil }
        returnEvent.post(tap: .cghidEventTap)

        return "Mouse jitter (\(Int(dx)),\(Int(dy)))"
    }

    static func simulateKeypress() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }

        let shiftKeyCode: UInt16 = 0x38

        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shiftKeyCode,
            keyDown: true
        ) else { return nil }
        keyDown.post(tap: .cghidEventTap)

        guard let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: shiftKeyCode,
            keyDown: false
        ) else { return nil }
        keyUp.post(tap: .cghidEventTap)

        return "Shift key press"
    }
}
