import SwiftUI

struct ThermostatIcon: View {
    var tintColor: Color
    var fillFraction: Double = 0.6
    var size: CGFloat = 13

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Thermometer occupies left ~62% of width, ticks occupy right ~38%
            let stemWidth = w * 0.30
            let stemCenterX = w * 0.34
            let stemLeft = stemCenterX - stemWidth / 2
            let stemRight = stemCenterX + stemWidth / 2
            let stemTop = h * 0.06

            let bulbDiameter = w * 0.56
            let bulbCenterX = stemCenterX
            let bulbCenterY = h * 0.74
            let bulbRadius = bulbDiameter / 2

            let lineWidth = max(1.1, w * 0.085)

            // 1. Inner Fluid (Bulb + Stem Fill)
            var fluidPath = Path()
            let innerBulbRadius = max(1.0, bulbRadius - lineWidth * 0.8)
            fluidPath.addEllipse(in: CGRect(
                x: bulbCenterX - innerBulbRadius,
                y: bulbCenterY - innerBulbRadius,
                width: innerBulbRadius * 2,
                height: innerBulbRadius * 2
            ))

            let fluidClamped = min(1.0, max(0.25, fillFraction))
            let fluidTop = stemTop + (bulbCenterY - stemTop) * (1.0 - fluidClamped)
            let innerStemWidth = max(1.0, stemWidth - lineWidth * 1.5)
            let innerStemLeft = stemCenterX - innerStemWidth / 2

            fluidPath.addRect(CGRect(
                x: innerStemLeft,
                y: fluidTop,
                width: innerStemWidth,
                height: max(0, bulbCenterY - fluidTop)
            ))

            context.fill(fluidPath, with: .color(tintColor))

            // 2. Outer White / Primary Outline
            var outlinePath = Path()
            outlinePath.addArc(
                center: CGPoint(x: stemCenterX, y: stemTop + stemWidth / 2),
                radius: stemWidth / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )

            let dy = sqrt(max(0, bulbRadius * bulbRadius - (stemWidth / 2) * (stemWidth / 2)))
            let intersectY = bulbCenterY - dy
            outlinePath.addLine(to: CGPoint(x: stemRight, y: intersectY))

            let startAngle = atan2(intersectY - bulbCenterY, stemRight - bulbCenterX)
            let endAngle = atan2(intersectY - bulbCenterY, stemLeft - bulbCenterX)
            outlinePath.addArc(
                center: CGPoint(x: bulbCenterX, y: bulbCenterY),
                radius: bulbRadius,
                startAngle: Angle(radians: Double(startAngle)),
                endAngle: Angle(radians: Double(endAngle)),
                clockwise: false
            )
            outlinePath.addLine(to: CGPoint(x: stemLeft, y: stemTop + stemWidth / 2))

            context.stroke(
                outlinePath,
                with: .color(.primary),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            // 3. 3 Horizontal Ticks on the Right
            let tickLeft = stemRight + w * 0.12
            let tickRight = min(w, tickLeft + w * 0.22)
            let tickWidth = max(1.5, tickRight - tickLeft)
            let tickHeight = max(1.1, h * 0.08)

            let tickYPositions = [
                stemTop + h * 0.18,
                stemTop + h * 0.34,
                stemTop + h * 0.50
            ]

            for tickY in tickYPositions {
                let tickRect = CGRect(
                    x: tickLeft,
                    y: tickY - tickHeight / 2,
                    width: tickWidth,
                    height: tickHeight
                )
                let tickPath = Path(roundedRect: tickRect, cornerRadius: tickHeight / 2)
                context.fill(tickPath, with: .color(tintColor))
            }
        }
        .frame(width: size, height: size * 1.15)
    }
}
