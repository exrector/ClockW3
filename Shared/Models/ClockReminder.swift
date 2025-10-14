import Foundation

// MARK: - Clock Reminder Model
/// Модель напоминания с привязкой к локальному времени циферблата
struct ClockReminder: Codable, Identifiable {
    let id: UUID
    let hour: Int        // 0-23
    let minute: Int      // округлено до 15 минут (0, 15, 30, 45)
    let date: Date?      // nil = ежедневное, не nil = однократное на конкретную дату
    var isEnabled: Bool

    init(id: UUID = UUID(), hour: Int, minute: Int, date: Date? = nil, isEnabled: Bool = true) {
        self.id = id
        self.hour = hour
        // Округляем минуты до ближайших 15 минут
        self.minute = Self.roundToQuarter(minute)
        self.date = date
        self.isEnabled = isEnabled
    }

    var isDaily: Bool {
        date == nil
    }

    /// Округляет минуты до ближайших 15 минут (0, 15, 30, 45)
    static func roundToQuarter(_ minute: Int) -> Int {
        return (minute / 15) * 15
    }

    /// Форматированное время для отображения
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Тип напоминания для отображения
    var typeDescription: String {
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else {
            return "Daily"
        }
    }

    /// Вычисляет время напоминания из угла поворота циферблата
    /// - Parameters:
    ///   - rotationAngle: Угол поворота в радианах
    ///   - currentTime: Текущее время для определения локального времени
    /// - Returns: ClockReminder с округлением до 15 минут
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

        // Конвертируем угол обратно в час (учитывая опорный час 18:00)
        let degrees = targetAngle * 180.0 / .pi
        let hourFloat = (degrees / ClockConstants.degreesPerHour + ClockConstants.referenceHour).truncatingRemainder(dividingBy: 24.0)
        
        // Вычисляем общее количество минут и округляем до 15 минут
        let totalMinutes = hourFloat * 60.0
        let roundedMinutes = round(totalMinutes / 15.0) * 15.0
        
        // Нормализуем значения в диапазоне 0-23 часов и 0-59 минут
        var targetHour = Int(roundedMinutes / 60.0)
        var targetMinute = Int(roundedMinutes.truncatingRemainder(dividingBy: 60.0))
        
        // Убираем отрицательные значения
        while targetHour < 0 {
            targetHour += 24
        }
        while targetMinute < 0 {
            targetMinute += 60
            targetHour -= 1
        }
        
        // Приводим к диапазону 0-23
        targetHour = targetHour % 24
        if targetHour < 0 {
            targetHour += 24
        }
        
        // Приводим минуты к диапазону 0-59 и округляем до 15 минут
        targetMinute = targetMinute % 60
        if targetMinute < 0 {
            targetMinute += 60
        }
        targetMinute = roundToQuarter(targetMinute)

        return ClockReminder(hour: targetHour, minute: targetMinute, date: nil)
    }

    /// Возвращает следующую дату с указанным временем относительно опорного времени.
    static func nextTriggerDate(hour: Int, minute: Int, from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let sameDay = calendar.date(from: components) else {
            return referenceDate
        }

        if sameDay > referenceDate {
            return sameDay
        }

        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }
}
