import AppKit
import Foundation
import Observation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable, Hashable {
    case iconOnly
    case temperatureOnly = "percentOnly"
    case temperatureAndSystem = "iconAndPercent"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconOnly: return "Icon Only"
        case .temperatureOnly: return "Temperature Only"
        case .temperatureAndSystem: return "Temperature + System Stats"
        }
    }
}

enum NotificationThreshold: String, CaseIterable, Identifiable, Hashable {
    case off
    case seriousOrAbove
    case criticalOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .seriousOrAbove: return "Serious or Critical"
        case .criticalOnly: return "Critical Only"
        }
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable, Hashable {
    case fahrenheit
    case celsius

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fahrenheit: return "Fahrenheit (°F)"
        case .celsius: return "Celsius (°C)"
        }
    }

    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let pollIntervalOptions: [Double] = [1, 2, 5, 10, 30, 60]
    static let historyWindowOptions: [Double] = [1, 5, 15, 60]

    private let defaults: UserDefaults

    var pollInterval: Double {
        didSet { defaults.set(pollInterval, forKey: Keys.pollInterval) }
    }

    var graphWindowMinutes: Double {
        didSet { defaults.set(graphWindowMinutes, forKey: Keys.graphWindowMinutes) }
    }

    var historyRetentionMinutes: Double {
        didSet { defaults.set(historyRetentionMinutes, forKey: Keys.historyRetentionMinutes) }
    }

    var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode) }
    }

    var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Keys.showDockIcon)
            NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        }
    }

    var notificationThreshold: NotificationThreshold {
        didSet { defaults.set(notificationThreshold.rawValue, forKey: Keys.notificationThreshold) }
    }

    var highTemperatureAlertsEnabled: Bool {
        didSet { defaults.set(highTemperatureAlertsEnabled, forKey: Keys.highTemperatureAlertsEnabled) }
    }

    var highTempThresholdFahrenheit: Double {
        didSet { defaults.set(highTempThresholdFahrenheit, forKey: Keys.highTempThresholdFahrenheit) }
    }

    var verboseLogging: Bool {
        didSet { defaults.set(verboseLogging, forKey: Keys.verboseLogging) }
    }

    var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }

    var showTopCPUApps: Bool {
        didSet { defaults.set(showTopCPUApps, forKey: Keys.showTopCPUApps) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pollInterval = Self.validOption(
            defaults.object(forKey: Keys.pollInterval) as? Double,
            options: Self.pollIntervalOptions,
            fallback: 1
        )
        graphWindowMinutes = Self.validOption(
            defaults.object(forKey: Keys.graphWindowMinutes) as? Double,
            options: Self.historyWindowOptions,
            fallback: 5
        )
        historyRetentionMinutes = Self.validOption(
            defaults.object(forKey: Keys.historyRetentionMinutes) as? Double,
            options: Self.historyWindowOptions,
            fallback: 60
        )
        menuBarDisplayMode = MenuBarDisplayMode(rawValue: defaults.string(forKey: Keys.menuBarDisplayMode) ?? "")
            ?? .temperatureAndSystem
        showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
        notificationThreshold = NotificationThreshold(
            rawValue: defaults.string(forKey: Keys.notificationThreshold) ?? ""
        ) ?? .off
        highTemperatureAlertsEnabled = defaults.object(forKey: Keys.highTemperatureAlertsEnabled) as? Bool ?? false
        highTempThresholdFahrenheit = min(
            200,
            max(130, defaults.object(forKey: Keys.highTempThresholdFahrenheit) as? Double ?? 185)
        )
        verboseLogging = defaults.object(forKey: Keys.verboseLogging) as? Bool ?? false
        temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Keys.temperatureUnit) ?? "")
            ?? .fahrenheit
        showTopCPUApps = defaults.object(forKey: Keys.showTopCPUApps) as? Bool ?? true
    }

    private static func validOption(_ value: Double?, options: [Double], fallback: Double) -> Double {
        guard let value, options.contains(value) else { return fallback }
        return value
    }

    enum Keys {
        static let pollInterval = "pollInterval"
        static let graphWindowMinutes = "graphWindowMinutes"
        static let historyRetentionMinutes = "historyRetentionMinutes"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let showDockIcon = "showDockIcon"
        static let notificationThreshold = "notificationThreshold"
        static let highTemperatureAlertsEnabled = "highTemperatureAlertsEnabled"
        static let highTempThresholdFahrenheit = "highTempThresholdFahrenheit"
        static let verboseLogging = "verboseLogging"
        static let temperatureUnit = "temperatureUnit"
        static let showTopCPUApps = "showTopCPUApps"
    }
}
