import SwiftUI

struct MenuBarLabel: View {
    var monitor: SystemMonitor
    var settings: AppSettings

    var body: some View {
        HStack(spacing: 3) {
            if settings.menuBarDisplayMode != .temperatureOnly {
                ThermostatIcon(
                    tintColor: .orange,
                    fillFraction: temperatureFraction,
                    size: 13
                )
                .frame(width: 14, alignment: .center)
            }

            if settings.menuBarDisplayMode != .iconOnly {
                Text(Temperature.compactFormat(celsius: monitor.temperatureCelsius, unit: settings.temperatureUnit))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            if settings.menuBarDisplayMode == .temperatureAndSystem {
                Text(String(format: "%.0f%%", monitor.cpuUsage))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .frame(minWidth: 30, alignment: .trailing)

                Text(String(format: "%.1fG", monitor.memoryUsedGB))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.red)
                    .frame(minWidth: 38, alignment: .trailing)
            }
        }
        .opacity(monitor.isMonitoring ? 1 : 0.45)
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var temperatureFraction: Double {
        Temperature.fillFraction(celsius: monitor.temperatureCelsius, fallbackThermalState: monitor.thermalState)
    }

    private var accessibilityText: String {
        let status = monitor.isMonitoring ? "" : ", monitoring paused"
        let temperaturePart = monitor.temperatureCelsius.map {
            ", experimental chip sensor \(Temperature.format(celsius: $0, unit: settings.temperatureUnit))"
        } ?? ", degree reading unavailable"
        return "SwiftTemp: \(monitor.thermalState.label) thermal state, "
            + "CPU \(Int(monitor.cpuUsage.rounded())) percent, "
            + "Memory \(String(format: "%.1f", monitor.memoryUsedGB)) GB\(temperaturePart)\(status)"
    }
}
