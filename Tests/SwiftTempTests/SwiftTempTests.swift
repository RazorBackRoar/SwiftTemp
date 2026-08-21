import XCTest
@testable import SwiftTemp

final class SwiftTempTests: XCTestCase {
    func testTemperatureConversionsAndFormatting() {
        XCTAssertEqual(Temperature.fahrenheit(fromCelsius: 0), 32, accuracy: 0.0001)
        XCTAssertEqual(Temperature.fahrenheit(fromCelsius: 100), 212, accuracy: 0.0001)
        XCTAssertEqual(Temperature.celsius(fromFahrenheit: 212), 100, accuracy: 0.0001)
        XCTAssertEqual(Temperature.format(celsius: 46.03, unit: .fahrenheit), "115°F")
        XCTAssertEqual(Temperature.format(celsius: 46.03, unit: .celsius), "46°C")
        XCTAssertEqual(Temperature.format(celsius: nil, unit: .fahrenheit), "Unavailable")
        XCTAssertEqual(Temperature.format(celsius: .infinity, unit: .celsius), "Unavailable")
        XCTAssertEqual(Temperature.compactFormat(celsius: nil, unit: .fahrenheit), "—")
    }

    func testTemperatureTintProgression() {
        XCTAssertEqual(Temperature.tint(celsius: 64.9), .yellow)
        XCTAssertEqual(Temperature.tint(celsius: 65), .orange)
        XCTAssertEqual(Temperature.tint(celsius: 84.9), .orange)
        XCTAssertEqual(Temperature.tint(celsius: 85), .red)
        XCTAssertEqual(Temperature.tint(celsius: 99.9), .red)
        XCTAssertEqual(Temperature.tint(celsius: 100), .purple)
        XCTAssertEqual(Temperature.tint(celsius: nil), .secondary)
    }

