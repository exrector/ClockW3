import SwiftUI
import CoreGraphics

// MARK: - Clock Constants (портированные из оригинального ClockConstants)
enum ClockConstants {
    // Базовые размеры
    static let clockSizeRatio: CGFloat = 0.99  // 95% от размера контейнера
    
    // Параметры тиков (96 штук)
    static let tickCount = 96
    static let hourTickSpacing = 4         // Шаг для часовых тиков
    static let halfHourTickSpacing = 2     // Шаг для получасовых тиков
    static let degreesPerTick = 3.75       // Градусов на один тик
    static let degreesPerHour = 15.0       // Градусов на час
    static let referenceHour = 18.0        // Опорный час для расчетов (18:00 = 0°)

    // Радиусы элементов циферблата (относительные к baseRadius)
    static let staticBackgroundRadius: CGFloat = 1.0

    // Два внешних кольца с подписями городов
    static let outerLabelRingRadius: CGFloat = 0.95  // Внешнее кольцо
    static let middleLabelRingRadius: CGFloat = 0.82 // Среднее кольцо

    // Основные элементы (сдвинуты к центру)
    static let cityNameRadius: CGFloat = 0.96
    static let tickOuterRadius: CGFloat = 0.75
    static let hourTickInnerRadius: CGFloat = 0.68
    static let halfHourTickInnerRadius: CGFloat = 0.70
    static let quarterTickInnerRadius: CGFloat = 0.72
    static let numberRadius: CGFloat = 0.66

    // Толщина тиков
    static let hourTickThickness: CGFloat = 0.011
    static let halfHourTickThickness: CGFloat = 0.0073
    static let quarterTickThickness: CGFloat = 0.0045

    // Размеры шрифтов (относительные к baseRadius * 2)
    static let numberFontSizeRatio: CGFloat = 0.06      // 24 цифры часов
    static let weekdayFontSizeRatio: CGFloat = 0.03     // Дни месяца в пузырях
    static let labelRingFontSizeRatio: CGFloat = 0.06   // IATA коды на кольцах

    // Параметры стрелок (сдвинуты к центру)
    static let arrowLineEndRadius: CGFloat = 0.45
    static let arrowThicknessRatio: CGFloat = 0.01
    static let weekdayNumberRadius: CGFloat = 0.52  // Пузыри с днями месяца
    static let weekdayBubbleRadiusRatio: CGFloat = 0.05
    
    // Параметры дней месяца
    static let daySectorCount: Int = 31
    static let daySectorInnerRadius: CGFloat = 0.87
    static let daySectorOuterRadius: CGFloat = 0.98
    static let daySectorNumberRadius: CGFloat = 0.93
    static let dayBubbleRadiusRatio: CGFloat = 0.06
    
    // Глобус
    static let globeRadius: CGFloat = 0.62
    
    // Анимации
    static let snapDuration: Double = 0.25
    static let magneticThreshold: CGFloat = 1.5 * .pi / 180  // 1.5 градуса в радианах
}

// MARK: - Geometry Helpers
extension ClockConstants {
    /// Вычисляет точку на окружности
    static func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle.radians)) * radius,
            y: center.y + CGFloat(sin(angle.radians)) * radius
        )
    }
    
    /// Вычисляет угол стрелки для города (портированная логика)
    static func calculateArrowAngle(hour: Int, minute: Int) -> Double {
        let hour24 = Double(hour) + Double(minute) / 60.0
        return calculateArrowAngle(hour24: hour24)
    }

    static func calculateArrowAngle(hour24: Double) -> Double {
        let normalized = normalizeHour24(hour24)
        let degrees = normalized * degreesPerHour - referenceHour * degreesPerHour
        return -degrees * Double.pi / 180.0  // Радианы, минус для правильного направления
    }
    
    /// Вычисляет угол для цифры часа на циферблате (по часовой стрелке)
    static func hourNumberAngle(hour: Int) -> Double {
        // Положительный угол = по часовой стрелке (18→24→6→12)
        // 18 справа (0°), 24 внизу (90°), 6 слева (180°), 12 вверху (270°)
        return Double(hour - 18) * degreesPerHour * .pi / 180.0
    }
    
    /// Вычисляет угол для дня месяца
    static func dayAngle(day: Int) -> Double {
        let degreesPerSector = 360.0 / Double(daySectorCount)
        let offset = Double(12 - 1) * degreesPerSector + degreesPerSector / 2
        return (-Double(day - 1) * degreesPerSector + offset + 90) * .pi / 180.0
    }
    
    /// Нормализует угол к диапазону [-π, π]
    static func normalizeAngle(_ angle: Double) -> Double {
        return atan2(sin(angle), cos(angle))
    }
    
    /// Находит ближайший тик для магнитного притяжения
    static func nearestTickAngle(_ angle: Double) -> Double {
        let quarterHourStep = degreesPerTick * .pi / 180.0
        return round(angle / quarterHourStep) * quarterHourStep
    }
}

private extension ClockConstants {
    static func normalizeHour24(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 24.0)
        if result < 0 { result += 24.0 }
        return result
    }
}
