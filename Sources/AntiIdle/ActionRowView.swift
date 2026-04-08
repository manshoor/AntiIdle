import SwiftUI

struct ActionRowView: View {
    let actionType: ActionType
    @ObservedObject var manager: AntiIdleManager

    @State private var isExpanded = false

    private var config: ActionConfig {
        manager.config(for: actionType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row: icon + name + toggle
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: actionType.iconName)
                            .frame(width: 16)
                            .foregroundStyle(config.enabled ? .primary : .tertiary)

                        Text(actionType.displayName)
                            .font(.callout)
                            .foregroundStyle(config.enabled ? .primary : .secondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                Toggle("", isOn: manager.bindingForEnabled(actionType))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Expanded options
            if isExpanded {
                VStack(spacing: 8) {
                    // Rate picker
                    HStack {
                        Text("Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: manager.bindingForEPM(actionType)) {
                            ForEach(actionType.rateOptions, id: \.self) { epm in
                                Text("\(epm)/min").tag(epm)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }

                    // Movement radius (visible movement only)
                    if actionType == .visibleMovement {
                        HStack {
                            Text("Radius")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: manager.bindingForMovementRadius(actionType)) {
                                ForEach(MovementRadius.allCases, id: \.self) { radius in
                                    Text(radius.displayName).tag(radius)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                    }

                    // Burst click count
                    if actionType == .burstClick {
                        HStack {
                            Text("Clicks/burst")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: manager.bindingForBurstClickCount(actionType)) {
                                ForEach([1, 2, 3, 4, 5], id: \.self) { count in
                                    Text("\(count)").tag(count)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 70)
                        }
                    }

                    // App names for app switch
                    if actionType == .appSwitch {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Safari, Slack, VS Code", text: manager.bindingForAppNames(actionType))
                                .font(.callout)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(config.enabled ? Color.accentColor.opacity(0.04) : Color.clear)
    }
}
