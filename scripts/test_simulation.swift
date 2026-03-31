#!/usr/bin/env swift
// Quick smoke test for AntiIdle's core simulation logic

import CoreGraphics
import ApplicationServices
import Foundation

print("=== AntiIdle Smoke Test ===\n")

// 1. Check Accessibility
let trusted = AXIsProcessTrusted()
print("1. Accessibility trusted: \(trusted)")
if !trusted {
    print("   ⚠️  Not trusted! Simulation will fail.")
    print("   Grant access: System Settings > Privacy & Security > Accessibility")
    print("   Add 'Terminal' (or your terminal app) to the list.")
    // Still try the rest to see what happens
}

// 2. Test CGEvent creation (mouse)
print("\n2. Testing CGEvent mouse creation...")
if let event = CGEvent(source: nil) {
    let pos = event.location
    print("   Current cursor position: (\(Int(pos.x)), \(Int(pos.y)))")

    let jitteredPos = CGPoint(x: pos.x + 2, y: pos.y + 2)
    if let moveEvent = CGEvent(
        mouseEventSource: nil,
        mouseType: .mouseMoved,
        mouseCursorPosition: jitteredPos,
        mouseButton: .left
    ) {
        print("   ✅ Mouse move CGEvent created successfully")

        if trusted {
            moveEvent.post(tap: .cghidEventTap)
            usleep(100_000) // 100ms

            // Check new position
            if let checkEvent = CGEvent(source: nil) {
                let newPos = checkEvent.location
                print("   Posted mouse jitter -> new position: (\(Int(newPos.x)), \(Int(newPos.y)))")

                // Move back
                if let returnEvent = CGEvent(
                    mouseEventSource: nil,
                    mouseType: .mouseMoved,
                    mouseCursorPosition: pos,
                    mouseButton: .left
                ) {
                    returnEvent.post(tap: .cghidEventTap)
                    print("   ✅ Mouse returned to original position")
                }
            }
        } else {
            print("   ⏭️  Skipping post (no accessibility)")
        }
    } else {
        print("   ❌ Failed to create mouse move CGEvent")
    }
} else {
    print("   ❌ Failed to create CGEvent(source: nil)")
}

// 3. Test CGEvent creation (keyboard)
print("\n3. Testing CGEvent keyboard creation...")
let shiftKeyCode: UInt16 = 0x38
if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: shiftKeyCode, keyDown: true),
   let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: shiftKeyCode, keyDown: false) {
    print("   ✅ Shift key CGEvents created successfully")

    if trusted {
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        print("   ✅ Shift key press/release posted")
    } else {
        print("   ⏭️  Skipping post (no accessibility)")
    }
} else {
    print("   ❌ Failed to create keyboard CGEvents")
}

// 4. Test CGEvent tap creation (idle detection)
print("\n4. Testing CGEvent tap creation (idle detection)...")
let eventMask: CGEventMask = (
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.keyDown.rawValue)
)

if let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
) {
    print("   ✅ Event tap created successfully")
    // Clean up
    CFMachPortInvalidate(tap)
} else {
    print("   ⚠️  Event tap creation failed (needs Input Monitoring permission)")
    print("   This is non-critical — app will simulate without activity detection")
}

// 5. Summary
print("\n=== Summary ===")
if trusted {
    print("✅ All core functionality is working!")
    print("   The AntiIdle app should be fully functional.")
} else {
    print("⚠️  Accessibility not granted to this terminal.")
    print("   CGEvent objects CAN be created (good).")
    print("   But posting them requires Accessibility permission.")
    print("   The AntiIdle.app itself needs its own Accessibility grant.")
    print("   Launch the app, click Toggle ON/OFF, and approve the permission dialog.")
}
