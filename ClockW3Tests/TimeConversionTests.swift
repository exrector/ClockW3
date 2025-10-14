#!/usr/bin/env swift
import Foundation

// Тесты точности преобразования время ↔ угол
struct TimeConversionTests {
    
    static func runTests() -> Bool {
        print("🧪 Тестирование точности преобразования время ↔ угол...")
        
        var passed = 0
        var total = 0
        
        // Тест 1: Точность для ровных часов
        total += 1
        let success1 = testExactHours()
        if success1 {
            passed += 1
            print("✅ Тест 1: Точность для ровных часов")
        } else {
            print("❌ Тест 1: Ошибка точности для ровных часов")
        }
        
        // Тест 2: Точность для получасовых значений
        total += 1
        let success2 = testHalfHours()
        if success2 {
            passed += 1
            print("✅ Тест 2: Точность для получасовых значений")
        } else {
            print("❌ Тест 2: Ошибка точности для получасовых значений")
        }
        
        // Тест 3: Точность для четвертьчасовых значений
        total += 1
        let success3 = testQuarterHours()
        if success3 {
            passed += 1
            print("✅ Тест 3: Точность для четвертьчасовых значений")
        } else {
            print("❌ Тест 3: Ошибка точности для четвертьчасовых значений")
        }
        
        // Тест 4: Полный цикл преобразования
        total += 1
        let success4 = testFullCycle()
        if success4 {
            passed += 1
            print("✅ Тест 4: Полный цикл преобразования")
        } else {
            print("❌ Тест 4: Ошибка полного цикла")
        }
        
        print("📊 Результат: \(passed)/\(total) тестов пройдено")
        return passed == total
    }
    
    private static func testExactHours() -> Bool {
        let testHours = [0, 6, 12, 18]
        
        for hour in testHours {
            let angle = calculateArrowAngle(hour: hour, minute: 0)
            let reminder = createReminderFromAngle(angle, hour: 12, minute: 0) // Базовое время 12:00
            
            // Проверяем что время округлилось правильно (допускаем ±15 минут)
            let expectedMinutes = hour * 60
            let actualMinutes = reminder.hour * 60 + reminder.minute
            let diff = abs(actualMinutes - expectedMinutes)
            
            if diff > 15 && diff < (24 * 60 - 15) { // Учитываем переход через полночь
                print("  ❌ Час \(hour): ожидали \(hour):00, получили \(reminder.hour):\(String(format: "%02d", reminder.minute))")
                return false
            }
        }
        
        return true
    }
    
    private static func testHalfHours() -> Bool {
        let testTimes = [(6, 30), (12, 30), (18, 30), (0, 30)]
        
        for (hour, minute) in testTimes {
            let angle = calculateArrowAngle(hour: hour, minute: minute)
            let reminder = createReminderFromAngle(angle, hour: 12, minute: 0)
            
            // Проверяем точность (допускаем ±15 минут)
            let expectedMinutes = hour * 60 + minute
            let actualMinutes = reminder.hour * 60 + reminder.minute
            let diff = abs(actualMinutes - expectedMinutes)
            
            if diff > 15 && diff < (24 * 60 - 15) {
                print("  ❌ Время \(hour):\(minute): получили \(reminder.hour):\(String(format: "%02d", reminder.minute))")
                return false
            }
        }
        
        return true
    }
    
    private static func testQuarterHours() -> Bool {
        let testTimes = [(12, 15), (12, 45), (6, 15), (18, 45)]
        
        for (hour, minute) in testTimes {
            let angle = calculateArrowAngle(hour: hour, minute: minute)
            let reminder = createReminderFromAngle(angle, hour: 12, minute: 0)
            
            // Для четвертьчасовых значений должно быть точное попадание
            let expectedMinutes = hour * 60 + minute
            let actualMinutes = reminder.hour * 60 + reminder.minute
            let diff = abs(actualMinutes - expectedMinutes)
            
            if diff > 0 && diff < (24 * 60) {
                print("  ❌ Время \(hour):\(minute): получили \(reminder.hour):\(String(format: "%02d", reminder.minute))")
                return false
            }
        }
        
        return true
    }
    
    private static func testFullCycle() -> Bool {
        // Тестируем полный цикл: время → угол → время для критических точек
        let criticalTimes = [
            (0, 0),   // Полночь
            (6, 0),   // Утро
            (12, 0),  // Полдень  
            (18, 0),  // Вечер (опорная точка)
            (23, 59)  // Почти полночь
        ]
        
        for (originalHour, originalMinute) in criticalTimes {
            // Время → угол
            let angle = calculateArrowAngle(hour: originalHour, minute: originalMinute)
            
            // Угол → время
            let reminder = createReminderFromAngle(angle, hour: 12, minute: 0)
            
            // Проверяем точность (для ровных часов должно быть точно)
            if originalMinute == 0 {
                if reminder.hour != originalHour || reminder.minute != 0 {
                    print("  ❌ Цикл \(originalHour):00: получили \(reminder.hour):\(String(format: "%02d", reminder.minute))")
                    return false
                }
            }
        }
        
        return true
    }
    
    // Вспомогательные функции
    private static func calculateArrowAngle(hour: Int, minute: Int) -> Double {
        let hour24 = Double(hour) + Double(minute) / 60.0
        let degrees = hour24 * 15.0 - 18.0 * 15.0
        return degrees * Double.pi / 180.0
    }
    
    private static func createReminderFromAngle(_ rotationAngle: Double, hour: Int, minute: Int) -> MockReminder {
        // Имитируем новую логику ClockReminder.fromRotationAngle
        // rotationAngle напрямую преобразуется в время (без учёта текущего времени)
        
        var normalizedAngle = rotationAngle.truncatingRemainder(dividingBy: 2.0 * Double.pi)
        if normalizedAngle < 0 {
            normalizedAngle += 2.0 * Double.pi
        }
        
        let degrees = normalizedAngle * 180.0 / Double.pi
        let hourFloat = (degrees / 15.0 + 18.0).truncatingRemainder(dividingBy: 24.0)
        
        // Округляем до ближайших 15 минут
        let totalMinutes = hourFloat * 60.0
        let roundedMinutes = round(totalMinutes / 15.0) * 15.0
        
        let resultHour = Int(roundedMinutes / 60.0) % 24
        let resultMinute = Int(roundedMinutes.truncatingRemainder(dividingBy: 60.0))
        
        return MockReminder(hour: resultHour, minute: resultMinute)
    }
    
    private struct MockReminder {
        let hour: Int
        let minute: Int
    }
}

// Запуск тестов
let success = TimeConversionTests.runTests()
exit(success ? 0 : 1)
