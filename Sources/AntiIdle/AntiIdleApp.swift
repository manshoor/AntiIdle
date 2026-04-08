import SwiftUI
import AppKit

@main
struct AntiIdleApp: App {
    @StateObject private var manager = AntiIdleManager()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(manager: manager)
                .onAppear { manager.isPopoverVisible = true }
                .onDisappear { manager.isPopoverVisible = false }
        } label: {
            let icon = coloredMenuBarIcon(
                systemName: manager.isActive ? "eye.fill" : "eye.slash.fill",
                color: manager.isActive ? .systemGreen : .systemGray
            )
            Image(nsImage: icon)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Menu Bar Icon

    private func coloredMenuBarIcon(systemName: String, color: NSColor) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        guard let base = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) else {
            return NSImage(systemSymbolName: "eye", accessibilityDescription: nil) ?? NSImage()
        }
        let image = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }
}
