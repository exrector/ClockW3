#!/usr/bin/env swift
import Foundation

// Тесты системы напоминаний
struct ReminderTests {
    
    static func runTests() -> Bool {
        
        var passed = 0
        var total = 0
        
        // Тест 1: Создание напоминания
        total += 1
        let reminder = MockReminder(
            id: UUID(),
            targetTime: Date(),
            isEnabled: true,
            type: .today
        )
        if reminder.isEnabled && reminder.isToday {
            passed += 1
        } else {
        }
        
        // Тест 2: Форматирование времени
        total += 1
        let calendar = Calendar.current
        let components = DateComponents(hour: 14, minute: 30)
        if let testDate = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let formatted = formatter.string(from: testDate)
            if !formatted.isEmpty {
                passed += 1
            } else {
            }
        } else {
        }
        
        // Тест 3: Типы напоминаний
        total += 1
        let todayReminder = MockReminder(id: UUID(), targetTime: Date(), isEnabled: true, type: .today)
        let tomorrowReminder = MockReminder(id: UUID(), targetTime: Date(), isEnabled: true, type: .tomorrow)
        if todayReminder.typeDescription != tomorrowReminder.typeDescription {
            passed += 1
        } else {
        }
        
        // Тест 4: Создание напоминания из угла поворота
        total += 1
        let currentTime = Date()
        let angle = Double.pi / 4 // 45°
        let reminderFromAngle = createReminderFromAngle(angle, currentTime: currentTime)
        if reminderFromAngle != nil {
            passed += 1
        } else {
        }
        
        return passed == total
    }
    
    // Mock структуры для тестирования
    private enum ReminderType {
        case today, tomorrow, specificDate(Date)
    }
    
    private struct MockReminder {
        let id: UUID
        let targetTime: Date
        let isEnabled: Bool
        let type: ReminderType
        
        var isToday: Bool {
            switch type {
            case .today: return true
            default: return false
            }
        }
        
        var typeDescription: String {
            switch type {
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .specificDate(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        }
    }
    
    private static func createReminderFromAngle(_ angle: Double, currentTime: Date) -> MockReminder? {
        // Преобразуем угол в время
        let degrees = angle * 180.0 / Double.pi
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees
        let hours = (normalizedDegrees + 270) / 15.0 // 270° смещение для 18:00 = 0°
        let targetHour = Int(hours.truncatingRemainder(dividingBy: 24))
        let targetMinute = Int((hours - Double(targetHour)) * 60)
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = targetHour
        components.minute = targetMinute
        
        guard let targetTime = calendar.date(from: components) else { return nil }
        
        return MockReminder(
            id: UUID(),
            targetTime: targetTime,
            isEnabled: true,
            type: .today
        )
    }
}

// Запуск тестов
let success = ReminderTests.runTests()
exit(success ? 0 : 1)
