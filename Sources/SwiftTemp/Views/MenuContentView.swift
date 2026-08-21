import AppKit
import SwiftUI

struct MenuContentView: View {
    var monitor: SystemMonitor
    var settings: AppSettings

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
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
                        Image(systemName: monitor.thermalState.symbolName)
                            .font(.system(size: 13))
                            .foregroundStyle(monitor.thermalState.tint)
                            .frame(width: 16, alignment: .center)
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
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 13))
                            .foregroundStyle(Temperature.tint(celsius: monitor.temperatureCelsius))
                            .frame(width: 16, alignment: .center)
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
                                Image(systemName: (rpm ?? 0) > 0 ? "fanblades.fill" : "fanblades")
                                    .font(.system(size: 13))
                                    .foregroundStyle((rpm ?? 0) > 0 ? .blue : .secondary)
                                    .frame(width: 16, alignment: .center)
                            }

                            Spacer()

                            if let rpm {
                                Text(rpm > 0 ? "\(rpm) RPM" : "0 RPM")
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.04))
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // MARK: - CPU & Memory Card
            VStack(spacing: 8) {
                // CPU Usage
                VStack(spacing: 4) {
                    if settings.showTopCPUApps {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showTopCPU.toggle()
                            }
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
                                .fill(Color.green)
                                .frame(width: geo.size.width * min(1, max(0, monitor.cpuUsage / 100)))
                        }
                    }
                    .frame(height: 4)
                }

                // Memory Used
                VStack(spacing: 4) {
                    HStack {
                        Label {
                            Text("Memory Used")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "memorychip")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue)
                                .frame(width: 16, alignment: .center)
                        }

                        Spacer()

                        Text(String(format: "%.1f/%.0f GB", monitor.memoryUsedGB, monitor.memoryTotalGB))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.blue)

                        Button {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "memoryBreakdown")
                        } label: {
                            Text("Details")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    GeometryReader { geo in
                        let ratio = monitor.memoryTotalGB > 0 ? (monitor.memoryUsedGB / monitor.memoryTotalGB) : 0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(Color.blue)
                                .frame(width: geo.size.width * min(1, max(0, ratio)))
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
                    .fill(Color.primary.opacity(0.04))
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // MARK: - Activity Graph Card (Always present for layout stability)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("CHIP TEMPERATURE HISTORY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
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
                    .fill(Color.primary.opacity(0.04))
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
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
                .buttonStyle(.bordered)

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
            Label {
                Text("CPU Usage")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "cpu")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                    .frame(width: 16, alignment: .center)
            }

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
