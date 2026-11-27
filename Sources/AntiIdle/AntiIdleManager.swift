import Foundation
import Combine
import AppKit
import ServiceManagement
import SwiftUI

final class AntiIdleManager: ObservableObject {

    // MARK: - Popover Visibility (thread-safe)

    private let popoverLock = NSLock()
    private var _popoverVisible = false

    var isPopoverVisible: Bool {
        get { popoverLock.lock(); defer { popoverLock.unlock() }; return _popoverVisible }
        set {
            popoverLock.lock()
            _popoverVisible = newValue
            popoverLock.unlock()
            DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        }
    }

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
    @Published var nextActionName: String = ""

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
    @Published var accessibilityGranted: Bool = false {
        didSet {
            // The tap fails without permission; retry once it is granted.
            if accessibilityGranted {
                idleDetector.ensureEventTap()
            }
        }
    }

    // MARK: - Sub-components

    private let settings = SettingsManager.shared
    private let idleDetector = IdleDetector()
    private var globalHotkey: GlobalHotkey?

    // MARK: - Multi-Timer System

    private var actionTimers: [ActionType: DispatchSourceTimer] = [:]
    private var nextFireDates: [ActionType: Date] = [:]
    private let timerQueue = DispatchQueue(label: "com.antiidle.timer", qos: .utility)
    private var countdownTimer: Timer?
    private let actionGate = ActionGate()
    private var burstProbability: Double = 0.3

    /// Skip actions if the user gave real input this recently.
    private static let userActiveWindow: TimeInterval = 15

    // MARK: - Sleep/Lock state

    private var sleepTracker = SleepResumeTracker()

    // MARK: - Init

    init() {
        self.startOnLogin = settings.startOnLogin
        self.scheduleEnabled = settings.scheduleEnabled
        self.scheduleStartHour = settings.scheduleStartHour
        self.scheduleEndHour = settings.scheduleEndHour
        self.weekdaysOnly = settings.weekdaysOnly
        self.accessibilityGranted = AccessibilityHelper.isTrusted()

        self.globalHotkey = GlobalHotkey { [weak self] in
            DispatchQueue.main.async {
                self?.toggle()
            }
        }

        subscribeSleepNotifications()

        // Restore the saved Active state. didSet does not run during init,
        // so start the timers explicitly.
        if settings.isActive {
            self.isActive = true
            start()
        }
    }

    // MARK: - Public

    func toggle() {
        if !isActive {
            accessibilityGranted = AccessibilityHelper.isTrusted(promptIfNeeded: true)
        }

        // A manual choice overrides any pending auto-resume.
        sleepTracker.reset()
        isActive.toggle()
    }

    func config(for type: ActionType) -> ActionConfig {
        return settings.config(for: type)
    }

    func updateActionConfig(_ type: ActionType, _ config: ActionConfig) {
        settings.setConfig(config, for: type)
        objectWillChange.send()

        if isActive {
            if config.enabled && config.eventsPerMinute > 0 {
                scheduleTimer(for: type, config: config)
            } else {
                actionTimers[type]?.cancel()
                actionTimers[type] = nil
                nextFireDates[type] = nil
            }
        }
    }

    // MARK: - Timer Management

    private func start() {
        idleDetector.ensureEventTap()
        actionGate.set(.running)
        for actionType in ActionType.allCases {
            let config = settings.config(for: actionType)
            if config.enabled && config.eventsPerMinute > 0 {
                scheduleTimer(for: actionType, config: config)
            }
        }
        startCountdownTimer()
    }

    private func stop() {
        actionGate.set(.stopped)
        for (_, timer) in actionTimers {
            timer.cancel()
        }
        actionTimers.removeAll()
        nextFireDates.removeAll()
        countdownTimer?.invalidate()
        countdownTimer = nil
        secondsUntilNext = 0
        nextActionName = ""
    }

