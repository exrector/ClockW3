import SwiftUI

// MARK: - Static Background View (портированный Layer01)
struct StaticBackgroundView: View {
    let size: CGSize
    let colors: ClockColorPalette
    let currentTime: Date
    
    private var baseRadius: CGFloat {
        min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
    }
    
    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    var body: some View {
        ZStack {
            // Основной фон
            Circle()
                .fill(colors.background)
                .frame(width: baseRadius * 2, height: baseRadius * 2)

            // Тики (96 штук) - временно закомментировано
            // TicksView(
            //     baseRadius: baseRadius,
            //     center: center,
            //     hourTicksColor: colors.hourTicks,
            //     minorTicksColor: colors.minorTicks
            // )

            // Цифры часов (24 штуки)
            HourNumbersView(
                baseRadius: baseRadius,
                center: center,
                fontSize: baseRadius * 2 * ClockConstants.numberFontSizeRatio,
                numbersColor: colors.numbers
            )

            // Отладочный круг базового радиуса
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                .frame(width: baseRadius * 2, height: baseRadius * 2)
        }
    }
}

// MARK: - Ticks View
struct TicksView: View {
    let baseRadius: CGFloat
    let center: CGPoint
    let hourTicksColor: Color
    let minorTicksColor: Color
    
    var body: some View {
        Canvas { context, size in
            for i in 0..<ClockConstants.tickCount {
                let isHourTick = (i % ClockConstants.hourTickSpacing == 0)
                let isHalfHourTick = (i % ClockConstants.halfHourTickSpacing == 0) && !isHourTick
                
                let innerRadius: CGFloat
                let thickness: CGFloat
                let color: Color
                
                if isHourTick {
                    innerRadius = baseRadius * ClockConstants.hourTickInnerRadius
                    thickness = baseRadius * ClockConstants.hourTickThickness
                    color = hourTicksColor
                } else if isHalfHourTick {
                    innerRadius = baseRadius * ClockConstants.halfHourTickInnerRadius
                    thickness = baseRadius * ClockConstants.halfHourTickThickness
                    color = minorTicksColor
                } else {
                    innerRadius = baseRadius * ClockConstants.quarterTickInnerRadius
                    thickness = baseRadius * ClockConstants.quarterTickThickness
                    color = minorTicksColor
                }
                
                let outerRadius = baseRadius * ClockConstants.tickOuterRadius
                let angle = Double(i - 72) * ClockConstants.degreesPerTick * .pi / 180
                
                let startPoint = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: innerRadius,
                    angle: angle
                )
                let endPoint = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: outerRadius,
                    angle: angle
                )
                
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                
                context.stroke(path, with: .color(color), lineWidth: thickness)
            }
        }
    }
}

// MARK: - Hour Numbers View
struct HourNumbersView: View {
    let baseRadius: CGFloat
    let center: CGPoint
    let fontSize: CGFloat
    let numbersColor: Color
    
    var body: some View {
        ForEach(1...24, id: \.self) { hour in
            let angle = ClockConstants.hourNumberAngle(hour: hour)
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: baseRadius * ClockConstants.numberRadius,
                angle: angle
            )
            
            Text(String(format: "%02d", hour))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(numbersColor)
                .position(position)
        }
    }
}

// MARK: - Preview
#Preview {
    StaticBackgroundView(
        size: CGSize(width: 400, height: 400),
        colors: ClockColorPalette.system(),
        currentTime: Date()
    )
}