    @MainActor
    func testAppSettingsDefaultsAndLegacyMenuValues() {
        let defaults = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.pollInterval, 1)
        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)
        XCTAssertEqual(settings.menuBarDisplayMode, .temperatureAndSystem)
        XCTAssertFalse(settings.highTemperatureAlertsEnabled)

        defaults.set("percentOnly", forKey: AppSettings.Keys.menuBarDisplayMode)
        XCTAssertEqual(AppSettings(defaults: defaults).menuBarDisplayMode, .temperatureOnly)
    }

    @MainActor
    func testAppSettingsRejectsInvalidPersistedOptions() {
        let defaults = isolatedDefaults()
        defaults.set(0, forKey: AppSettings.Keys.pollInterval)
        defaults.set(999, forKey: AppSettings.Keys.graphWindowMinutes)
        defaults.set(-1, forKey: AppSettings.Keys.historyRetentionMinutes)
        defaults.set(500, forKey: AppSettings.Keys.highTempThresholdFahrenheit)

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.pollInterval, 1)
        XCTAssertEqual(settings.graphWindowMinutes, 5)
        XCTAssertEqual(settings.historyRetentionMinutes, 60)
        XCTAssertEqual(settings.highTempThresholdFahrenheit, 200)
    }

    func testSMCTemperatureDecoding() {
        let floatBits = Float(42.5).bitPattern
        let littleEndianBytes = [
            UInt8(floatBits & 0xFF),
            UInt8((floatBits >> 8) & 0xFF),
            UInt8((floatBits >> 16) & 0xFF),
            UInt8((floatBits >> 24) & 0xFF)
        ]
        let floatValue = SMCConnection.decodeTemperature(bytes: littleEndianBytes, dataType: "flt ")
        let fixedPointValue = SMCConnection.decodeTemperature(bytes: [0x2A, 0x80], dataType: "sp78")
        XCTAssertNotNil(floatValue)
        XCTAssertNotNil(fixedPointValue)
        XCTAssertEqual(floatValue!, 42.5, accuracy: 0.001)
        XCTAssertEqual(fixedPointValue!, 42.5, accuracy: 0.001)
        XCTAssertEqual(SMCConnection.decodeTemperature(bytes: [0, 0, 0, 0], dataType: "flt "), 0)
        XCTAssertNil(SMCConnection.decodeTemperature(bytes: littleEndianBytes, dataType: "ui32"))
    }

    func testRepresentativeTemperatureUsesOnlyComputeSensors() {
        let readings = [
            (key: "TCHP", celsius: 95.0),
            (key: "TB0T", celsius: 40.0),
            (key: "Tp01", celsius: 72.0),
            (key: "Te05", celsius: 68.0),
            (key: "Tg0D", celsius: 75.0)
        ]
        let selected = SMCTemperatureReader.representativeTemperature(from: readings)
        XCTAssertEqual(selected?.key, "Tg0D")
        XCTAssertEqual(selected?.celsius, 75)
        XCTAssertFalse(SMCTemperatureReader.isComputeTemperatureKey("TCHP"))
    }

    @MainActor
    func testThermalNotificationThresholds() {
        XCTAssertFalse(ThermalNotifier.shouldNotify(for: .critical, threshold: .off))
        XCTAssertFalse(ThermalNotifier.shouldNotify(for: .fair, threshold: .seriousOrAbove))
        XCTAssertTrue(ThermalNotifier.shouldNotify(for: .serious, threshold: .seriousOrAbove))
        XCTAssertTrue(ThermalNotifier.shouldNotify(for: .critical, threshold: .criticalOnly))
    }

    func testHighTemperatureHysteresis() {
        var latch = HighTemperatureHysteresis()
        XCTAssertFalse(latch.evaluate(fahrenheit: 180, thresholdFahrenheit: 185))
        XCTAssertTrue(latch.evaluate(fahrenheit: 185, thresholdFahrenheit: 185))
        XCTAssertFalse(latch.evaluate(fahrenheit: 190, thresholdFahrenheit: 185))
        XCTAssertFalse(latch.evaluate(fahrenheit: 180, thresholdFahrenheit: 185))
        XCTAssertFalse(latch.evaluate(fahrenheit: 179.9, thresholdFahrenheit: 185))
        XCTAssertTrue(latch.evaluate(fahrenheit: 185, thresholdFahrenheit: 185))
        latch.reset()
        XCTAssertTrue(latch.evaluate(fahrenheit: 200, thresholdFahrenheit: 185))
        XCTAssertFalse(latch.evaluate(fahrenheit: .nan, thresholdFahrenheit: 185))
    }

    func testCPUUsageFirstSampleIsZeroThenFinite() {
        var previous: host_cpu_load_info?
        let first = CPUUsage.currentTotalUsage(previous: &previous)
        XCTAssertEqual(first, 0)
        XCTAssertNotNil(previous)
        let second = CPUUsage.currentTotalUsage(previous: &previous)
        XCTAssertGreaterThanOrEqual(second, 0)
        XCTAssertLessThanOrEqual(second, 100)
    }

    func testMemoryUsageReportsPhysicalTotal() {
        let snapshot = MemoryUsage.current()
        let expectedTotal = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        XCTAssertEqual(snapshot.totalGB, expectedTotal, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(snapshot.usedGB, 0)
        XCTAssertLessThanOrEqual(snapshot.usedGB, snapshot.totalGB * 1.5)
    }

    func testMenuBarDisplayModesCoverAllUserFacingCases() {
        XCTAssertEqual(MenuBarDisplayMode.allCases.count, 3)
        XCTAssertEqual(MenuBarDisplayMode(rawValue: "percentOnly"), .temperatureOnly)
        XCTAssertEqual(MenuBarDisplayMode(rawValue: "iconAndPercent"), .temperatureAndSystem)
    }

    func testGPUUsageParsesDeviceUtilization() {
        let sample = """
        "PerformanceStatistics" = {"Device Utilization %" = 37}
        """
        XCTAssertEqual(GPUUsage.parsePerformanceStatistics(sample), 37)
        XCTAssertNil(GPUUsage.parsePerformanceStatistics("no stats here"))
        let activeSample = """
        "PerformanceStatistics" = {"Device Active" = 0.5}
        """
        XCTAssertEqual(GPUUsage.parsePerformanceStatistics(activeSample), 50)

        let compactIoreg = """
        "PerformanceStatistics" = {"In use system memory (driver)"=0,"Tiler Utilization %"=16,"Renderer Utilization %"=23,"Device Utilization %"=23}
        """
        XCTAssertEqual(GPUUsage.parsePerformanceStatistics(compactIoreg), 23)
    }

    func testGPUUsageReadsThisMacWhenAvailable() async {
        let value = await GPUUsage.current()
        XCTAssertNotNil(value, "IOAccelerator PerformanceStatistics should be readable on this Mac")
        if let value {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 100)
        }
    }

    func testParsesGPUUserClientCreatorAndAppUsage() {
        let parsed = ProcessGPUScanner.parseCreator("pid 444, WindowServer")
        XCTAssertEqual(parsed?.pid, 444)
        XCTAssertEqual(parsed?.name, "WindowServer")
        XCTAssertNil(ProcessGPUScanner.parseCreator("not a creator"))

        let usage: [[String: Any]] = [
            ["API": "Metal", "accumulatedGPUTime": 1_000_000],
            ["API": "Metal", "accumulatedGPUTime": 2_500_000]
        ]
        XCTAssertEqual(ProcessGPUScanner.accumulatedGPUTime(fromAppUsage: usage), 3_500_000)
        XCTAssertEqual(ProcessGPUScanner.accumulatedGPUTime(fromAppUsage: []), 0)
    }

    func testGPUClientSnapshotFindsMetalProcesses() {
        let totals = ProcessGPUScanner.accumulatedTimesByPID()
        XCTAssertFalse(totals.isEmpty, "AGXDeviceUserClient should list GPU clients on this Mac")
        XCTAssertTrue(totals.values.contains { $0.nanoseconds > 0 })
    }

    func testCPURankedSnapshotReturnsFinitePercents() {
        let rows = ProcessCPUScanner.rankedSnapshot(limit: 8, sampleSeconds: 0.6)
        for row in rows {
            XCTAssertGreaterThan(row.cpuPercent, 0)
            XCTAssertLessThanOrEqual(row.cpuPercent, Double(ProcessInfo.processInfo.activeProcessorCount) * 100)
            XCTAssertFalse(row.name.isEmpty)
        }
    }

    func testSMCHardwareIntegrationWhenAvailable() {
        guard let connection = SMCConnection() else { return }
        XCTAssertTrue(connection.isOpen)

        let keys = connection.discoverTemperatureKeys()
        XCTAssertTrue(keys.allSatisfy { $0.celsius > -20 && $0.celsius < 150 })

        let fanCount = connection.readFanCount()
        XCTAssertGreaterThanOrEqual(fanCount ?? 0, 0)
        if let fanCount, fanCount > 0 {
            XCTAssertEqual(connection.readFanRPMs(count: fanCount).count, fanCount)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "SwiftTempTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
