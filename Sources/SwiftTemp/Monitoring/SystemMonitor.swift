import AppKit
import Darwin
import Foundation
import Observation

private struct MonitoringSnapshot: Sendable {
    let cpuUsage: Double
    let gpuUsage: Double?
    let memory: MemorySnapshot
    let sensors: SensorSnapshot
}

private actor SystemSampler {
    private var previousCPUTicks: host_cpu_load_info?
    private let gpuReader = GPUUsage()
    private let sensorReader = SMCTemperatureReader()

    func sample() async -> MonitoringSnapshot {
        async let gpuUsage = gpuReader.current()
        async let sensors = sensorReader.currentSnapshot()
        let cpuUsage = CPUUsage.currentTotalUsage(previous: &previousCPUTicks)
        let memory = MemoryUsage.current()
        return MonitoringSnapshot(
            cpuUsage: cpuUsage,
            gpuUsage: await gpuUsage,
            memory: memory,
            sensors: await sensors
        )
    }

    func resetDeltas() {
        previousCPUTicks = nil
    }
}

@MainActor
@Observable
final class SystemMonitor {
    private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private(set) var cpuUsage: Double = 0
    private(set) var gpuUsage: Double?
    private(set) var memoryUsedGB: Double = 0
    private(set) var memoryTotalGB: Double =
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    private(set) var lastUpdated: Date = Date()
    private(set) var history: [SystemSample] = []
    private(set) var isMonitoring = true
    private(set) var temperatureCelsius: Double?
    private(set) var temperatureSensorKey: String?
    private(set) var fanCount: Int?
    private(set) var fanSpeeds: [Int?] = []

    private let settings: AppSettings
    private let sampler = SystemSampler()
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var pendingRefresh = false
    private var thermalObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var displaySleepObserver: NSObjectProtocol?
    private var displayWakeObserver: NSObjectProtocol?
    private var isSystemSleeping = false
    private var isDisplaySleeping = false

    init(settings: AppSettings) {
        self.settings = settings
        observeSystemEvents()
        refresh()
        rescheduleTimer()
    }

    func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard isMonitoring, !isSystemSleeping, !isDisplaySleeping else { return }

        let interval = settings.pollInterval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        newTimer.tolerance = min(1, interval * 0.1)
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func setMonitoring(_ enabled: Bool) {
        guard isMonitoring != enabled else { return }
        isMonitoring = enabled
        if enabled {
            refresh()
        } else {
            cancelPendingRefresh()
        }
        rescheduleTimer()
    }

    func refresh() {
        guard isMonitoring, !isSystemSleeping, !isDisplaySleeping else { return }
        guard refreshTask == nil else {
            pendingRefresh = true
            return
        }

        let generation = refreshGeneration
        refreshTask = Task { [weak self, sampler] in
            let snapshot = await sampler.sample()
            guard !Task.isCancelled, let self, self.refreshGeneration == generation else { return }
            self.refreshTask = nil
            self.apply(snapshot)
            if self.pendingRefresh {
                self.pendingRefresh = false
                self.refresh()
            }
        }
    }

    private func apply(_ snapshot: MonitoringSnapshot) {
        updateThermalState(ProcessInfo.processInfo.thermalState)
        cpuUsage = snapshot.cpuUsage
        gpuUsage = snapshot.gpuUsage
        memoryUsedGB = snapshot.memory.usedGB
        memoryTotalGB = snapshot.memory.totalGB
        temperatureCelsius = snapshot.sensors.temperatureCelsius
        temperatureSensorKey = snapshot.sensors.temperatureSensorKey
        fanCount = snapshot.sensors.fanCount
        fanSpeeds = snapshot.sensors.fanSpeeds
        lastUpdated = Date()
        recordSample(at: lastUpdated)

        if settings.highTemperatureAlertsEnabled, let celsius = temperatureCelsius {
            ThermalNotifier.notifyHighTemperature(
                fahrenheit: Temperature.fahrenheit(fromCelsius: celsius),
                thresholdFahrenheit: settings.highTempThresholdFahrenheit
            )
        }

        if settings.verboseLogging {
            AppLogger.system.debug(
                "Sample: cpu=\(self.cpuUsage, privacy: .public)% mem=\(self.memoryUsedGB, privacy: .public)GB state=\(self.thermalState.label, privacy: .public)"
            )
        }
    }

    private func recordSample(at timestamp: Date) {
        history.append(
            SystemSample(
                timestamp: timestamp,
                thermalState: thermalState,
                cpuUsage: cpuUsage,
                gpuUsage: gpuUsage,
                memoryUsedGB: memoryUsedGB,
                temperatureCelsius: temperatureCelsius
            )
        )

        let cutoff = timestamp.addingTimeInterval(-settings.historyRetentionMinutes * 60)
        if let firstRetainedIndex = history.firstIndex(where: { $0.timestamp >= cutoff }),
            firstRetainedIndex > 0
        {
            history.removeFirst(firstRetainedIndex)
        }
    }

    private func observeSystemEvents() {
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isMonitoring else { return }
                self.updateThermalState(ProcessInfo.processInfo.thermalState)
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.prepareForSystemSleep()
            }
        }
        wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeAfterSystemWake()
            }
        }
        displaySleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.prepareForDisplaySleep()
            }
        }
        displayWakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeAfterDisplayWake()
            }
        }
    }

    private func prepareForSystemSleep() {
        isSystemSleeping = true
        pauseForSleep()
    }

    private func prepareForDisplaySleep() {
        isDisplaySleeping = true
        pauseForSleep()
    }

    private func pauseForSleep() {
        timer?.invalidate()
        timer = nil
        cancelPendingRefresh()
    }

    private func resumeAfterSystemWake() {
        guard isSystemSleeping else { return }
        isSystemSleeping = false
        Task { [weak self, sampler] in
            await sampler.resetDeltas()
            guard let self, !self.isDisplaySleeping else { return }
            self.refresh()
            self.rescheduleTimer()
        }
    }

    private func resumeAfterDisplayWake() {
        guard isDisplaySleeping else { return }
        isDisplaySleeping = false
        guard !isSystemSleeping else { return }
        refresh()
        rescheduleTimer()
    }

    private func updateThermalState(_ newState: ProcessInfo.ThermalState) {
        let oldState = thermalState
        guard oldState != newState else { return }
        thermalState = newState
        AppLogger.thermal.notice("Thermal state changed to \(newState.label, privacy: .public)")
        ThermalNotifier.notifyStateChange(
            from: oldState,
            to: newState,
            threshold: settings.notificationThreshold
        )
    }

    private func cancelPendingRefresh() {
        refreshGeneration += 1
        pendingRefresh = false
        refreshTask?.cancel()
        refreshTask = nil
    }
}
