import Foundation

struct SystemSample: Identifiable, Sendable {
    var id: Date { timestamp }

    let timestamp: Date
    let thermalState: ProcessInfo.ThermalState
    let cpuUsage: Double
    let memoryUsedGB: Double
    let temperatureCelsius: Double?
}
