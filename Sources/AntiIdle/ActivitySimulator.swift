import CoreGraphics
import ApplicationServices
import Foundation

enum ActivitySimulator {

    // MARK: - Mouse Jitter (existing, 1-2px invisible)

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

        usleep(UInt32.random(in: 50_000...100_000))

        guard let returnEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: currentPos,
            mouseButton: .left
        ) else { return nil }
        returnEvent.post(tap: .cghidEventTap)

        return "Mouse jitter (\(Int(dx)),\(Int(dy)))"
    }

    // MARK: - Shift Keypress (existing)

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

    // MARK: - Visible Mouse Movement

    static func simulateVisibleMovement(radius: MovementRadius) -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let currentPos = CGEvent(source: nil)?.location else { return nil }

        // Random angle and distance
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: radius.range)

        var targetX = currentPos.x + cos(angle) * distance
        var targetY = currentPos.y + sin(angle) * distance

        // Clamp to screen bounds (thread-safe)
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        let margin: CGFloat = 10
        targetX = max(margin, min(targetX, screenBounds.width - margin))
        targetY = max(margin, min(targetY, screenBounds.height - margin))

        let target = CGPoint(x: targetX, y: targetY)

        // Animate with intermediate steps for smooth movement
        let steps = Int.random(in: 8...15)
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let intermediateX = currentPos.x + (target.x - currentPos.x) * t
            let intermediateY = currentPos.y + (target.y - currentPos.y) * t
            let intermediatePos = CGPoint(x: intermediateX, y: intermediateY)

            guard let moveEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: intermediatePos,
                mouseButton: .left
            ) else { return nil }
            moveEvent.post(tap: .cghidEventTap)
            usleep(UInt32.random(in: 15_000...30_000)) // 15-30ms between steps
        }

        let movedDistance = Int(sqrt(pow(target.x - currentPos.x, 2) + pow(target.y - currentPos.y, 2)))
        return "Visible move (\(movedDistance)px)"
    }

    // MARK: - Keep-Alive Click

    static func simulateKeepAliveClick() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let currentPos = CGEvent(source: nil)?.location else { return nil }

        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: currentPos,
            mouseButton: .left
        ) else { return nil }
        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseDown.post(tap: .cghidEventTap)

        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: currentPos,
            mouseButton: .left
        ) else { return nil }
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
        mouseUp.post(tap: .cghidEventTap)

        return "Keep-alive click at (\(Int(currentPos.x)),\(Int(currentPos.y)))"
    }

    // MARK: - Burst Clicks

    static func simulateBurstClicks(count: Int) -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let currentPos = CGEvent(source: nil)?.location else { return nil }

        var completed = 0
        for _ in 0..<count {
            guard let mouseDown = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: currentPos,
                mouseButton: .left
            ) else { break }
            mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
            mouseDown.post(tap: .cghidEventTap)

            guard let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: currentPos,
                mouseButton: .left
            ) else { break }
            mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
            mouseUp.post(tap: .cghidEventTap)

            completed += 1
            usleep(UInt32.random(in: 10_000...30_000)) // 10-30ms between clicks
        }

        return "Burst: \(completed) clicks"
    }

    // MARK: - Drag Gesture

    static func simulateDragGesture() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let startPos = CGEvent(source: nil)?.location else { return nil }

        // Random direction and distance
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let totalDistance = CGFloat.random(in: 30...100)
        let steps = Int.random(in: 5...8)

        var endX = startPos.x + cos(angle) * totalDistance
        var endY = startPos.y + sin(angle) * totalDistance

        // Clamp to screen
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        endX = max(10, min(endX, screenBounds.width - 10))
        endY = max(10, min(endY, screenBounds.height - 10))

        // Mouse down at start
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: startPos,
            mouseButton: .left
        ) else { return nil }
        mouseDown.post(tap: .cghidEventTap)

        // Drag through intermediate points
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pos = CGPoint(
                x: startPos.x + (endX - startPos.x) * t,
                y: startPos.y + (endY - startPos.y) * t
            )

            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: pos,
                mouseButton: .left
            ) else { break }
            dragEvent.post(tap: .cghidEventTap)
            usleep(UInt32.random(in: 20_000...40_000)) // 20-40ms between points
        }

        // Mouse up at end
        let endPos = CGPoint(x: endX, y: endY)
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: endPos,
            mouseButton: .left
        ) else { return nil }
        mouseUp.post(tap: .cghidEventTap)

        let direction: String
        let angleDeg = angle * 180 / .pi
        switch angleDeg {
        case 315...360, 0..<45:   direction = "right"
        case 45..<135:            direction = "down"
        case 135..<225:           direction = "left"
        default:                  direction = "up"
        }

        return "Drag \(Int(totalDistance))px \(direction)"
    }

    // MARK: - Scroll Drag (vertical)

    static func simulateScrollDrag() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let startPos = CGEvent(source: nil)?.location else { return nil }

        // Vertical direction: up or down
        let goingDown = Bool.random()
        let totalDistance = CGFloat.random(in: 50...150)
        let signedDistance = goingDown ? totalDistance : -totalDistance
        let steps = Int.random(in: 5...8)

        var endY = startPos.y + signedDistance
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        endY = max(10, min(endY, screenBounds.height - 10))

        // Mouse down
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: startPos,
            mouseButton: .left
        ) else { return nil }
        mouseDown.post(tap: .cghidEventTap)

        // Vertical drag
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let pos = CGPoint(
                x: startPos.x,
                y: startPos.y + signedDistance * t
            )

            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: pos,
                mouseButton: .left
            ) else { break }
            dragEvent.post(tap: .cghidEventTap)
            usleep(UInt32.random(in: 20_000...40_000))
        }

        // Mouse up
        let endPos = CGPoint(x: startPos.x, y: endY)
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: endPos,
            mouseButton: .left
        ) else { return nil }
        mouseUp.post(tap: .cghidEventTap)

        return "Scroll drag \(Int(abs(signedDistance)))px \(goingDown ? "down" : "up")"
    }
}
