import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            notificationsTab
                .tabItem { Label("Alerts", systemImage: "bell") }

            dataTab
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
        }
        .frame(width: 440)
        .frame(minHeight: 300)
        .padding(20)
    }

    private var generalTab: some View {
        Form {
            Picker("Temperature unit", selection: $settings.temperatureUnit) {
                ForEach(TemperatureUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }

            Picker("Refresh interval", selection: $settings.pollInterval) {
                ForEach(AppSettings.pollIntervalOptions, id: \.self) { seconds in
                    Text(intervalLabel(seconds)).tag(seconds)
                }
            }
            .onChange(of: settings.pollInterval) {
                monitor.rescheduleTimer()
            }

            Picker("Menu bar", selection: $settings.menuBarDisplayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Toggle("Allow top CPU process details", isOn: $settings.showTopCPUApps)
            Toggle("Show Dock icon", isOn: $settings.showDockIcon)
            LaunchAtLoginToggle()

            Text("Degree readings use an undocumented SMC interface and may be unavailable. Apple’s Thermal State remains the supported system-health indicator.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationsTab: some View {
        Form {
            Picker("Thermal-state alerts", selection: $settings.notificationThreshold) {
                ForEach(NotificationThreshold.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .onChange(of: settings.notificationThreshold) {
                if settings.notificationThreshold != .off {
                    ThermalNotifier.requestAuthorizationIfNeeded()
                }
            }

            Toggle("Experimental temperature threshold", isOn: $settings.highTemperatureAlertsEnabled)
                .onChange(of: settings.highTemperatureAlertsEnabled) {
                    ThermalNotifier.resetHighTemperatureState()
                    if settings.highTemperatureAlertsEnabled {
                        ThermalNotifier.requestAuthorizationIfNeeded()
                    }
                }

            if settings.highTemperatureAlertsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Threshold")
                        Spacer()
                        Text(thresholdLabel)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.highTempThresholdFahrenheit, in: 130...200, step: 5)
                        .onChange(of: settings.highTempThresholdFahrenheit) {
                            ThermalNotifier.resetHighTemperatureState()
                        }
                }
            }

            Text("Temperature alerts are opt-in because the value is an unsupported, model-dependent chip-sensor reading—not an Apple overheating diagnosis.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataTab: some View {
        Form {
            Picker("Graph shows", selection: $settings.graphWindowMinutes) {
                ForEach(AppSettings.historyWindowOptions, id: \.self) { minutes in
                    Text("Last \(durationLabel(minutes))").tag(minutes)
                }
            }

            Picker("Keep history", selection: $settings.historyRetentionMinutes) {
                ForEach(AppSettings.historyWindowOptions, id: \.self) { minutes in
                    Text(durationLabel(minutes)).tag(minutes)
                }
            }

            Toggle("Verbose diagnostic logging", isOn: $settings.verboseLogging)

            Text("History is kept only in memory and is cleared when SwiftTemp quits.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var thresholdLabel: String {
        let fahrenheit = settings.highTempThresholdFahrenheit
        let celsius = Temperature.celsius(fromFahrenheit: fahrenheit)
        return String(format: "%.0f°F / %.0f°C", fahrenheit, celsius)
    }

    private func intervalLabel(_ seconds: Double) -> String {
        seconds < 60 ? "\(Int(seconds)) sec" : "\(Int(seconds / 60)) min"
    }

    private func durationLabel(_ minutes: Double) -> String {
        minutes < 60 ? "\(Int(minutes)) min" : "\(Int(minutes / 60)) hour"
    }
}
