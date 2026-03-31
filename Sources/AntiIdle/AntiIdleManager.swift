import Foundation
import Combine
import AppKit
import ServiceManagement

final class AntiIdleManager: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false {
        didSet {
            settings.isActive = isActive
            if isActive {
                start()
            } else {
                stop()
            }
        }
    }

    @Published var secondsUntilNext: Int = 0
    @Published var maxInterval: TimeInterval = 120 {
        didSet { settings.maxInterval = maxInterval }
    }

    @Published var startOnLogin: Bool = false {
        didSet {
            settings.startOnLogin = startOnLogin
            updateLoginItem()
        }
    }

    @Published var scheduleEnabled: Bool = false {
        didSet { settings.scheduleEnabled = scheduleEnabled }
    }

    @Published var scheduleStartHour: Int = 9 {
        didSet { settings.scheduleStartHour = scheduleStartHour }
    }

    @Published var scheduleEndHour: Int = 18 {
        didSet { settings.scheduleEndHour = scheduleEndHour }
    }

    @Published var weekdaysOnly: Bool = true {
        didSet { settings.weekdaysOnly = weekdaysOnly }
    }

    @Published var actionLog: [(date: Date, description: String)] = []

    @Published var accessibilityGranted: Bool = false

    /// Alternates between mouse and key
    private var nextActionIsMouse: Bool = true

    // MARK: - Sub-components

    private let settings = SettingsManager.shared
    private let idleDetector = IdleDetector()
    private var globalHotkey: GlobalHotkey?

    // MARK: - Timers

    private var actionTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.antiidle.timer", qos: .utility)
    private var countdownTimer: Timer?

    // MARK: - Sleep/Lock state

    private var wasActiveBeforeSleep = false

    // MARK: - Init

    init() {
        // Load persisted settings
        self.maxInterval = settings.maxInterval
        self.startOnLogin = settings.startOnLogin
        self.scheduleEnabled = settings.scheduleEnabled
        self.scheduleStartHour = settings.scheduleStartHour
        self.scheduleEndHour = settings.scheduleEndHour
        self.weekdaysOnly = settings.weekdaysOnly

        // Check accessibility
        self.accessibilityGranted = AccessibilityHelper.isTrusted()

        // Set up global hotkey (Cmd+Shift+K)
        self.globalHotkey = GlobalHotkey { [weak self] in
            DispatchQueue.main.async {
                self?.toggle()
            }
        }

        // Subscribe to sleep/lock notifications
        subscribeSleepNotifications()

        // Restore active state if was active before quit
        if settings.isActive {
            self.isActive = true
        }
    }

    // MARK: - Public

    func toggle() {
        if !isActive {
            // Check accessibility before activating
            accessibilityGranted = AccessibilityHelper.isTrusted(promptIfNeeded: true)
        }
        isActive.toggle()
    }

    // MARK: - Timer Management

    private func start() {
        scheduleNextAction()
        startCountdownTimer()
    }

    private func stop() {
        actionTimer?.cancel()
        actionTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        secondsUntilNext = 0
    }

    private func scheduleNextAction() {
        actionTimer?.cancel()

        let interval = randomInterval()
        secondsUntilNext = Int(interval)

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.performAction()
        }
        timer.resume()
        actionTimer = timer
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsUntilNext > 0 {
                self.secondsUntilNext -= 1
            }
        }
    }

    // MARK: - Action Execution

    private func performAction() {
        // Check if within schedule
        if scheduleEnabled && !isWithinSchedule() {
            logAction("Skipped (outside schedule)")
            scheduleNextIfActive()
            return
        }

        // Check if user is genuinely active
        if idleDetector.isUserActive(within: 10) {
            logAction("Skipped (user active)")
            scheduleNextIfActive()
            return
        }

        // Perform the action
        let description: String?
        if nextActionIsMouse {
            description = ActivitySimulator.simulateMouseJitter()
        } else {
            description = ActivitySimulator.simulateKeypress()
        }
        nextActionIsMouse.toggle()

        if let desc = description {
            logAction(desc)
        } else {
            logAction("Failed (no accessibility?)")
        }

        scheduleNextIfActive()
    }

    private func scheduleNextIfActive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isActive else { return }
            self.scheduleNextAction()
        }
    }

    // MARK: - Schedule Check

    private func isWithinSchedule() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat

        if weekdaysOnly && (weekday == 1 || weekday == 7) {
            return false
        }

        return hour >= scheduleStartHour && hour < scheduleEndHour
    }

    // MARK: - Interval Randomization (Box-Muller)

    private func randomInterval() -> TimeInterval {
        let mean = maxInterval * 0.6
        let stddev = maxInterval * 0.2

        // Box-Muller transform for normal distribution
        let u1 = Double.random(in: 0.001...1.0) // avoid log(0)
        let u2 = Double.random(in: 0.0...1.0)
        let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)

        let value = mean + z * stddev
        return max(30, min(value, maxInterval))
    }

    // MARK: - Action Log

    private func logAction(_ description: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let entry = (date: Date(), description: description)
            self.actionLog.insert(entry, at: 0)
            if self.actionLog.count > 10 {
                self.actionLog.removeLast()
            }
        }
    }

    // MARK: - Login Item

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if startOnLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("AntiIdle: Failed to update login item: \(error)")
            }
        }
    }

    // MARK: - Sleep/Lock Notifications

    private func subscribeSleepNotifications() {
        let wsnc = NSWorkspace.shared.notificationCenter

        wsnc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }
        wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }
        wsnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }
        wsnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }

        // Screen lock/unlock via DistributedNotificationCenter
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handleSleep()
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handleWake()
        }
    }

    private func handleSleep() {
        wasActiveBeforeSleep = isActive
        if isActive {
            isActive = false
            logAction("Auto-paused (sleep/lock)")
        }
    }

    private func handleWake() {
        if wasActiveBeforeSleep {
            isActive = true
            logAction("Auto-resumed (wake/unlock)")
            wasActiveBeforeSleep = false
        }
    }
}
