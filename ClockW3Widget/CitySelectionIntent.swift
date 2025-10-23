//
//  CitySelectionIntent.swift
//  ClockW3
//
//  Widget configuration for city selection
//

import AppIntents
import Foundation

// MARK: - City Entity для AppIntents
struct CityEntity: AppEntity {
    let id: String
    let displayName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "City")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    static var defaultQuery = CityQuery()
}

// MARK: - City Query
struct CityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CityEntity] {
        // Динамически загружаем города при каждом запросе
        let cities = await loadSavedCitiesAsync()
        return cities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CityEntity] {
        // Динамически загружаем города при каждом запросе - БЕЗ кэширования
        return await loadSavedCitiesAsync()
    }

    func defaultResult() async -> CityEntity? {
        let cities = await loadSavedCitiesAsync()
        return cities.first
    }

    private func loadSavedCitiesAsync() async -> [CityEntity] {
        // Принудительная синхронизация UserDefaults перед чтением
        SharedUserDefaults.shared.synchronize()

        // Читаем сохранённые города из SharedUserDefaults (формат: строка с разделителем запятой)
        let idsString = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.selectedCitiesKey) ?? ""
        print("🔍 CityQuery: idsString = '\(idsString)'")

        var identifiers = idsString.split(separator: ",").map(String.init)
        print("🔍 CityQuery: identifiers count = \(identifiers.count), list = \(identifiers)")

        // Если нет сохранённых, возвращаем дефолтные
        if identifiers.isEmpty {
            identifiers = WorldCity.initialSelectionIdentifiers()
            print("🔍 CityQuery: Using default identifiers, count = \(identifiers.count)")
        }

        let entities = identifiers.map { identifier in
            let name = TimeZoneDirectory.cityName(forIdentifier: identifier)
            return CityEntity(id: identifier, displayName: name)
        }
        print("🔍 CityQuery: Returning \(entities.count) cities")

        // Небольшая задержка чтобы система поняла что это динамический запрос
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 секунды

        return entities
    }
}

// MARK: - Widget Configuration Intents
struct MediumWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select City"
    static var description = IntentDescription("Choose which city to display")

    @Parameter(title: "City", default: nil)
    var city: CityEntity?
}

struct SmallWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select City"
    static var description = IntentDescription("Choose which city to display")

    @Parameter(title: "City", default: nil)
    var city: CityEntity?
}

struct LargeWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select City"
    static var description = IntentDescription("Choose which city to display")

    @Parameter(title: "City", default: nil)
    var city: CityEntity?
}
