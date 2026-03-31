import SwiftUI

@main
struct AntiIdleApp: App {
    @StateObject private var manager = AntiIdleManager()

    var body: some Scene {
        MenuBarExtra {
            menuContent
        } label: {
            Image(systemName: manager.isActive ? "play.fill" : "pause.fill")
        }
        .menuBarExtraStyle(.menu)
    }

    @ViewBuilder
    private var menuContent: some View {
        // Status label
        Label(
            manager.isActive ? "Active" : "Paused",
            systemImage: manager.isActive ? "circle.fill" : "circle"
        )

        // Toggle button with keyboard shortcut display
        Button("Toggle ON/OFF   \u{2318}\u{21E7}K") {
            manager.toggle()
        }

        Divider()

        // Interval submenu
        Menu("Interval") {
            ForEach(intervalOptions, id: \.seconds) { option in
                Button {
                    manager.maxInterval = option.seconds
                } label: {
                    if manager.maxInterval == option.seconds {
                        Text("\u{2713} \(option.label)")
                    } else {
                        Text("   \(option.label)")
                    }
                }
            }
        }

        // Countdown
        if manager.isActive {
            Text("Next action in: \(manager.secondsUntilNext)s")
        }

        // Accessibility warning
        if !manager.accessibilityGranted {
            Divider()
            Button("\u{26A0} Grant Accessibility Permission") {
                _ = AccessibilityHelper.isTrusted(promptIfNeeded: true)
                manager.accessibilityGranted = AccessibilityHelper.isTrusted()
            }
        }

        Divider()

        // Start on login
        Toggle("Start on Login", isOn: $manager.startOnLogin)

        // Schedule submenu
        Menu("Schedule") {
            Toggle("Enable Schedule", isOn: $manager.scheduleEnabled)

            Menu("Start Hour: \(formatHour(manager.scheduleStartHour))") {
                ForEach(7..<12, id: \.self) { hour in
                    Button(formatHour(hour)) {
                        manager.scheduleStartHour = hour
                    }
                }
            }

            Menu("End Hour: \(formatHour(manager.scheduleEndHour))") {
                ForEach([16, 17, 18, 19, 20, 21], id: \.self) { hour in
                    Button(formatHour(hour)) {
                        manager.scheduleEndHour = hour
                    }
                }
            }

            Toggle("Weekdays Only", isOn: $manager.weekdaysOnly)
        }

        Divider()

        // Recent actions log
        Menu("Recent Actions") {
            if manager.actionLog.isEmpty {
                Text("No actions yet")
            } else {
                ForEach(Array(manager.actionLog.enumerated()), id: \.offset) { _, entry in
                    Text("\(formatTime(entry.date)) \u{2014} \(entry.description)")
                }
            }
        }

        Divider()

        Button("Quit AntiIdle") {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Helpers

    private var intervalOptions: [(label: String, seconds: TimeInterval)] {
        [
            ("30 seconds", 30),
            ("1 minute", 60),
            ("2 minutes", 120),
            ("3 minutes", 180),
            ("5 minutes", 300),
        ]
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
