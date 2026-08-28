import AppKit
import SwiftUI

struct MenuContentView: View {
    var monitor: SystemMonitor
    var settings: AppSettings

    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // MARK: - Thermal & Sensors Card
            VStack(spacing: 8) {
                HStack {
                    metricIcon(monitor.thermalState.symbolName, color: monitor.thermalState.tint)
                        .accessibilityHidden(true)

                    Text("Thermal State")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(monitor.thermalState.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(monitor.thermalState.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(monitor.thermalState.tint.opacity(0.14))
                        )
                }

                HStack {
                    metricIcon("thermometer.high", color: .orange)
                        .accessibilityHidden(true)

                    Text("Chip Sensor")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(
                        Temperature.format(
                            celsius: monitor.temperatureCelsius, unit: settings.temperatureUnit)
                    )
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .frame(minWidth: 65, alignment: .trailing)
                }
                .help(sensorHelpText)

                if let fanCount = monitor.fanCount, fanCount > 0 {
                    ForEach(0..<fanCount, id: \.self) { i in
                        let rpm: Int? = i < monitor.fanSpeeds.count ? monitor.fanSpeeds[i] : nil
                        HStack {
                            AnimatedFanIcon(
                                rpm: rpm,
                                color: (rpm ?? 0) > 0 ? .blue : .secondary,
                                size: 14
                            )

                            Text(fanCount == 1 ? "Fan" : "Fan \(i + 1)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let rpm {
                                Text(rpm > 0 ? "\(rpm) RPM" : "Stopped")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(rpm > 0 ? .blue : .secondary)
                                    .frame(width: 110, alignment: .trailing)
                            } else {
                                Text("Not Available")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(
                cardBackground
            )

            // MARK: - CPU / GPU / Memory Card
            VStack(spacing: 14) {
                // CPU
                Button {
                    openBreakdownWindow(id: "cpuBreakdown")
                } label: {
                    VStack(spacing: 4) {
                        cpuSummary()

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(.green)
                                    .frame(
                                        width: geo.size.width
                                            * min(1, max(0, monitor.cpuUsage / 100))
                                    )
                                    .animation(
                                        reduceMotion ? nil : .easeOut(duration: 0.2),
                                        value: monitor.cpuUsage)
                            }
                        }
                        .frame(height: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the CPU process breakdown")

                // GPU
                Button {
                    openBreakdownWindow(id: "gpuBreakdown")
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            metricIcon("display", color: .blue)
                                .accessibilityHidden(true)

                            Text("GPU")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if let gpu = monitor.gpuUsage {
                                Text(String(format: "%.0f%%", gpu))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(.blue)
                            } else {
                                Text("Not Available")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }

                            detailsLabel(tint: .blue)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(.blue)
                                    .frame(
                                        width: geo.size.width
                                            * min(1, max(0, (monitor.gpuUsage ?? 0) / 100))
                                    )
                                    .animation(
                                        reduceMotion ? nil : .easeOut(duration: 0.2),
                                        value: monitor.gpuUsage ?? 0)
                            }
                        }
                        .frame(height: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the GPU process breakdown")

                // Memory
                Button {
                    openBreakdownWindow(id: "memoryBreakdown")
                } label: {
                    VStack(spacing: 4) {
                        HStack {
                            metricIcon("memorychip", color: .red)
                                .accessibilityHidden(true)

                            Text("Memory")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(
                                String(
                                    format: "%.1f / %.0f GB", monitor.memoryUsedGB,
                                    monitor.memoryTotalGB)
                            )
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.red)

                            detailsLabel(tint: .red)
                        }

                        GeometryReader { geo in
                            let ratio =
                                monitor.memoryTotalGB > 0
                                ? (monitor.memoryUsedGB / monitor.memoryTotalGB) : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                Capsule()
                                    .fill(.red)
                                    .frame(width: geo.size.width * min(1, max(0, ratio)))
                                    .animation(
                                        reduceMotion ? nil : .easeOut(duration: 0.2), value: ratio)
                            }
                        }
                        .frame(height: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the memory process breakdown")
            }
            .padding(10)
            .background(
                cardBackground
            )

            // MARK: - Activity Graph Card (Always present for layout stability)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("CHIP TEMPERATURE HISTORY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(settings.temperatureUnit.symbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HistoryGraphView(
                    samples: graphSamples,
                    unit: settings.temperatureUnit,
                    windowMinutes: settings.graphWindowMinutes
                )
                .frame(height: 52)
            }
            .padding(10)
            .background(
                cardBackground
            )

            // MARK: - Actions & Controls
            HStack(spacing: 8) {
                Button {
                    monitor.setMonitoring(!monitor.isMonitoring)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: monitor.isMonitoring ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(monitor.isMonitoring ? Color.orange : Color.green)
                        Text(monitor.isMonitoring ? "Pause" : "Resume")
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuActionButtonStyle())

                Button {
                    monitor.refresh()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("Refresh")
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(MenuActionButtonStyle())
                .disabled(!monitor.isMonitoring)
            }

            HStack(spacing: 8) {
                Text("Updated \(Self.timeFormatter.string(from: monitor.lastUpdated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                SettingsLink {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Settings")
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(MenuActionButtonStyle())
                .keyboardShortcut(",", modifiers: .command)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        NSApp.activate(ignoringOtherApps: true)
                    })

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                .buttonStyle(MenuActionButtonStyle())
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func cpuSummary() -> some View {
        HStack {
            metricIcon("cpu", color: .green)
                .accessibilityHidden(true)

            Text("CPU")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "%.1f%%", monitor.cpuUsage))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.green)
                .frame(width: 55, alignment: .trailing)

            detailsLabel(tint: .green)
        }
    }

    private func detailsLabel(tint: Color) -> some View {
        Text("Details")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
    }

    private func openBreakdownWindow(id: String) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }

    private func metricIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.primary.opacity(0.04))
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
    }

