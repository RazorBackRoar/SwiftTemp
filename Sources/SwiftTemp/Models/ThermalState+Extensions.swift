import SwiftUI

/// Presentation helpers for Apple's only public thermal API on Apple
/// Silicon: a 4-level pressure state, not a temperature. See the project
/// README for why this app doesn't (and can't, via public API) show °C/°F.
extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var symbolName: String {
        switch self {
        case .nominal: return "checkmark.circle.fill"
        case .fair: return "exclamationmark.triangle.fill"
        case .serious: return "exclamationmark.octagon.fill"
        case .critical: return "flame.fill"
        @unknown default: return "thermometer"
        }
    }

    /// Color scheme from the UI/UX plan: Normal=green, Fair=yellow, Hot=red,
    /// Critical=purple — mapped 1:1 onto nominal/fair/serious/critical by
    /// severity order.
    var tint: Color {
        switch self {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .red
        case .critical: return .purple
        @unknown default: return .secondary
        }
    }
}
