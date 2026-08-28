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
}
