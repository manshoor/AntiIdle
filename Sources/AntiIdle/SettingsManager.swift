import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Keys {
        static let isActive = "antiidle.isActive"
        static let startOnLogin = "antiidle.startOnLogin"
        static let scheduleEnabled = "antiidle.scheduleEnabled"
        static let scheduleStartHour = "antiidle.scheduleStartHour"
        static let scheduleEndHour = "antiidle.scheduleEndHour"
        static let weekdaysOnly = "antiidle.weekdaysOnly"
        static let actionConfigs = "antiidle.actionConfigs"
    }

    private let defaults = UserDefaults.standard

    @Published var isActive: Bool {
        didSet { defaults.set(isActive, forKey: Keys.isActive) }
    }

    @Published var startOnLogin: Bool {
        didSet { defaults.set(startOnLogin, forKey: Keys.startOnLogin) }
    }

    @Published var scheduleEnabled: Bool {
        didSet { defaults.set(scheduleEnabled, forKey: Keys.scheduleEnabled) }
    }

    @Published var scheduleStartHour: Int {
        didSet { defaults.set(scheduleStartHour, forKey: Keys.scheduleStartHour) }
    }

    @Published var scheduleEndHour: Int {
        didSet { defaults.set(scheduleEndHour, forKey: Keys.scheduleEndHour) }
    }

    @Published var weekdaysOnly: Bool {
        didSet { defaults.set(weekdaysOnly, forKey: Keys.weekdaysOnly) }
    }

    // Per-action configs stored as JSON data
    private var _actionConfigs: [String: ActionConfig] = [:]

    private init() {
        let d = UserDefaults.standard

        d.register(defaults: [
            Keys.isActive: false,
            Keys.startOnLogin: false,
            Keys.scheduleEnabled: false,
            Keys.scheduleStartHour: 9,
            Keys.scheduleEndHour: 18,
            Keys.weekdaysOnly: true
        ])

        self.isActive = d.bool(forKey: Keys.isActive)
        self.startOnLogin = d.bool(forKey: Keys.startOnLogin)
        self.scheduleEnabled = d.bool(forKey: Keys.scheduleEnabled)
        self.scheduleStartHour = d.integer(forKey: Keys.scheduleStartHour)
        self.scheduleEndHour = d.integer(forKey: Keys.scheduleEndHour)
        self.weekdaysOnly = d.bool(forKey: Keys.weekdaysOnly)

        // Load action configs from JSON data, or populate defaults
        if let data = d.data(forKey: Keys.actionConfigs),
           let decoded = try? JSONDecoder().decode([String: ActionConfig].self, from: data) {
            _actionConfigs = decoded
        }
        // Ensure all action types have a config entry
        for actionType in ActionType.allCases {
            if _actionConfigs[actionType.rawValue] == nil {
                _actionConfigs[actionType.rawValue] = actionType.defaultConfig
            }
        }
        saveActionConfigs()
    }

    // MARK: - Action Config Accessors

    func config(for type: ActionType) -> ActionConfig {
        return _actionConfigs[type.rawValue] ?? type.defaultConfig
    }

    func setConfig(_ config: ActionConfig, for type: ActionType) {
        _actionConfigs[type.rawValue] = config
        saveActionConfigs()
    }

    func allConfigs() -> [String: ActionConfig] {
        return _actionConfigs
    }

    private func saveActionConfigs() {
        if let data = try? JSONEncoder().encode(_actionConfigs) {
            defaults.set(data, forKey: Keys.actionConfigs)
        }
    }
}
