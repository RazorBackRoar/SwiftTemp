import Foundation
import UserNotifications

/// Posts local notifications on thermal state transitions.
///
/// `UNUserNotificationCenter` requires a real app bundle (a bundle
/// identifier from Info.plist) to initialize at all. A bare `swift run`/
/// `swift build` executable has none, and calling into UserNotifications
/// without one crashes the process outright — an uncaught Objective-C
/// exception, not a catchable Swift error. So every entry point here
/// checks `Bundle.main.bundleIdentifier` first and no-ops instead of
/// calling `UNUserNotificationCenter.current()` at all when it's missing.
/// This only works fully once running as the built `.app`
/// (`scripts/build-mac.sh`), which has a real Info.plist.
@MainActor
enum ThermalNotifier {
    private static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func requestAuthorizationIfNeeded() {
        guard isAvailable else {
            AppLogger.system.notice(
                "Skipping notification setup — no bundle identifier (running via `swift run`, not a built .app)."
            )
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            Task { @MainActor in
                if let error {
                    AppLogger.system.error(
                        "Notification authorization error: \(error.localizedDescription, privacy: .public)"
                    )
                } else {
                    AppLogger.system.notice("Notification authorization granted: \(granted, privacy: .public)")
                }
            }
        }
    }

    static func notifyStateChange(
        from oldState: ProcessInfo.ThermalState,
        to newState: ProcessInfo.ThermalState,
        threshold: NotificationThreshold
    ) {
        guard isAvailable else { return }
        guard oldState != newState, shouldNotify(for: newState, threshold: threshold) else { return }

        let content = UNMutableNotificationContent()
        content.title = "SwiftTemp"
        content.body = "Thermal state changed to \(newState.label)."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error {
                    AppLogger.system.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private static var highTemperatureLatch = HighTemperatureHysteresis()

    static func notifyHighTemperature(fahrenheit: Double, thresholdFahrenheit: Double) {
        let shouldNotify = highTemperatureLatch.evaluate(
            fahrenheit: fahrenheit,
            thresholdFahrenheit: thresholdFahrenheit
        )
        guard isAvailable, shouldNotify else { return }

        let content = UNMutableNotificationContent()
        content.title = "Temperature Threshold Reached"
        content.body = String(
            format: "The experimental chip sensor reached %.0f°F (configured threshold: %.0f°F).",
            fahrenheit,
            thresholdFahrenheit
        )
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            Task { @MainActor in
                if let error {
                    AppLogger.system.error(
                        "Failed to post high-temperature notification: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    static func resetHighTemperatureState() {
        highTemperatureLatch.reset()
    }

    static func shouldNotify(for state: ProcessInfo.ThermalState, threshold: NotificationThreshold) -> Bool {
        switch threshold {
        case .off:
            return false
        case .criticalOnly:
            return state == .critical
        case .seriousOrAbove:
            return state == .serious || state == .critical
        }
    }
}

/// Fires once on an upward crossing, then rearms after the reading drops
/// 5°F below the configured threshold.
struct HighTemperatureHysteresis: Equatable, Sendable {
    private(set) var isLatched = false

    mutating func evaluate(fahrenheit: Double, thresholdFahrenheit: Double) -> Bool {
        guard fahrenheit.isFinite, thresholdFahrenheit.isFinite else { return false }
        if fahrenheit < thresholdFahrenheit - 5 {
            isLatched = false
            return false
        }
        guard fahrenheit >= thresholdFahrenheit, !isLatched else { return false }
        isLatched = true
        return true
    }

    mutating func reset() {
        isLatched = false
    }
}
