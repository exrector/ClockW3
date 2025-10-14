#!/usr/bin/env swift
import Foundation

// Тесты производительности
struct PerformanceTests {
    
    static func runTests() -> Bool {
        print("🧪 Тестирование производительности...")
        
        var passed = 0
        var total = 0
        
        // Тест 1: Производительность расчёта углов
        total += 1
        let startTime1 = CFAbsoluteTimeGetCurrent()
        for hour in 0..<24 {
            for minute in 0..<60 {
                _ = calculateArrowAngle(hour: hour, minute: minute)
            }
        }
        let duration1 = CFAbsoluteTimeGetCurrent() - startTime1
        if duration1 < 0.1 { // Должно выполняться менее чем за 100мс
            passed += 1
            print("✅ Тест 1: Расчёт углов за \(String(format: "%.3f", duration1))с")
        } else {
            print("❌ Тест 1: Расчёт углов слишком медленный: \(String(format: "%.3f", duration1))с")
        }
        
        // Тест 2: Производительность нормализации углов
        total += 1
        let startTime2 = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10000 {
            _ = normalizeAngle(Double.random(in: -10*Double.pi...10*Double.pi))
        }
        let duration2 = CFAbsoluteTimeGetCurrent() - startTime2
        if duration2 < 0.05 { // Должно выполняться менее чем за 50мс
            passed += 1
            print("✅ Тест 2: Нормализация углов за \(String(format: "%.3f", duration2))с")
        } else {
            print("❌ Тест 2: Нормализация углов слишком медленная: \(String(format: "%.3f", duration2))с")
        }
        
        // Тест 3: Производительность создания дат
        total += 1
        let startTime3 = CFAbsoluteTimeGetCurrent()
        for _ in 0..<1000 {
            _ = Date()
        }
        let duration3 = CFAbsoluteTimeGetCurrent() - startTime3
        if duration3 < 0.01 { // Должно выполняться менее чем за 10мс
            passed += 1
            print("✅ Тест 3: Создание дат за \(String(format: "%.3f", duration3))с")
        } else {
            print("❌ Тест 3: Создание дат слишком медленное: \(String(format: "%.3f", duration3))с")
        }
        
        print("📊 Результат: \(passed)/\(total) тестов пройдено")
        return passed == total
    }
    
    // Вспомогательные функции для тестирования
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
let success = PerformanceTests.runTests()
exit(success ? 0 : 1)
