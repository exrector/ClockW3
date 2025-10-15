#!/usr/bin/env swift
import Foundation

// Тесты расчёта углов для ClockW3
struct AngleCalculationTests {
    
    static func runTests() -> Bool {
        
        var passed = 0
        var total = 0
        
        // Тест 1: 18:00 = 0° (опорная точка)
        total += 1
        let angle18 = calculateArrowAngle(hour: 18, minute: 0)
        if abs(angle18 - 0) < 0.001 {
            passed += 1
        } else {
        }
        
        // Тест 2: 00:00 = -270° = -3π/2
        total += 1
        let angle00 = calculateArrowAngle(hour: 0, minute: 0)
        let expected00 = -3 * Double.pi / 2
        if abs(angle00 - expected00) < 0.001 {
            passed += 1
        } else {
        }
        
        // Тест 3: 12:00 = -90° = -π/2
        total += 1
        let angle12 = calculateArrowAngle(hour: 12, minute: 0)
        let expected12 = -Double.pi / 2
        if abs(angle12 - expected12) < 0.001 {
            passed += 1
        } else {
        }
        
        // Тест 4: 06:00 = -180° = -π
        total += 1
        let angle06 = calculateArrowAngle(hour: 6, minute: 0)
        let expected06 = -Double.pi
        if abs(angle06 - expected06) < 0.001 {
            passed += 1
        } else {
        }
        
        return passed == total
    }
    
    // Локальная копия функции для тестирования
    private static func calculateArrowAngle(hour: Int, minute: Int) -> Double {
        let hour24 = Double(hour) + Double(minute) / 60.0
        let normalized = hour24 < 24 ? hour24 : hour24.truncatingRemainder(dividingBy: 24)
        let degrees = normalized * 15.0 - 18.0 * 15.0
        return degrees * Double.pi / 180.0
    }
}

// Запуск тестов
let success = AngleCalculationTests.runTests()
exit(success ? 0 : 1)
