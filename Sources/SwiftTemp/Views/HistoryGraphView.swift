import Charts
import SwiftUI

struct HistoryGraphView: View {
    var samples: [SystemSample]
    var unit: TemperatureUnit
    var windowMinutes: Double = 15

    var body: some View {
        let now = Date()
        let startTime = now.addingTimeInterval(-max(60, windowMinutes * 60))
        let chartSamples = temperatureSamples
        let tint = Temperature.tint(celsius: chartSamples.last?.temperatureCelsius)
        let lineStyle: some ShapeStyle = tint
        let areaStyle = areaGradient(color: tint)

        Chart {
            ForEach(chartSamples) { sample in
                if let celsius = sample.temperatureCelsius {
                    let displayedValue = Temperature.value(celsius: celsius, unit: unit)
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Temperature", displayedValue)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(lineStyle)

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        yStart: .value("Scale minimum", yDomain.lowerBound),
                        yEnd: .value("Temperature", displayedValue)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(areaStyle)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: startTime...now)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.primary.opacity(0.1))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yTicks) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    .foregroundStyle(Color.primary.opacity(0.1))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number.rounded()))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.72))
                    }
                }
            }
        }
        .chartPlotStyle { plotContent in
            plotContent
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .overlay {
            if chartSamples.count < 2 {
                Text("Waiting for sensor data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Experimental chip temperature history chart")
        .accessibilityValue(accessibilitySummary)
    }

    private var temperatureSamples: [SystemSample] {
        samples.filter { $0.temperatureCelsius?.isFinite == true }
    }

    private var yDomain: ClosedRange<Double> {
        let lowerCelsius = 20.0
        let upperCelsius = 120.0
        return Temperature.value(
            celsius: lowerCelsius, unit: unit)...Temperature.value(
                celsius: upperCelsius, unit: unit)
    }

    private var yTicks: [Double] {
        let lower = yDomain.lowerBound
        let upper = yDomain.upperBound
        return [lower, (lower + upper) / 2, upper]
    }

    private func areaGradient(color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.24), color.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var accessibilitySummary: String {
        guard let celsius = temperatureSamples.last?.temperatureCelsius else {
            return "No sensor data yet"
        }
        return
            "Latest experimental chip sensor reading \(Temperature.format(celsius: celsius, unit: unit))"
    }
}
