import Foundation

struct SensorSnapshot: Sendable {
    let temperatureCelsius: Double?
    let temperatureSensorKey: String?
    let fanCount: Int?
    let fanSpeeds: [Int?]
}

actor SMCTemperatureReader {
    private let connection: SMCConnection?
    private var cachedTemperatureKeys: [String] = []
    private var hasDiscovered = false

    init() {
        connection = SMCConnection()
    }

    func currentSnapshot() -> SensorSnapshot {
        guard let connection else {
            return SensorSnapshot(
                temperatureCelsius: nil,
                temperatureSensorKey: nil,
                fanCount: nil,
                fanSpeeds: []
            )
        }

        let temperature = currentTemperature(using: connection)
        let fanCount = connection.readFanCount()
        let fanSpeeds = fanCount.map { connection.readFanRPMs(count: $0) } ?? []
        return SensorSnapshot(
            temperatureCelsius: temperature?.celsius,
            temperatureSensorKey: temperature?.key,
            fanCount: fanCount,
            fanSpeeds: fanSpeeds
        )
    }

    static func isComputeTemperatureKey(_ key: String) -> Bool {
        guard key.utf8.count == 4 else { return false }
        return key.hasPrefix("Tp") || key.hasPrefix("Te") || key.hasPrefix("Tg")
    }

    static func representativeTemperature(
        from readings: [(key: String, celsius: Double)]
    ) -> (key: String, celsius: Double)? {
        readings
            .filter { isComputeTemperatureKey($0.key) && $0.celsius.isFinite && $0.celsius > 15 && $0.celsius < 120 }
            .max { $0.celsius < $1.celsius }
    }

    private func currentTemperature(using connection: SMCConnection) -> (key: String, celsius: Double)? {
        if !hasDiscovered {
            let discovered = connection.discoverTemperatureKeys().filter { Self.isComputeTemperatureKey($0.key) }
            let tracked = discovered.sorted { $0.celsius > $1.celsius }.prefix(12)
            cachedTemperatureKeys = tracked.map(\.key)
            hasDiscovered = true

            AppLogger.system.notice(
                "SMC discovery found \(discovered.count, privacy: .public) plausible compute-temperature keys; tracking \(tracked.count, privacy: .public)."
            )
            for (key, celsius) in tracked {
                AppLogger.system.debug("SMC key \(key, privacy: .public): \(celsius, privacy: .public)°C")
            }
        }

        let readings = cachedTemperatureKeys.compactMap { key -> (key: String, celsius: Double)? in
            guard let celsius = connection.readFloatValue(forKey: key) else { return nil }
            return (key, celsius)
        }
        return Self.representativeTemperature(from: readings)
    }
}
