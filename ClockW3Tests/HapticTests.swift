#!/usr/bin/env swift
import Foundation

// Тесты хаптической обратной связи
struct HapticTests {
    
    static func runTests() -> Bool {
        
        
        var passed = 0
        var total = 0
        
        // Тест 1: Расчёт индекса риски
        total += 1
        let index0 = tickIndex(for: 0)
        if index0 == 0 {
            passed += 1
        } else {
        }
        
        // Тест 2: Индекс для 90°
        total += 1
        let index90 = tickIndex(for: Double.pi / 2)
        let expected90 = 24 // четверть оборота
        if index90 == expected90 {
            passed += 1
        } else {
        }
        
        // Тест 3: Определение типа риски - часовая
        total += 1
        let hourType = tickType(for: 0)
        if hourType == .hour {
            passed += 1
        } else {
        }
        
        // Тест 4: Определение типа риски - получасовая
        total += 1
        let halfHourType = tickType(for: 8)
        if halfHourType == .halfHour {
            passed += 1
        } else {
        }
        
        // Тест 5: Определение типа риски - четвертьчасовая
        total += 1
        let quarterType = tickType(for: 4)
        if quarterType == .quarter {
            passed += 1
        } else {
        }
        
        return passed == total
    }
    
    // Типы рисок
    private enum TickType {
        case hour, halfHour, quarter, regular
    }
    
    // Вспомогательные функции
    private static func tickIndex(for angle: Double) -> Int {
        let ticksPerRevolution = 96
        let normalizedAngle = angle < 0 ? angle + 2 * Double.pi : angle
        let tickAngle = 2 * Double.pi / Double(ticksPerRevolution)
        return Int(round(normalizedAngle / tickAngle)) % ticksPerRevolution
    }
    
    private static func tickType(for index: Int) -> TickType {
        if index % 16 == 0 { return .hour }
        if index % 8 == 0 { return .halfHour }
        if index % 4 == 0 { return .quarter }
        return .regular
    }
}

// Запуск тестов
let success = HapticTests.runTests()
exit(success ? 0 : 1)
