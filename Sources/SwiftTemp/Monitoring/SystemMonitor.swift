import AppKit
import Darwin
import Foundation
import Observation

private struct MonitoringSnapshot: Sendable {
    let cpuUsage: Double
    let memory: MemorySnapshot
    let sensors: SensorSnapshot
    let topCPUProcesses: [ProcessCPUInfo]
}

private actor SystemSampler {
    private var previousCPUTicks: host_cpu_load_info?
    private let sensorReader = SMCTemperatureReader()
    private let processScanner = ProcessCPUScanner()

    func sample(includeTopProcesses: Bool) async -> MonitoringSnapshot {
        let cpuUsage = CPUUsage.currentTotalUsage(previous: &previousCPUTicks)
        let memory = MemoryUsage.current()
        let sensors = await sensorReader.currentSnapshot()
        let topCPUProcesses = includeTopProcesses ? processScanner.topProcesses(limit: 3) : []
        return MonitoringSnapshot(
            cpuUsage: cpuUsage,
            memory: memory,
            sensors: sensors,
            topCPUProcesses: topCPUProcesses
        )
    }

    func resetDeltas() {
        previousCPUTicks = nil
        processScanner.reset()
    }
}

@MainActor
@Observable
final class SystemMonitor {
    private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private(set) var cpuUsage: Double = 0
    private(set) var memoryUsedGB: Double = 0
    private(set) var memoryTotalGB: Double = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    private(set) var lastUpdated: Date = Date()
    private(set) var history: [SystemSample] = []
    private(set) var isMonitoring = true
    private(set) var temperatureCelsius: Double?
    private(set) var temperatureSensorKey: String?
    private(set) var fanCount: Int?
    private(set) var fanSpeeds: [Int?] = []
    private(set) var topCPUProcesses: [ProcessCPUInfo] = []

    private let settings: AppSettings
    private let sampler = SystemSampler()
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var thermalObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var isSleeping = false
    private var topProcessesVisible = false

    init(settings: AppSettings) {
        self.settings = settings
        observeSystemEvents()
        refresh()
        rescheduleTimer()
    }

    func rescheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard isMonitoring, !isSleeping else { return }

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
            topCPUProcesses = []
        }
        rescheduleTimer()
    }

    func setTopProcessesVisible(_ visible: Bool) {
        topProcessesVisible = visible && settings.showTopCPUApps
        if topProcessesVisible {
            refresh()
        } else {
            topCPUProcesses = []
        }
    }

    func refresh() {
        guard isMonitoring, !isSleeping, refreshTask == nil else { return }

        let includeTopProcesses = topProcessesVisible && settings.showTopCPUApps
        let generation = refreshGeneration
        refreshTask = Task { [weak self, sampler] in
            let snapshot = await sampler.sample(includeTopProcesses: includeTopProcesses)
            guard !Task.isCancelled, let self, self.refreshGeneration == generation else { return }
            self.refreshTask = nil
            self.apply(snapshot)
        }
    }

    private func apply(_ snapshot: MonitoringSnapshot) {
        thermalState = ProcessInfo.processInfo.thermalState
        cpuUsage = snapshot.cpuUsage
        memoryUsedGB = snapshot.memory.usedGB
        memoryTotalGB = snapshot.memory.totalGB
        temperatureCelsius = snapshot.sensors.temperatureCelsius
        temperatureSensorKey = snapshot.sensors.temperatureSensorKey
        fanCount = snapshot.sensors.fanCount
        fanSpeeds = snapshot.sensors.fanSpeeds
        topCPUProcesses = snapshot.topCPUProcesses
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
                memoryUsedGB: memoryUsedGB,
                temperatureCelsius: temperatureCelsius
            )
        )

        let cutoff = timestamp.addingTimeInterval(-settings.historyRetentionMinutes * 60)
        if let firstRetainedIndex = history.firstIndex(where: { $0.timestamp >= cutoff }), firstRetainedIndex > 0 {
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
                let oldState = self.thermalState
                let newState = ProcessInfo.processInfo.thermalState
                self.thermalState = newState
                AppLogger.thermal.notice("Thermal state changed to \(newState.label, privacy: .public)")
                ThermalNotifier.notifyStateChange(
                    from: oldState,
                    to: newState,
                    threshold: self.settings.notificationThreshold
                )
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        sleepObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.prepareForSleep()
            }
        }
        wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resumeAfterWake()
            }
        }
    }

    private func prepareForSleep() {
        isSleeping = true
        timer?.invalidate()
        timer = nil
        cancelPendingRefresh()
    }

    private func resumeAfterWake() {
        guard isSleeping else { return }
        isSleeping = false
        Task { [weak self, sampler] in
            await sampler.resetDeltas()
            guard let self else { return }
            self.refresh()
            self.rescheduleTimer()
        }
    }

    private func cancelPendingRefresh() {
        refreshGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
    }
}
