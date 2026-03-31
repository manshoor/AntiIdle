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

        // Toggle button
        Button("Toggle ON/OFF   \u{2318}\u{21E7}K") {
            manager.toggle()
        }

        Divider()

        // Actions submenu — per-action configuration
        Menu("Actions") {
            ForEach(ActionType.allCases) { actionType in
                actionSubmenu(for: actionType)
            }
        }

        // Countdown
        if manager.isActive && manager.secondsUntilNext > 0 {
            Text("Next: \(manager.nextActionName) in \(manager.secondsUntilNext)s")
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

    // MARK: - Per-Action Submenu

    @ViewBuilder
    private func actionSubmenu(for type: ActionType) -> some View {
        let config = manager.config(for: type)
        let statusIcon = config.enabled && config.eventsPerMinute > 0 ? "\u{25CF}" : "\u{25CB}"

        Menu("\(statusIcon) \(type.displayName)") {
            // Enable/disable toggle
            Button(config.enabled ? "\u{2713} Enabled" : "   Enable") {
                var c = config
                c.enabled.toggle()
                if c.enabled && c.eventsPerMinute == 0 {
                    c.eventsPerMinute = type.defaultConfig.eventsPerMinute > 0
                        ? type.defaultConfig.eventsPerMinute
                        : type.rateOptions.first ?? 1
                }
                manager.updateActionConfig(type, c)
            }

            Divider()

            // Rate picker
            Menu("Rate: \(config.eventsPerMinute)/min") {
                ForEach(type.rateOptions, id: \.self) { epm in
                    Button(epm == config.eventsPerMinute ? "\u{2713} \(epm)/min" : "   \(epm)/min") {
                        var c = config
                        c.eventsPerMinute = epm
                        if epm > 0 { c.enabled = true }
                        manager.updateActionConfig(type, c)
                    }
                }
            }

            // Action-specific options
            if type == .visibleMovement {
                Divider()
                Menu("Radius: \(config.movementRadius?.displayName ?? "Medium")") {
                    ForEach(MovementRadius.allCases, id: \.self) { radius in
                        Button(radius == config.movementRadius
                            ? "\u{2713} \(radius.displayName)"
                            : "   \(radius.displayName)") {
                            var c = config
                            c.movementRadius = radius
                            manager.updateActionConfig(type, c)
                        }
                    }
                }
            }

            if type == .burstClick {
                Divider()
                Menu("Clicks/burst: \(config.burstClickCount ?? 100)") {
                    ForEach([10, 50, 100, 200, 500], id: \.self) { count in
                        Button(count == config.burstClickCount
                            ? "\u{2713} \(count)"
                            : "   \(count)") {
                            var c = config
                            c.burstClickCount = count
                            manager.updateActionConfig(type, c)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

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
