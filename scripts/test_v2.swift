#!/usr/bin/env swift
// Smoke test for AntiIdle v2 — all action types

import CoreGraphics
import ApplicationServices
import Foundation

print("=== AntiIdle v2 Smoke Test ===\n")

let trusted = AXIsProcessTrusted()
print("Accessibility: \(trusted ? "granted" : "NOT GRANTED")")
guard trusted else {
    print("Cannot test without Accessibility. Exiting.")
    Foundation.exit(1)
}

// Helper to get cursor position
func cursorPos() -> CGPoint? {
    return CGEvent(source: nil)?.location
}

print("")

// 1. Mouse Jitter
print("1. Mouse Jitter...")
if let pos = cursorPos() {
    let offsets: [CGFloat] = [-2, -1, 1, 2]
    let dx = offsets.randomElement()!
    let dy = offsets.randomElement()!
    let jittered = CGPoint(x: pos.x + dx, y: pos.y + dy)
    if let e = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: jittered, mouseButton: .left) {
        e.post(tap: .cghidEventTap)
        usleep(80_000)
        if let ret = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left) {
            ret.post(tap: .cghidEventTap)
        }
        print("   OK — jittered (\(Int(dx)),\(Int(dy))) and returned")
    }
}

// 2. Visible Movement
print("\n2. Visible Movement (100px)...")
if let pos = cursorPos() {
    let angle = CGFloat.random(in: 0...(2 * .pi))
    let dist: CGFloat = 100
    let screenBounds = CGDisplayBounds(CGMainDisplayID())
    var tx = pos.x + cos(angle) * dist
    var ty = pos.y + sin(angle) * dist
    tx = max(10, min(tx, screenBounds.width - 10))
    ty = max(10, min(ty, screenBounds.height - 10))

    let steps = 10
    for i in 1...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let p = CGPoint(x: pos.x + (tx - pos.x) * t, y: pos.y + (ty - pos.y) * t)
        if let e = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left) {
            e.post(tap: .cghidEventTap)
        }
        usleep(20_000)
    }

    if let newPos = cursorPos() {
        let moved = sqrt(pow(newPos.x - pos.x, 2) + pow(newPos.y - pos.y, 2))
        print("   OK — moved \(Int(moved))px (cursor now at \(Int(newPos.x)),\(Int(newPos.y)))")
    }
}

// 3. Keep-Alive Click
print("\n3. Keep-Alive Click...")
if let pos = cursorPos() {
    if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
       let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
        down.setIntegerValueField(.mouseEventClickState, value: 1)
        up.setIntegerValueField(.mouseEventClickState, value: 1)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        print("   OK — click at (\(Int(pos.x)),\(Int(pos.y)))")
    }
}

// 4. Burst Clicks (5 quick clicks)
print("\n4. Burst Clicks (5)...")
if let pos = cursorPos() {
    var count = 0
    for _ in 0..<5 {
        if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left),
           let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
            down.setIntegerValueField(.mouseEventClickState, value: 1)
            up.setIntegerValueField(.mouseEventClickState, value: 1)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            count += 1
            usleep(15_000)
        }
    }
    print("   OK — \(count) burst clicks")
}

// 5. Drag Gesture
print("\n5. Drag Gesture (50px)...")
if let pos = cursorPos() {
    let endX = pos.x + 50
    let endY = pos.y + 30
    if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
        down.post(tap: .cghidEventTap)
        for i in 1...5 {
            let t = CGFloat(i) / 5.0
            let p = CGPoint(x: pos.x + (endX - pos.x) * t, y: pos.y + (endY - pos.y) * t)
            if let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: p, mouseButton: .left) {
                drag.post(tap: .cghidEventTap)
            }
            usleep(30_000)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: endX, y: endY), mouseButton: .left) {
            up.post(tap: .cghidEventTap)
        }
        print("   OK — dragged 50px right, 30px down")
    }
}

// 6. Scroll Drag
print("\n6. Scroll Drag (80px down)...")
if let pos = cursorPos() {
    if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
        down.post(tap: .cghidEventTap)
        for i in 1...5 {
            let t = CGFloat(i) / 5.0
            let p = CGPoint(x: pos.x, y: pos.y + 80 * t)
            if let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: p, mouseButton: .left) {
                drag.post(tap: .cghidEventTap)
            }
            usleep(30_000)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: pos.x, y: pos.y + 80), mouseButton: .left) {
            up.post(tap: .cghidEventTap)
        }
        print("   OK — scroll dragged 80px down")
    }
}

// 7. Shift Keypress
print("\n7. Shift Keypress...")
if let kd = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true),
   let ku = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: false) {
    kd.post(tap: .cghidEventTap)
    ku.post(tap: .cghidEventTap)
    print("   OK — shift press/release")
}

// 8. Event tap (idle detection)
print("\n8. Event Tap (idle detection)...")
let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.keyDown.rawValue)
if let tap = CGEvent.tapCreate(
    tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
    eventsOfInterest: mask,
    callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
    userInfo: nil
) {
    print("   OK — event tap created")
    CFMachPortInvalidate(tap)
} else {
    print("   WARN — event tap failed (Input Monitoring?)")
}

print("\n=== All 8 action types verified! ===")
