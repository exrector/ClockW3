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

            // Тики (96 штук)
            TicksView(
                baseRadius: baseRadius,
                center: center,
                hourTicksColor: colors.hourTicks,
                minorTicksColor: colors.minorTicks
            )

            // Цифры часов (24 штуки)
            HourNumbersView(
                baseRadius: baseRadius,
                center: center,
                fontSize: baseRadius * 2 * ClockConstants.numberFontSizeRatio,
                numbersColor: colors.numbers
            )

            // Отладочный круг базового радиуса (закомментирован)
            // Circle()
            //     .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
            //     .frame(width: baseRadius * 2, height: baseRadius * 2)
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
            // ticdods: точки тиков
            for i in 0..<ClockConstants.tickCount {
                let isHourTick = (i % ClockConstants.hourTickSpacing == 0)
                let isHalfHourTick = (i % ClockConstants.halfHourTickSpacing == 0) && !isHourTick
                
                let color: Color
                let dotDiameter: CGFloat
                
                if isHourTick {
                    dotDiameter = baseRadius * ClockConstants.hourTickThickness * 2.0
                    color = hourTicksColor
                } else if isHalfHourTick {
                    dotDiameter = baseRadius * ClockConstants.halfHourTickThickness * 2.0
                    color = minorTicksColor
                } else {
                    dotDiameter = baseRadius * ClockConstants.quarterTickThickness * 2.0
                    color = minorTicksColor
                }
                
                // Все точки тиков и точка стрелки лежат на одном радиусе
                let dotCenterRadius = baseRadius * ClockConstants.cityMarkerRadius
                
                // ВАЖНО: 18:00 = 0° (вправо). Тики идут равномерно без referenceHour.
                let angleDegrees = Double(i) * ClockConstants.degreesPerTick
                let angle = angleDegrees * .pi / 180
                
                let centerPoint = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: dotCenterRadius,
                    angle: angle
                )
                
                let rect = CGRect(
                    x: centerPoint.x - dotDiameter / 2.0,
                    y: centerPoint.y - dotDiameter / 2.0,
                    width: dotDiameter,
                    height: dotDiameter
                )
                let path = Path(ellipseIn: rect)
                context.fill(path, with: .color(color))
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

#if DEBUG
struct StaticBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        StaticBackgroundView(
            size: CGSize(width: 400, height: 400),
            colors: ClockColorPalette.system(colorScheme: .light),
            currentTime: Date()
        )
    }
}
#endif