    private var graphSamples: [SystemSample] {
        let cutoff = Date().addingTimeInterval(-settings.graphWindowMinutes * 60)
        let filtered = monitor.history.filter {
            $0.timestamp >= cutoff && $0.temperatureCelsius?.isFinite == true
        }
        let maximumPoints = 180
        guard filtered.count > maximumPoints else { return filtered }

        let step = Int(ceil(Double(filtered.count) / Double(maximumPoints)))
        var reduced = Swift.stride(from: 0, to: filtered.count, by: step).map { filtered[$0] }
        if let last = filtered.last, reduced.last?.id != last.id {
            reduced.append(last)
        }
        return reduced
    }

    private var sensorHelpText: String {
        if let key = monitor.temperatureSensorKey {
            return
                "Experimental private SMC reading from compute sensor \(key). This is not an Apple thermal diagnosis."
        }
        return "No supported degree API exists. Apple Thermal State above remains authoritative."
    }

    private var temperatureFraction: Double {
        guard let c = monitor.temperatureCelsius else {
            switch monitor.thermalState {
            case .nominal: return 0.35
            case .fair: return 0.55
            case .serious: return 0.80
            case .critical: return 1.0
            @unknown default: return 0.4
            }
        }
        return min(1.0, max(0.25, (c - 20.0) / 75.0))
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ThermostatIcon(
                    tintColor: .orange,
                    fillFraction: temperatureFraction,
                    size: 14
                )
                Text("SwiftTemp")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(monitor.isMonitoring ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(monitor.isMonitoring ? "Active" : "Paused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(monitor.isMonitoring ? .green : .secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(
                        monitor.isMonitoring
                            ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
            )
        }
    }
}

private struct MenuActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuActionButton(configuration: configuration)
    }
}

private struct MenuActionButton: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.10))
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
    }
}
