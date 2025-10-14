#!/usr/bin/env swift
import Foundation

// Интеграционные тесты
struct IntegrationTests {
    
    static func runTests() -> Bool {
        print("🧪 Интеграционные тесты...")
        
        var passed = 0
        var total = 0
        
        // Тест 1: Полный цикл расчёта времени
        total += 1
        let success1 = testFullTimeCalculationCycle()
        if success1 {
            passed += 1
            print("✅ Тест 1: Полный цикл расчёта времени")
        } else {
            print("❌ Тест 1: Ошибка в цикле расчёта времени")
        }
        
        // Тест 2: Интеграция с системными настройками
        total += 1
        let success2 = testSystemIntegration()
        if success2 {
            passed += 1
            print("✅ Тест 2: Интеграция с системой")
        } else {
            print("❌ Тест 2: Ошибка интеграции с системой")
        }
        
        // Тест 3: Обработка граничных случаев
        total += 1
        let success3 = testEdgeCases()
        if success3 {
            passed += 1
            print("✅ Тест 3: Граничные случаи")
        } else {
            print("❌ Тест 3: Ошибка в граничных случаях")
        }
        
        print("📊 Результат: \(passed)/\(total) тестов пройдено")
        return passed == total
    }
    
    private static func testFullTimeCalculationCycle() -> Bool {
        // Тестируем полный цикл: время -> угол -> время
        let originalTime = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: originalTime)
        let minute = calendar.component(.minute, from: originalTime)
        
        // Время -> угол
        let angle = calculateArrowAngle(hour: hour, minute: minute)
        
        // Угол -> время (обратное преобразование)
        let degrees = angle * 180.0 / Double.pi
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees
        let calculatedHours = (normalizedDegrees + 270) / 15.0
        let calculatedHour = Int(calculatedHours.truncatingRemainder(dividingBy: 24))
        
        // Проверяем точность (допускаем погрешность в 1 час)
        return abs(calculatedHour - hour) <= 1
    }
    
    private static func testSystemIntegration() -> Bool {
        // Тестируем интеграцию с системными компонентами
        let currentTimeZone = TimeZone.current
        let utcTimeZone = TimeZone(identifier: "UTC")
        
        // Проверяем доступность часовых поясов
        guard utcTimeZone != nil else { return false }
        
        // Проверяем работу с календарём
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        return components.year != nil && components.hour != nil
    }
    
    private static func testEdgeCases() -> Bool {
        // Тестируем граничные случаи
        var allPassed = true
        
        // Полночь
        let midnight = calculateArrowAngle(hour: 0, minute: 0)
        if abs(midnight - (-3 * Double.pi / 2)) > 0.001 {
            allPassed = false
        }
        
        // 23:59
        let almostMidnight = calculateArrowAngle(hour: 23, minute: 59)
        let expectedAlmostMidnight = ((23 + 59.0/60.0) * 15.0 - 270.0) * Double.pi / 180.0
        if abs(almostMidnight - expectedAlmostMidnight) > 0.1 {
            allPassed = false
        }
        
        // Нормализация больших углов
        let largeAngle = 10 * Double.pi
        let normalized = normalizeAngle(largeAngle)
        if abs(normalized) > Double.pi {
            allPassed = false
        }
        
        return allPassed
    }
    
    // Вспомогательные функции
    private static func calculateArrowAngle(hour: Int, minute: Int) -> Double {
        let hour24 = Double(hour) + Double(minute) / 60.0
        let degrees = hour24 * 15.0 - 18.0 * 15.0
        return degrees * Double.pi / 180.0
    }
    
    private static func normalizeAngle(_ angle: Double) -> Double {
        let twoPi = 2 * Double.pi
        var result = angle.truncatingRemainder(dividingBy: twoPi)
        if result > Double.pi {
            result -= twoPi
        } else if result <= -Double.pi {
            result += twoPi
        }
        return result
    }
}

// Запуск тестов
let success = IntegrationTests.runTests()
exit(success ? 0 : 1)
