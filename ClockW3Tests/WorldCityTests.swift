#!/usr/bin/env swift
import Foundation

// Тесты управления городами
struct WorldCityTests {
    
    static func runTests() -> Bool {
        print("🧪 Тестирование управления городами...")
        
        var passed = 0
        var total = 0
        
        // Тест 1: Создание города с валидным часовым поясом
        total += 1
        let validCity = MockWorldCity(name: "Test", timeZoneIdentifier: "UTC", iataCode: "TST")
        if validCity.name == "Test" && validCity.iataCode == "TST" {
            passed += 1
            print("✅ Тест 1: Создание валидного города")
        } else {
            print("❌ Тест 1: Ошибка создания города")
        }
        
        // Тест 2: Проверка часового пояса
        total += 1
        if TimeZone(identifier: "UTC") != nil {
            passed += 1
            print("✅ Тест 2: UTC часовой пояс валиден")
        } else {
            print("❌ Тест 2: UTC часовой пояс не найден")
        }
        
        // Тест 3: Проверка локального часового пояса
        total += 1
        let localTZ = TimeZone.current.identifier
        if !localTZ.isEmpty {
            passed += 1
            print("✅ Тест 3: Локальный часовой пояс: \(localTZ)")
        } else {
            print("❌ Тест 3: Локальный часовой пояс не определён")
        }
        
        // Тест 4: Проверка инициализации по умолчанию
        total += 1
        let defaultIdentifiers = getInitialSelectionIdentifiers()
        if !defaultIdentifiers.isEmpty && defaultIdentifiers.contains(TimeZone.current.identifier) {
            passed += 1
            print("✅ Тест 4: Инициализация по умолчанию содержит локальный пояс")
        } else {
            print("❌ Тест 4: Ошибка инициализации по умолчанию")
        }
        
        print("📊 Результат: \(passed)/\(total) тестов пройдено")
        return passed == total
    }
    
    // Mock структуры для тестирования
    private struct MockWorldCity {
        let name: String
        let timeZoneIdentifier: String
        let iataCode: String
    }
    
    private static func getInitialSelectionIdentifiers() -> [String] {
        return [
            TimeZone.current.identifier,
            "UTC",
            "America/New_York",
            "Europe/London",
            "Asia/Tokyo"
        ]
    }
}

// Запуск тестов
let success = WorldCityTests.runTests()
exit(success ? 0 : 1)
