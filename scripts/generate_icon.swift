#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

// Generate an AntiIdle app icon: a rounded-rect background with a mouse cursor + circular arrows
func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))

    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Background: rounded rect with gradient (dark teal to blue)
    let cornerRadius = s * 0.2
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.12, green: 0.56, blue: 0.58, alpha: 1.0),  // teal
        CGColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1.0),  // blue
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations) {
        ctx.drawLinearGradient(gradient,
                              start: CGPoint(x: 0, y: s),
                              end: CGPoint(x: s, y: 0),
                              options: [])
    }

    // Draw a mouse cursor icon (simplified arrow pointer)
    ctx.saveGState()
    let cursorScale = s / 512.0
    let cx = s * 0.32  // cursor center X
    let cy = s * 0.28  // cursor bottom Y

    ctx.translateBy(x: cx, y: cy)
    ctx.scaleBy(x: cursorScale, y: cursorScale)

    // Arrow pointer shape
    let cursor = CGMutablePath()
    cursor.move(to: CGPoint(x: 0, y: 0))
    cursor.addLine(to: CGPoint(x: 0, y: 280))
    cursor.addLine(to: CGPoint(x: 75, y: 210))
    cursor.addLine(to: CGPoint(x: 140, y: 320))
    cursor.addLine(to: CGPoint(x: 180, y: 300))
    cursor.addLine(to: CGPoint(x: 115, y: 190))
    cursor.addLine(to: CGPoint(x: 200, y: 190))
    cursor.closeSubpath()

    // White fill with slight shadow
    ctx.setShadow(offset: CGSize(width: 2 * cursorScale, height: -2 * cursorScale),
                  blur: 8 * cursorScale,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.addPath(cursor)
    ctx.fillPath()

    // Thin dark border
    ctx.setShadow(offset: .zero, blur: 0)
    ctx.setStrokeColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.5))
    ctx.setLineWidth(3)
    ctx.addPath(cursor)
    ctx.strokePath()

    ctx.restoreGState()

    // Draw circular refresh arrows (indicating movement/activity)
    ctx.saveGState()
    let arrowCenterX = s * 0.62
    let arrowCenterY = s * 0.55
    let radius = s * 0.18

    ctx.translateBy(x: arrowCenterX, y: arrowCenterY)

    // Draw arc
    ctx.setStrokeColor(CGColor(red: 0.4, green: 1.0, blue: 0.85, alpha: 0.9))
    ctx.setLineWidth(s * 0.035)
    ctx.setLineCap(.round)

    // Top arc
    let arcPath1 = CGMutablePath()
    arcPath1.addArc(center: .zero, radius: radius,
                    startAngle: -0.3, endAngle: .pi * 0.8, clockwise: false)
    ctx.addPath(arcPath1)
    ctx.strokePath()

    // Bottom arc
    let arcPath2 = CGMutablePath()
    arcPath2.addArc(center: .zero, radius: radius,
                    startAngle: .pi - 0.3, endAngle: .pi * 1.8, clockwise: false)
    ctx.addPath(arcPath2)
    ctx.strokePath()

    // Arrowheads
    ctx.setFillColor(CGColor(red: 0.4, green: 1.0, blue: 0.85, alpha: 0.9))
    let arrowSize = s * 0.06

    // Top arrowhead
    let angle1 = CGFloat.pi * 0.8
    let tipX1 = radius * cos(angle1)
    let tipY1 = radius * sin(angle1)
    let arrow1 = CGMutablePath()
    arrow1.move(to: CGPoint(x: tipX1, y: tipY1))
    arrow1.addLine(to: CGPoint(x: tipX1 + arrowSize, y: tipY1 + arrowSize * 0.8))
    arrow1.addLine(to: CGPoint(x: tipX1 - arrowSize * 0.3, y: tipY1 + arrowSize * 0.5))
    arrow1.closeSubpath()
    ctx.addPath(arrow1)
    ctx.fillPath()

    // Bottom arrowhead
    let angle2 = CGFloat.pi * 1.8
    let tipX2 = radius * cos(angle2)
    let tipY2 = radius * sin(angle2)
    let arrow2 = CGMutablePath()
    arrow2.move(to: CGPoint(x: tipX2, y: tipY2))
    arrow2.addLine(to: CGPoint(x: tipX2 - arrowSize, y: tipY2 - arrowSize * 0.8))
    arrow2.addLine(to: CGPoint(x: tipX2 + arrowSize * 0.3, y: tipY2 - arrowSize * 0.5))
    arrow2.closeSubpath()
    ctx.addPath(arrow2)
    ctx.fillPath()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Icon sizes needed for .iconset
let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let projectDir = URL(fileURLWithPath: scriptDir).deletingLastPathComponent().path
let iconsetDir = "\(projectDir)/Resources/AppIcon.iconset"

// Create iconset directory
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for entry in sizes {
    let image = generateIcon(size: entry.size)
    let path = "\(iconsetDir)/\(entry.name).png"
    savePNG(image, to: path)
    print("Generated \(entry.name).png (\(entry.size)x\(entry.size))")
}

print("\nIconset created at: \(iconsetDir)")
print("Run: iconutil -c icns \(iconsetDir) -o \(projectDir)/Resources/AppIcon.icns")
