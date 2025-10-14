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
    ///   - targetDate: Целевая дата (nil = ежедневное напоминание)
    /// - Returns: ClockReminder с округлённым временем
    static func fromRotationAngle(_ rotationAngle: Double, currentTime: Date = Date(), targetDate: Date? = nil) -> ClockReminder {
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
        
        // Округляем до ближайших 15 минут для точности
        let totalMinutes = hourFloat * 60.0
        let roundedMinutes = round(totalMinutes / 15.0) * 15.0
        
        let targetHour = Int(roundedMinutes / 60.0) % 24
        let targetMinute = Int(roundedMinutes.truncatingRemainder(dividingBy: 60.0))

        // Определяем дату: если целевое время уже прошло сегодня, ставим на завтра
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let targetTotalMinutes = targetHour * 60 + targetMinute
        
        let finalDate: Date?
        if targetDate != nil {
            finalDate = targetDate
        } else if targetTotalMinutes <= currentTotalMinutes {
            // Время уже прошло сегодня, ставим на завтра
            finalDate = calendar.date(byAdding: .day, value: 1, to: currentTime)
        } else {
            // Время ещё не наступило сегодня
            finalDate = nil
        }

        return ClockReminder(hour: targetHour, minute: targetMinute, date: finalDate)
    }
}
