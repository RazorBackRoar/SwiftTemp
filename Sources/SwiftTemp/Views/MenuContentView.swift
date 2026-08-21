import AppKit
import SwiftUI

struct MenuContentView: View {
    var monitor: SystemMonitor
    var settings: AppSettings

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTopCPU: Bool = false

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
                    Label {
                        Text("Thermal State")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    } icon: {
                        metricIcon(monitor.thermalState.symbolName, color: monitor.thermalState.tint)
                    }

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
                    Label {
                        Text("Chip Sensor")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    } icon: {
                        metricIcon("thermometer.high", color: Temperature.tint(celsius: monitor.temperatureCelsius))
                    }

                    Spacer()

                    Text(Temperature.format(celsius: monitor.temperatureCelsius, unit: settings.temperatureUnit))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Temperature.tint(celsius: monitor.temperatureCelsius))
                        .frame(minWidth: 65, alignment: .trailing)
                }
                .help(sensorHelpText)

                if let fanCount = monitor.fanCount, fanCount > 0 {
                    ForEach(0..<fanCount, id: \.self) { i in
                        let rpm: Int? = i < monitor.fanSpeeds.count ? monitor.fanSpeeds[i] : nil
                        HStack {
                            Label {
                                Text(fanCount == 1 ? "Fan Speed" : "Fan \(i + 1)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } icon: {
                                AnimatedFanIcon(
                                    rpm: rpm,
                                    color: (rpm ?? 0) > 0 ? .cyan : .secondary,
                                    size: 14
                                )
                            }

                            Spacer()

                            if let rpm {
                                Text(rpm > 0 ? "\(rpm) RPM" : "0 RPM")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(rpm > 0 ? .cyan : .secondary)
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.11), Color.cyan.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .strokeBorder(Color.orange.opacity(0.18), lineWidth: 1)
            )

            // MARK: - CPU / GPU / Memory Card
            VStack(spacing: 14) {
                // CPU
                VStack(spacing: 4) {
                    if settings.showTopCPUApps {
                        Button {
                            showTopCPU.toggle()
                            monitor.setTopProcessesVisible(showTopCPU)
                        } label: {
                            cpuSummary(showsDisclosure: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows or hides the highest CPU-using processes")
                    } else {
                        cpuSummary(showsDisclosure: false)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.mint, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, max(0, monitor.cpuUsage / 100)))
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: monitor.cpuUsage)
                        }
                    }
                    .frame(height: 4)
                }

                // GPU
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
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, max(0, (monitor.gpuUsage ?? 0) / 100)))
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: monitor.gpuUsage ?? 0)
                        }
                    }
                    .frame(height: 4)
                }

                // Memory
                VStack(spacing: 4) {
                    HStack {
                        metricIcon("memorychip", color: .purple)
                            .accessibilityHidden(true)

                        Text("Memory")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(String(format: "%.1f / %.0f GB", monitor.memoryUsedGB, monitor.memoryTotalGB))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.purple)

                        Button {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "memoryBreakdown")
                        } label: {
                            Text("Details")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)
                    }

                    GeometryReader { geo in
                        let ratio = monitor.memoryTotalGB > 0 ? (monitor.memoryUsedGB / monitor.memoryTotalGB) : 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.pink, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(1, max(0, ratio)))
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: ratio)
                        }
                    }
                    .frame(height: 4)
                }

                if settings.showTopCPUApps && showTopCPU {
                    Divider()
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("TOP CPU PROCESSES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)

                        let topList = monitor.topCPUProcesses
                        if topList.isEmpty {
                            HStack {
                                Text("Scanning processes…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(height: 16)
                        } else {
                            ForEach(topList.prefix(3)) { proc in
                                HStack {
                                    Text(proc.name)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                    Text(String(format: "%.1f%%", proc.cpuPercent))
                                        .font(.system(size: 11, design: .monospaced))
                                        .monospacedDigit()
                                        .fontWeight(.medium)
                                        .foregroundStyle(.green)
                                        .frame(width: 48, alignment: .trailing)
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(height: 16)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.05), Color.purple.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .strokeBorder(Color.purple.opacity(0.12), lineWidth: 1)
            )

            // MARK: - Activity Graph Card (Always present for layout stability)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.purple)
                    Text("CHIP TEMPERATURE HISTORY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.purple)
                    Spacer()
                    Text(settings.temperatureUnit.symbol)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.09), Color.orange.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .strokeBorder(Color.purple.opacity(0.16), lineWidth: 1)
            )

            // MARK: - Actions & Controls
            HStack(spacing: 6) {
                Button {
                    monitor.setMonitoring(!monitor.isMonitoring)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: monitor.isMonitoring ? "pause.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(monitor.isMonitoring ? "Pause" : "Resume")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(monitor.isMonitoring ? .orange : .green)

                Button {
                    monitor.refresh()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text("Refresh")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .disabled(!monitor.isMonitoring)

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text("Settings…")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .keyboardShortcut(",", modifiers: .command)
            }
            .controlSize(.regular)

            HStack {
                Text("Updated \(Self.timeFormatter.string(from: monitor.lastUpdated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Quit")
                        .fontWeight(.medium)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onDisappear {
            showTopCPU = false
            monitor.setTopProcessesVisible(false)
        }
        .onChange(of: settings.showTopCPUApps) {
            if !settings.showTopCPUApps {
                showTopCPU = false
                monitor.setTopProcessesVisible(false)
            }
        }
    }

    private func cpuSummary(showsDisclosure: Bool) -> some View {
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

            if showsDisclosure {
                Image(systemName: showTopCPU ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
            }
        }
    }

    private func metricIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
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
            return "Experimental private SMC reading from compute sensor \(key). This is not an Apple thermal diagnosis."
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
                    tintColor: monitor.temperatureCelsius.map { Temperature.tint(celsius: $0) } ?? monitor.thermalState.tint,
                    fillFraction: temperatureFraction,
                    size: 14
                )
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.68), value: temperatureFraction)
                Text("SwiftTemp")
                    .font(.system(size: 13, weight: .bold))
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
                    .fill(monitor.isMonitoring ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
            )
        }
    }
}
