import SwiftUI

struct AnimatedFanIcon: View {
    var rpm: Int?
    var color: Color
    var size: CGFloat = 15

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval, paused: !isSpinning)) { timeline in
            Image(systemName: isSpinning ? "fanblades.fill" : "fanblades")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
                .rotationEffect(.degrees(rotation(at: timeline.date)))
                .shadow(color: isSpinning ? color.opacity(0.25) : .clear, radius: 3)
        }
        .frame(width: size + 3, height: size + 3)
        .accessibilityHidden(true)
    }

    private var isSpinning: Bool {
        !reduceMotion && (rpm ?? 0) > 0
    }

    private var frameInterval: TimeInterval {
        guard let rpm, rpm > 0 else { return 1.0 / 12.0 }
        return rpm >= 3_000 ? 1.0 / 30.0 : 1.0 / 24.0
    }

    private func rotation(at date: Date) -> Double {
        guard isSpinning, let rpm else { return 0 }
        let rotationsPerSecond = min(1.8, max(0.35, Double(rpm) / 1_500.0))
        return date.timeIntervalSinceReferenceDate * rotationsPerSecond * 360
    }
}
