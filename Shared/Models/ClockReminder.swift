import Foundation

// MARK: - Clock Reminder Model
/// Модель напоминания с привязкой к локальному времени циферблата
struct ClockReminder: Codable, Identifiable {
    let id: UUID
    let hour: Int        // 0-23
    let minute: Int      // округлено до 15 минут (0, 15, 30, 45)
    var isEnabled: Bool

    init(id: UUID = UUID(), hour: Int, minute: Int, isEnabled: Bool = true) {
        self.id = id
        self.hour = hour
        // Округляем минуты до ближайших 15 минут
        self.minute = Self.roundToQuarter(minute)
        self.isEnabled = isEnabled
    }

    /// Округляет минуты до ближайших 15 минут (0, 15, 30, 45)
    static func roundToQuarter(_ minute: Int) -> Int {
        return (minute / 15) * 15
    }

    /// Форматированное время для отображения
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Вычисляет время напоминания из угла поворота циферблата
    /// - Parameters:
    ///   - rotationAngle: Угол поворота в радианах
    ///   - currentTime: Текущее время для определения локального времени
    /// - Returns: ClockReminder с округлённым временем
    static func fromRotationAngle(_ rotationAngle: Double, currentTime: Date = Date()) -> ClockReminder {
        // Получаем текущее локальное время
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentTime)
        let currentMinute = calendar.component(.minute, from: currentTime)

        // Вычисляем текущий угол локальной стрелки
        let currentHour24 = Double(currentHour) + Double(currentMinute) / 60.0
        let currentArrowAngle = ClockConstants.calculateArrowAngle(hour24: currentHour24)

        // Вычисляем целевой угол (текущий + поворот)
        let targetAngle = currentArrowAngle + rotationAngle

        // Нормализуем угол к диапазону [0, 2π]
        var normalizedAngle = targetAngle.truncatingRemainder(dividingBy: 2.0 * .pi)
        if normalizedAngle < 0 {
            normalizedAngle += 2.0 * .pi
        }

        // Конвертируем угол обратно в час (учитывая опорный час 18:00)
        // Формула обратная к ClockConstants.calculateArrowAngle
        let degrees = normalizedAngle * 180.0 / .pi
        let hourFloat = (degrees / ClockConstants.degreesPerHour + ClockConstants.referenceHour).truncatingRemainder(dividingBy: 24.0)

        let hour = Int(hourFloat)
        let minuteFloat = (hourFloat - Double(hour)) * 60.0
        let minute = Int(minuteFloat)

        return ClockReminder(hour: hour, minute: minute)
    }
}
