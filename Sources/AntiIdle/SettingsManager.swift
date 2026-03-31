import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Keys {
        static let maxInterval = "antiidle.maxInterval"
        static let isActive = "antiidle.isActive"
        static let startOnLogin = "antiidle.startOnLogin"
        static let scheduleEnabled = "antiidle.scheduleEnabled"
        static let scheduleStartHour = "antiidle.scheduleStartHour"
        static let scheduleEndHour = "antiidle.scheduleEndHour"
        static let weekdaysOnly = "antiidle.weekdaysOnly"
    }

    private let defaults = UserDefaults.standard

    @Published var maxInterval: TimeInterval {
        didSet { defaults.set(maxInterval, forKey: Keys.maxInterval) }
    }

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

    private init() {
        let d = UserDefaults.standard

        d.register(defaults: [
            Keys.maxInterval: 120.0,
            Keys.isActive: false,
            Keys.startOnLogin: false,
            Keys.scheduleEnabled: false,
            Keys.scheduleStartHour: 9,
            Keys.scheduleEndHour: 18,
            Keys.weekdaysOnly: true
        ])

        self.maxInterval = d.double(forKey: Keys.maxInterval)
        self.isActive = d.bool(forKey: Keys.isActive)
        self.startOnLogin = d.bool(forKey: Keys.startOnLogin)
        self.scheduleEnabled = d.bool(forKey: Keys.scheduleEnabled)
        self.scheduleStartHour = d.integer(forKey: Keys.scheduleStartHour)
        self.scheduleEndHour = d.integer(forKey: Keys.scheduleEndHour)
        self.weekdaysOnly = d.bool(forKey: Keys.weekdaysOnly)
    }
}