    private func scheduleTimer(for actionType: ActionType, config: ActionConfig) {
        actionTimers[actionType]?.cancel()

        let interval = randomInterval(epm: config.eventsPerMinute)
        let fireDate = Date().addingTimeInterval(interval)

        DispatchQueue.main.async { [weak self] in
            self?.nextFireDates[actionType] = fireDate
        }

        // Fire on main so the snapshot reads settings on the thread that
        // writes them; the action itself then runs on timerQueue.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.dispatchAction(actionType)
        }
        timer.resume()
        actionTimers[actionType] = timer
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }

    private func updateCountdown() {
        let now = Date()
        var soonestTime: TimeInterval = .greatestFiniteMagnitude
        var soonestType: ActionType?

        for (type, fireDate) in nextFireDates {
            let remaining = fireDate.timeIntervalSince(now)
            if remaining < soonestTime {
                soonestTime = remaining
                soonestType = type
            }
        }

        secondsUntilNext = max(0, Int(soonestTime))
        nextActionName = soonestType?.displayName ?? ""
    }

    // MARK: - Action Execution

    // Main thread: copy what the action needs, then run it off main.
    private func dispatchAction(_ actionType: ActionType) {
        // Periodic retry: permission may be granted in System Settings
        // without the app noticing.
        idleDetector.ensureEventTap()

        let snapshot = makeSnapshot(for: actionType)
        timerQueue.async { [weak self] in
            self?.performAction(actionType, snapshot)
        }
    }

    private func makeSnapshot(for actionType: ActionType) -> ActionSnapshot {
        let schedule = scheduleEnabled
            ? ScheduleWindow(
                startHour: scheduleStartHour,
                endHour: scheduleEndHour,
                days: weekdaysOnly ? .weekdays : .everyDay
            )
            : nil
        return ActionSnapshot(config: settings.config(for: actionType), schedule: schedule)
    }

    // timerQueue: reads only the snapshot and lock-protected state.
    private func performAction(_ actionType: ActionType, _ snapshot: ActionSnapshot) {
        // Stopped, paused or locked since this was queued: drop it.
        guard actionGate.state == .running else {
            return
        }

        // Suppress all actions while user is interacting with our popover
        if isPopoverVisible {
            logAction("Skipped \(actionType.displayName) (popover open)")
            rescheduleIfActive(actionType)
            return
        }

        if let schedule = snapshot.schedule, !schedule.contains(Date(), calendar: .current) {
            logAction("Skipped \(actionType.displayName) (outside schedule)")
            rescheduleIfActive(actionType)
            return
        }

        // The idle detector ignores our tagged events, so this is real input only
        if idleDetector.isUserActive(within: Self.userActiveWindow) {
            logAction("Skipped \(actionType.displayName) (user active)")
            rescheduleIfActive(actionType)
            return
        }

        let config = snapshot.config
        let description: String?

        switch actionType {
        case .mouseJitter:
            description = ActivitySimulator.simulateMouseJitter()
        case .visibleMovement:
            description = ActivitySimulator.simulateVisibleMovement(radius: config.movementRadius ?? .medium)
        case .keepAliveClick:
            description = ActivitySimulator.simulateKeepAliveClick()
        case .burstClick:
            description = ActivitySimulator.simulateBurstClicks(count: config.burstClickCount ?? 3)
        case .dragGesture:
            description = ActivitySimulator.simulateDragGesture()
        case .scrollDrag:
            description = ActivitySimulator.simulateScrollDrag()
        case .shiftKeypress:
            description = ActivitySimulator.simulateKeypress()
        case .appSwitch:
            description = ActivitySimulator.simulateAppSwitch(appNames: config.appNames ?? [])
        }

        logAction(description ?? "\(actionType.displayName) failed")
        rescheduleIfActive(actionType)
    }

    private func rescheduleIfActive(_ actionType: ActionType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isActive else { return }
            let config = self.settings.config(for: actionType)
            if config.enabled && config.eventsPerMinute > 0 {
                self.scheduleTimer(for: actionType, config: config)
            }
        }
    }

    // MARK: - Interval Randomization (Exponential + Burst/Quiet)

    private func randomInterval(epm: Int) -> TimeInterval {
        let baseInterval = 60.0 / Double(max(1, epm))

        // Exponential distribution (memoryless — naturally irregular)
        let lambda = Double(max(1, epm)) / 60.0
        var interval = -log(Double.random(in: 0.001...1.0)) / lambda

        // Burst/quiet modulation — creates natural clustering
        if Double.random(in: 0...1) < burstProbability {
            // Burst: shorter gap, cluster events together
            interval *= Double.random(in: 0.3...0.6)
            burstProbability = max(0.1, burstProbability - 0.15)
        } else {
            // Quiet: longer gap
            interval *= Double.random(in: 1.2...2.5)
            burstProbability = min(0.7, burstProbability + 0.1)
        }

        // Final noise
        interval += Double.random(in: -1.5...1.5)

        // Wider clamp: allow up to 4x base for quiet periods, min 3s
        return max(3, min(interval, baseInterval * 4.0))
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
            self?.handlePower(.sleep)
        }
        wsnc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handlePower(.wake)
        }
        wsnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handlePower(.sleep)
        }
        wsnc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.handlePower(.wake)
        }

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handlePower(.lock)
        }
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.handlePower(.unlock)
        }
    }

    // Pause or resume as SleepResumeTracker decides.
    private func handlePower(_ event: PowerEvent) {
        switch sleepTracker.handle(event, isActive ? .running : .stopped) {
        case .pause:
            isActive = false
            logAction("Auto-paused (sleep/lock)")
        case .resume:
            isActive = true
            logAction("Auto-resumed (wake/unlock)")
        case .none:
            return
        }
    }

    // MARK: - SwiftUI Binding Helpers

    func bindingForEnabled(_ type: ActionType) -> Binding<Bool> {
        Binding(
            get: { self.config(for: type).enabled },
            set: { newValue in
                var c = self.config(for: type)
                c.enabled = newValue
                if newValue && c.eventsPerMinute == 0 {
                    c.eventsPerMinute = type.defaultConfig.eventsPerMinute > 0
                        ? type.defaultConfig.eventsPerMinute
                        : type.rateOptions.first ?? 1
                }
                self.updateActionConfig(type, c)
            }
        )
    }

    func bindingForEPM(_ type: ActionType) -> Binding<Int> {
        Binding(
            get: { self.config(for: type).eventsPerMinute },
            set: { newValue in
                var c = self.config(for: type)
                c.eventsPerMinute = newValue
                self.updateActionConfig(type, c)
            }
        )
    }

    func bindingForMovementRadius(_ type: ActionType) -> Binding<MovementRadius> {
        Binding(
            get: { self.config(for: type).movementRadius ?? .medium },
            set: { newValue in
                var c = self.config(for: type)
                c.movementRadius = newValue
                self.updateActionConfig(type, c)
            }
        )
    }

    func bindingForBurstClickCount(_ type: ActionType) -> Binding<Int> {
        Binding(
            get: { self.config(for: type).burstClickCount ?? 3 },
            set: { newValue in
                var c = self.config(for: type)
                c.burstClickCount = newValue
                self.updateActionConfig(type, c)
            }
        )
    }

    func bindingForAppNames(_ type: ActionType) -> Binding<String> {
        Binding(
            get: { AppNameList.format(self.config(for: type).appNames ?? []) },
            set: { newValue in
                var c = self.config(for: type)
                c.appNames = AppNameList.parse(newValue)
                self.updateActionConfig(type, c)
            }
        )
    }
}
