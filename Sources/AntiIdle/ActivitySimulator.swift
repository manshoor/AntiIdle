import CoreGraphics
import ApplicationServices
import AppKit
import Foundation

enum ActivitySimulator {

    // MARK: - Shared State

    /// Timestamp of last simulated event — used to distinguish our events from real user input
    static var lastSimulatedEventTime: Date = .distantPast

    // MARK: - Human Motion Utilities

    /// Event source that shares modifier/keyboard state with real HID events
    private static func humanEventSource() -> CGEventSource? {
        return CGEventSource(stateID: .combinedSessionState)
    }

    /// Cubic Bézier curve evaluation at parameter t
    private static func cubicBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        return CGPoint(
            x: uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x,
            y: uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        )
    }

    /// Smoothstep ease-in-out: slow start, fast middle, slow end
    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        return t * t * (3 - 2 * t)
    }

    /// Continuous random offset using Gaussian magnitude + uniform angle
    private static func continuousJitter(maxMagnitude: CGFloat = 3.0) -> CGPoint {
        // Box-Muller for magnitude
        let u1 = CGFloat.random(in: 0.001...1.0)
        let u2 = CGFloat.random(in: 0.0...1.0)
        let z = abs(sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2))
        let magnitude = min(max(z * (maxMagnitude / 2.5), 0.5), maxMagnitude)

        let angle = CGFloat.random(in: 0...(2 * .pi))
        return CGPoint(x: cos(angle) * magnitude, y: sin(angle) * magnitude)
    }

    /// Generate Bézier control points for a natural arc between two points
    private static func randomControlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = sqrt(dx * dx + dy * dy)

        // Perpendicular direction
        let perpX = -dy / max(dist, 1)
        let perpY = dx / max(dist, 1)

        // Random perpendicular offsets for natural curve
        let offset1 = CGFloat.random(in: -dist * 0.2...dist * 0.2)
        let offset2 = CGFloat.random(in: -dist * 0.2...dist * 0.2)

        // Control points at ~1/3 and ~2/3 along the segment with perturbation
        let t1 = CGFloat.random(in: 0.25...0.4)
        let t2 = CGFloat.random(in: 0.6...0.75)

        let cp1 = CGPoint(
            x: start.x + dx * t1 + perpX * offset1,
            y: start.y + dy * t1 + perpY * offset1
        )
        let cp2 = CGPoint(
            x: start.x + dx * t2 + perpX * offset2,
            y: start.y + dy * t2 + perpY * offset2
        )
        return (cp1, cp2)
    }

    /// Clamp point to screen bounds with margin
    private static func clampToScreen(_ point: CGPoint, margin: CGFloat = 10) -> CGPoint {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        return CGPoint(
            x: max(margin, min(point.x, bounds.width - margin)),
            y: max(margin, min(point.y, bounds.height - margin))
        )
    }

    /// Post a mouseMoved event using human event source
    @discardableResult
    private static func postMove(to point: CGPoint) -> Bool {
        let clamped = clampToScreen(point)
        guard let event = CGEvent(
            mouseEventSource: humanEventSource(),
            mouseType: .mouseMoved,
            mouseCursorPosition: clamped,
            mouseButton: .left
        ) else { return false }
        lastSimulatedEventTime = Date()
        event.post(tap: .cghidEventTap)
        return true
    }

    /// Current cursor position
    private static func cursorPosition() -> CGPoint? {
        return CGEvent(source: nil)?.location
    }

    // MARK: - Mouse Jitter (invisible micro-drift)

    static func simulateMouseJitter() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard var pos = cursorPosition() else { return nil }

        // 1-3 micro-movements, each a small continuous offset
        let moveCount = Int.random(in: 1...3)
        var totalDrift: CGFloat = 0

        for _ in 0..<moveCount {
            let jitter = continuousJitter(maxMagnitude: 3.0)
            pos = CGPoint(x: pos.x + jitter.x, y: pos.y + jitter.y)
            postMove(to: pos)
            totalDrift += sqrt(jitter.x * jitter.x + jitter.y * jitter.y)
            usleep(UInt32.random(in: 30_000...120_000))
        }

        // 20% chance: partial correction (hand settling) but NOT to exact origin
        if Double.random(in: 0...1) < 0.2 {
            let settle = continuousJitter(maxMagnitude: 1.5)
            pos = CGPoint(x: pos.x - settle.x * 0.4, y: pos.y - settle.y * 0.4)
            usleep(UInt32.random(in: 40_000...100_000))
            postMove(to: pos)
        }

        return "Mouse jitter (\(String(format: "%.1f", totalDrift))px drift)"
    }

    // MARK: - Shift Keypress

    static func simulateKeypress() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }

        // 20% chance: vary the modifier key
        let keyCode: UInt16
        let keyName: String
        let flag: CGEventFlags
        let roll = Double.random(in: 0...1)
        if roll < 0.2 {
            // Right shift
            keyCode = 0x3C
            keyName = "Right Shift"
            flag = .maskShift
        } else if roll < 0.3 {
            // Control
            keyCode = 0x3B
            keyName = "Control"
            flag = .maskControl
        } else if roll < 0.4 {
            // Option
            keyCode = 0x3A
            keyName = "Option"
            flag = .maskAlternate
        } else {
            // Left shift (default, 60% of the time)
            keyCode = 0x38
            keyName = "Shift"
            flag = .maskShift
        }

        func pressRelease(_ code: UInt16, _ modFlag: CGEventFlags) {
            guard let keyDown = CGEvent(
                keyboardEventSource: humanEventSource(),
                virtualKey: code,
                keyDown: true
            ) else { return }
            keyDown.flags = modFlag
            lastSimulatedEventTime = Date()
            keyDown.post(tap: .cghidEventTap)

            // Realistic hold time: 80-150ms
            usleep(UInt32.random(in: 80_000...150_000))

            guard let keyUp = CGEvent(
                keyboardEventSource: humanEventSource(),
                virtualKey: code,
                keyDown: false
            ) else { return }
            keyUp.flags = []
            lastSimulatedEventTime = Date()
            keyUp.post(tap: .cghidEventTap)
        }

        pressRelease(keyCode, flag)

        // 15% chance: double-tap
        if Double.random(in: 0...1) < 0.15 {
            usleep(UInt32.random(in: 150_000...300_000))
            pressRelease(keyCode, flag)
            return "\(keyName) key (double-tap)"
        }

        return "\(keyName) key press"
    }

    // MARK: - Visible Mouse Movement (Bézier curves)

    static func simulateVisibleMovement(radius: MovementRadius) -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard let startPos = cursorPosition() else { return nil }

        // Random target
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let distance = CGFloat.random(in: radius.range)
        let rawTarget = CGPoint(
            x: startPos.x + cos(angle) * distance,
            y: startPos.y + sin(angle) * distance
        )
        let target = clampToScreen(rawTarget)

        // Bézier control points for a natural arc
        let (cp1, cp2) = randomControlPoints(from: startPos, to: target)

        // More steps for smoother curves
        let steps = Int.random(in: 15...30)
        for i in 1...steps {
            let linearT = CGFloat(i) / CGFloat(steps)
            let easedT = easeInOut(linearT)

            // Bézier position + hand tremor
            var point = cubicBezierPoint(t: easedT, p0: startPos, p1: cp1, p2: cp2, p3: target)
            let tremor = continuousJitter(maxMagnitude: 0.5)
            point.x += tremor.x
            point.y += tremor.y

            postMove(to: point)

            // Variable timing: slower at start/end, faster in middle
            let speed = 4 * linearT * (1 - linearT) // parabola peaking at 0.5
            let baseDelay: UInt32 = 18_000
            let delay = UInt32(CGFloat(baseDelay) / max(speed + 0.3, 0.4))
            usleep(min(delay, 25_000) + UInt32.random(in: 0...5_000))
        }

        // 30% chance: overshoot and correct
        if Double.random(in: 0...1) < 0.3 {
            let overshootDist = CGFloat.random(in: 5...15)
            let overshootAngle = atan2(target.y - startPos.y, target.x - startPos.x)
            let overshootTarget = CGPoint(
                x: target.x + cos(overshootAngle) * overshootDist,
                y: target.y + sin(overshootAngle) * overshootDist
            )
            postMove(to: overshootTarget)
            usleep(UInt32.random(in: 30_000...60_000))

            // Correct back over 3-5 steps
            let correctionSteps = Int.random(in: 3...5)
            for i in 1...correctionSteps {
                let t = CGFloat(i) / CGFloat(correctionSteps)
                let corrected = CGPoint(
                    x: overshootTarget.x + (target.x - overshootTarget.x) * easeInOut(t),
                    y: overshootTarget.y + (target.y - overshootTarget.y) * easeInOut(t)
                )
                postMove(to: corrected)
                usleep(UInt32.random(in: 15_000...30_000))
            }
        }

        let movedDistance = Int(sqrt(pow(target.x - startPos.x, 2) + pow(target.y - startPos.y, 2)))
        return "Visible move (\(movedDistance)px)"
    }

    // MARK: - Keep-Alive Click (with pre/post micro-movement)

    static func simulateKeepAliveClick() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard var pos = cursorPosition() else { return nil }

        // Pre-click: 2-3 micro-moves to simulate aim adjustment
        let preMoves = Int.random(in: 2...3)
        for _ in 0..<preMoves {
            let nudge = continuousJitter(maxMagnitude: 4.0)
            pos = CGPoint(x: pos.x + nudge.x, y: pos.y + nudge.y)
            postMove(to: pos)
            usleep(UInt32.random(in: 30_000...60_000))
        }

        let clickPos = clampToScreen(pos)

        // Mouse down
        guard let mouseDown = CGEvent(
            mouseEventSource: humanEventSource(),
            mouseType: .leftMouseDown,
            mouseCursorPosition: clickPos,
            mouseButton: .left
        ) else { return nil }
        mouseDown.setIntegerValueField(.mouseEventClickState, value: 1)
        lastSimulatedEventTime = Date()
        mouseDown.post(tap: .cghidEventTap)

        // Realistic hold time: 80-200ms
        usleep(UInt32.random(in: 80_000...200_000))

        // 50% chance: micro-drift during hold
        var releasePos = clickPos
        if Double.random(in: 0...1) < 0.5 {
            let drift = continuousJitter(maxMagnitude: 1.0)
            releasePos = CGPoint(x: clickPos.x + drift.x, y: clickPos.y + drift.y)
        }

        // Mouse up at (possibly drifted) position
        guard let mouseUp = CGEvent(
            mouseEventSource: humanEventSource(),
            mouseType: .leftMouseUp,
            mouseCursorPosition: clampToScreen(releasePos),
            mouseButton: .left
        ) else { return nil }
        mouseUp.setIntegerValueField(.mouseEventClickState, value: 1)
        lastSimulatedEventTime = Date()
        mouseUp.post(tap: .cghidEventTap)

        // 40% chance: post-click settle movement
        if Double.random(in: 0...1) < 0.4 {
            let settles = Int.random(in: 1...2)
            for _ in 0..<settles {
                usleep(UInt32.random(in: 30_000...80_000))
                let settle = continuousJitter(maxMagnitude: 1.5)
                releasePos = CGPoint(x: releasePos.x + settle.x, y: releasePos.y + settle.y)
                postMove(to: releasePos)
            }
        }

        return "Keep-alive click at (\(Int(clickPos.x)),\(Int(clickPos.y)))"
    }

    // MARK: - Burst Clicks (capped, natural multi-click)

    static func simulateBurstClicks(count: Int) -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard var pos = cursorPosition() else { return nil }

        // Cap to 5 — more than that is never natural
        let effectiveCount = min(max(count, 1), 5)
        var completed = 0

        for i in 0..<effectiveCount {
            let clickPos = clampToScreen(pos)

            guard let mouseDown = CGEvent(
                mouseEventSource: humanEventSource(),
                mouseType: .leftMouseDown,
                mouseCursorPosition: clickPos,
                mouseButton: .left
            ) else { break }
            mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            lastSimulatedEventTime = Date()
            mouseDown.post(tap: .cghidEventTap)

            // Realistic hold: 80-200ms
            usleep(UInt32.random(in: 80_000...200_000))

            guard let mouseUp = CGEvent(
                mouseEventSource: humanEventSource(),
                mouseType: .leftMouseUp,
                mouseCursorPosition: clickPos,
                mouseButton: .left
            ) else { break }
            mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
            lastSimulatedEventTime = Date()
            mouseUp.post(tap: .cghidEventTap)

            completed += 1

            // Inter-click delay: 80-180ms with slight position drift
            if i < effectiveCount - 1 {
                usleep(UInt32.random(in: 80_000...180_000))
                let drift = continuousJitter(maxMagnitude: 2.0)
                pos = CGPoint(x: pos.x + drift.x, y: pos.y + drift.y)
            }
        }

        return "Burst: \(completed) clicks"
    }

    // MARK: - Drag Gesture (Bézier path)

    static func simulateDragGesture() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard var pos = cursorPosition() else { return nil }

        // Pre-drag: small approach movement
        let approach = continuousJitter(maxMagnitude: 5.0)
        pos = CGPoint(x: pos.x + approach.x, y: pos.y + approach.y)
        postMove(to: pos)
        usleep(UInt32.random(in: 40_000...100_000))

        let startPos = clampToScreen(pos)

        // Random direction and distance
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let totalDistance = CGFloat.random(in: 30...100)
        let endPoint = clampToScreen(CGPoint(
            x: startPos.x + cos(angle) * totalDistance,
            y: startPos.y + sin(angle) * totalDistance
        ))

        // Bézier control points for curved drag
        let (cp1, cp2) = randomControlPoints(from: startPos, to: endPoint)

        // Mouse down at start
        guard let mouseDown = CGEvent(
            mouseEventSource: humanEventSource(),
            mouseType: .leftMouseDown,
            mouseCursorPosition: startPos,
            mouseButton: .left
        ) else { return nil }
        lastSimulatedEventTime = Date()
        mouseDown.post(tap: .cghidEventTap)

        // Drag through Bézier curve
        let steps = Int.random(in: 8...15)
        for i in 1...steps {
            let linearT = CGFloat(i) / CGFloat(steps)
            let easedT = easeInOut(linearT)

            var point = cubicBezierPoint(t: easedT, p0: startPos, p1: cp1, p2: cp2, p3: endPoint)

            // Hand tremor during drag
            let tremor = continuousJitter(maxMagnitude: 1.5)
            point.x += tremor.x
            point.y += tremor.y

            let clamped = clampToScreen(point)
            guard let dragEvent = CGEvent(
                mouseEventSource: humanEventSource(),
                mouseType: .leftMouseDragged,
                mouseCursorPosition: clamped,
                mouseButton: .left
            ) else { break }
            lastSimulatedEventTime = Date()
            dragEvent.post(tap: .cghidEventTap)

            // Variable timing: faster middle, slower ends
            let speed = 4 * linearT * (1 - linearT)
            let baseDelay: UInt32 = 30_000
            let delay = UInt32(CGFloat(baseDelay) / max(speed + 0.3, 0.4))
            usleep(min(delay, 45_000) + UInt32.random(in: 0...5_000))
        }

        // Post-drag pause before release
        usleep(UInt32.random(in: 30_000...80_000))

        // Mouse up at end
        guard let mouseUp = CGEvent(
            mouseEventSource: humanEventSource(),
            mouseType: .leftMouseUp,
            mouseCursorPosition: endPoint,
            mouseButton: .left
        ) else { return nil }
        lastSimulatedEventTime = Date()
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

    // MARK: - Scroll (real scroll wheel events)

    static func simulateScrollDrag() -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }

        let goingDown = Bool.random()
        let totalTicks = Int.random(in: 3...12)
        let eventCount = Int.random(in: 3...8)

        var ticksRemaining = totalTicks
        var delivered = 0

        for i in 0..<eventCount {
            guard ticksRemaining > 0 else { break }

            // Deceleration: larger deltas early, smaller late
            let maxDelta = max(1, min(3, ticksRemaining))
            let progress = CGFloat(i) / CGFloat(eventCount)
            let delta: Int
            if progress < 0.5 {
                delta = Int.random(in: 1...maxDelta)
            } else {
                delta = min(Int.random(in: 1...2), ticksRemaining)
            }

            let signedDelta = goingDown ? -delta : delta

            // Occasional horizontal scroll (imprecise gesture)
            let horizontalDelta: Int32 = Int.random(in: 0...10) < 2 ? Int32.random(in: -1...1) : 0

            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: humanEventSource(),
                units: .line,
                wheelCount: 2,
                wheel1: Int32(signedDelta),
                wheel2: horizontalDelta,
                wheel3: 0
            ) else { break }

            lastSimulatedEventTime = Date()
            scrollEvent.post(tap: .cghidEventTap)
            delivered += delta
            ticksRemaining -= delta

            // Variable timing: bursty with gaps, slower later (deceleration)
            if i < eventCount - 1 && ticksRemaining > 0 {
                let baseDelay: UInt32 = progress < 0.5 ? 40_000 : 80_000
                usleep(baseDelay + UInt32.random(in: 0...60_000))
            }
        }

        return "Scroll \(delivered) ticks \(goingDown ? "down" : "up")"
    }

    // MARK: - App Switch (activate random app + jitter)

    static func simulateAppSwitch(appNames: [String]) -> String? {
        guard AccessibilityHelper.isTrusted() else { return nil }
        guard !appNames.isEmpty else { return nil }

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        // Find the currently frontmost app to avoid switching to it
        let frontmost = NSWorkspace.shared.frontmostApplication

        // Match configured names against running apps (case-insensitive)
        let candidates = runningApps.filter { app in
            guard let name = app.localizedName else { return false }
            let lowerName = name.lowercased()
            return appNames.contains { configuredName in
                lowerName.contains(configuredName.lowercased())
            }
        }.filter { $0.processIdentifier != frontmost?.processIdentifier }

        guard let target = candidates.randomElement() else {
            return "App Switch skipped (no matching apps running)"
        }

        let appName = target.localizedName ?? "Unknown"

        // Activate the target app
        target.activate(options: [.activateIgnoringOtherApps])

        // Wait for the app to come to foreground
        usleep(UInt32.random(in: 300_000...500_000))

        // Perform a small mouse jitter in the newly focused app
        _ = simulateMouseJitter()

        return "Switched to \(appName)"
    }
}
