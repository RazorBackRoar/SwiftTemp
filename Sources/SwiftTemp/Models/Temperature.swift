import SwiftUI

enum Temperature {
    static func fahrenheit(fromCelsius celsius: Double) -> Double {
        (celsius * 9 / 5) + 32
    }

    static func celsius(fromFahrenheit fahrenheit: Double) -> Double {
        (fahrenheit - 32) * 5 / 9
    }

    static func value(celsius: Double, unit: TemperatureUnit) -> Double {
        unit == .fahrenheit ? fahrenheit(fromCelsius: celsius) : celsius
    }

    static func format(celsius: Double?, unit: TemperatureUnit) -> String {
        guard let celsius, celsius.isFinite else { return "Unavailable" }
        return String(format: "%.0f%@", value(celsius: celsius, unit: unit), unit.symbol)
    }

    static func compactFormat(celsius: Double?, unit: TemperatureUnit) -> String {
        guard let celsius, celsius.isFinite else { return "—" }
        return String(format: "%.0f%@", value(celsius: celsius, unit: unit), unit.symbol)
    }

    static func tint(celsius: Double?) -> Color {
        guard let celsius, celsius.isFinite else { return .secondary }
        switch celsius {
        case ..<50: return .blue
        case ..<75: return .green
        case ..<95: return .yellow
        case ..<105: return .orange
        default: return .red
        }
    }

    /// Icon fill fraction: derived from the measured degree reading when available,
    /// otherwise falls back to the public thermal state so the icon still shows something.
    static func fillFraction(celsius: Double?, fallbackThermalState: ProcessInfo.ThermalState) -> Double {
        guard let celsius else {
            switch fallbackThermalState {
            case .nominal: return 0.35
            case .fair: return 0.55
            case .serious: return 0.80
            case .critical: return 1.0
            @unknown default: return 0.4
            }
        }
        return min(1.0, max(0.25, (celsius - 20.0) / 75.0))
    }
}
