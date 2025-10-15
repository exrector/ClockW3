import Foundation

/// Маппинг тиков на точное время
/// 96 тиков = 24 часа × 4 (каждые 15 минут)
struct TickTimeMapper {
    /// Общее количество тиков
    static let totalTicks = 96
    
    /// Минут на один тик
    static let minutesPerTick = 15
    
    /// Опорная точка: тик 0 = 18:00
    /// Тики расположены по часовой стрелке:
    /// - 0° (справа) = 18:00 (тик 0)
    /// - 90° (внизу) = 24:00 (тик 24)
    /// - 180° (слева) = 06:00 (тик 48)
    /// - 270° (вверху) = 12:00 (тик 72)
    
    /// Получить час и минуты для указанного индекса тика
    /// - Parameter tickIndex: Индекс тика (0...95)
    /// - Returns: Кортеж (час, минута) в 24-часовом формате
    static func time(for tickIndex: Int) -> (hour: Int, minute: Int) {
        let normalized = tickIndex % totalTicks
        let totalMinutes = normalized * minutesPerTick
        
        // Опорная точка: тик 0 = 18:00
        let baseHour = 18
        let baseMinute = 0
        
        let totalFromBase = baseHour * 60 + baseMinute + totalMinutes
        let hour = (totalFromBase / 60) % 24
        let minute = totalFromBase % 60
        
        return (hour, minute)
    }
    
    /// Получить индекс ближайшего тика для указанного угла (в радианах)
    /// - Parameter angle: Угол в радианах
    /// - Returns: Индекс тика (0...95)
    static func tickIndex(for angle: Double) -> Int {
        // Нормализуем угол к диапазону [0, 2π)
        let normalized = atan2(sin(angle), cos(angle)) // [-π, π]
        let positive = normalized >= 0 ? normalized : normalized + 2 * .pi
        
        // Угол на один тик в радианах
        let radiansPerTick = 2 * .pi / Double(totalTicks)
        
        // Вычисляем индекс тика
        let index = Int(round(positive / radiansPerTick)) % totalTicks
        
        return index
    }
    
    /// Получить угол (в радианах) для указанного индекса тика
    /// - Parameter tickIndex: Индекс тика (0...95)
    /// - Returns: Угол в радианах
    static func angle(for tickIndex: Int) -> Double {
        let normalized = tickIndex % totalTicks
        let radiansPerTick = 2 * .pi / Double(totalTicks)
        return Double(normalized) * radiansPerTick
    }
    
    /// Получить время для указанного угла стрелки
    /// - Parameter angle: Угол в радианах
    /// - Returns: Кортеж (час, минута)
    static func time(for angle: Double) -> (hour: Int, minute: Int) {
        let index = tickIndex(for: angle)
        return time(for: index)
    }
    
    /// Получить форматированную строку времени для тика
    /// - Parameter tickIndex: Индекс тика (0...95)
    /// - Returns: Строка вида "18:00"
    static func formattedTime(for tickIndex: Int) -> String {
        let (hour, minute) = time(for: tickIndex)
        return String(format: "%02d:%02d", hour, minute)
    }
    
    /// Получить форматированную строку времени для угла
    /// - Parameter angle: Угол в радианах
    /// - Returns: Строка вида "18:00"
    static func formattedTime(for angle: Double) -> String {
        let (hour, minute) = time(for: angle)
        return String(format: "%02d:%02d", hour, minute)
    }
    
    /// Список всех 96 тиков с их временами
    static let allTicks: [(index: Int, hour: Int, minute: Int, time: String)] = {
        (0..<totalTicks).map { index in
            let (hour, minute) = time(for: index)
            let timeString = String(format: "%02d:%02d", hour, minute)
            return (index, hour, minute, timeString)
        }
    }()
}
