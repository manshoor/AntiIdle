import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var manager: AntiIdleManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                headerSection
                countdownSection
                accessibilityBanner
                actionsSection
                scheduleSection
                activityLogSection
                footerSection
            }
            .padding(16)
        }
        .frame(width: 320)
        .frame(maxHeight: 560)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(manager.isActive ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                Text(manager.isActive ? "Active" : "Paused")
                    .font(.headline)
                    .foregroundStyle(manager.isActive ? .primary : .secondary)

                Spacer()

                Button {
                    manager.toggle()
                } label: {
                    Image(systemName: manager.isActive ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(manager.isActive ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(manager.isActive ? "Pause simulation" : "Start simulation")
            }

            HStack {
                Text("\u{2318}\u{21E7}K to toggle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private var countdownSection: some View {
        if manager.isActive && manager.secondsUntilNext > 0 {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Next: \(manager.nextActionName) in \(manager.secondsUntilNext)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Accessibility Banner

    @ViewBuilder
    private var accessibilityBanner: some View {
        if !manager.accessibilityGranted {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Required")
                        .font(.caption.bold())
                    Text("Grant permission to simulate input")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Grant") {
                    _ = AccessibilityHelper.isTrusted(promptIfNeeded: true)
                    manager.accessibilityGranted = AccessibilityHelper.isTrusted()
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Actions")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 1) {
                ForEach(ActionType.allCases) { actionType in
                    ActionRowView(actionType: actionType, manager: manager)
                }
            }
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schedule")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            VStack(spacing: 8) {
                Toggle("Enable Schedule", isOn: $manager.scheduleEnabled)
                    .font(.callout)

                if manager.scheduleEnabled {
                    HStack {
                        Text("Hours")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Start", selection: $manager.scheduleStartHour) {
                            ForEach(5..<13, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)

                        Text("to")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Picker("End", selection: $manager.scheduleEndHour) {
                            ForEach(13..<23, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }

                    Toggle("Weekdays Only", isOn: $manager.weekdaysOnly)
                        .font(.callout)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Activity Log

    private var activityLogSection: some View {
        DisclosureGroup {
            if manager.actionLog.isEmpty {
                Text("No actions yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(manager.actionLog.enumerated()), id: \.offset) { _, entry in
                        HStack(alignment: .top, spacing: 6) {
                            Text(formatTime(entry.date))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            Text(entry.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        } label: {
            Text("Recent Actions")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Divider()

            Toggle("Start on Login", isOn: $manager.startOnLogin)
                .font(.callout)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit AntiIdle")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
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
