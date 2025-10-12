import SwiftUI
import Foundation

// MARK: - Angle Calculation Helpers
struct AngleCalculations {
    
    /// Вычисляет позицию точки на окружности
    static func pointOnCircle(
        center: CGPoint,
        radius: CGFloat,
        angle: Double
    ) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
    
    /// Вычисляет угол между двумя точками
    static func angleBetweenPoints(
        center: CGPoint,
        point: CGPoint
    ) -> Double {
        atan2(point.y - center.y, point.x - center.x)
    }
    
    /// Нормализует угол к диапазону [0, 2π]
    static func normalizeAngle0To2Pi(_ angle: Double) -> Double {
        let normalized = angle.truncatingRemainder(dividingBy: 2 * .pi)
        return normalized < 0 ? normalized + 2 * .pi : normalized
    }
    
    /// Нормализует угол к диапазону [-π, π]
    static func normalizeAnglePiToPi(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }
    
    /// Вычисляет кратчайшую разность между углами
    static func angleDifference(_ angle1: Double, _ angle2: Double) -> Double {
        let diff = angle2 - angle1
        return normalizeAnglePiToPi(diff)
    }
    
    /// Интерполирует между двумя углами по кратчайшему пути
    static func interpolateAngles(
        from: Double,
        to: Double,
        factor: Double
    ) -> Double {
        let diff = angleDifference(from, to)
        return from + diff * factor
    }
}

// MARK: - Weekday Helper
struct WeekdayHelper {
    /// Получает номер дня недели для города (1-7, где 1 = воскресенье)
    static func getWeekdayNumber(currentTime: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.component(.weekday, from: currentTime)
    }
    
    /// Получает название дня недели для города
    static func getWeekdayName(currentTime: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = timeZone
        
        return formatter.string(from: currentTime)
    }
    
    /// Получает сокращенное название дня недели
    static func getWeekdayShortName(currentTime: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = timeZone
        
        return formatter.string(from: currentTime)
    }
}

// MARK: - Time Helper
struct TimeHelper {
    /// Получает время в формате HH:mm для города
    static func getTimeString(currentTime: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: currentTime)
    }
    
    /// Получает час и минуту для города
    static func getHourAndMinute(currentTime: Date, timeZone: TimeZone) -> (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        return (hour, minute)
    }
    
    /// Получает день месяца для текущего времени
    static func getCurrentDay(currentTime: Date = Date()) -> Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: currentTime)
    }
    
    /// Получает количество дней в текущем месяце
    static func getDaysInCurrentMonth(currentTime: Date = Date()) -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: currentTime)
        return range?.count ?? 31
    }
}