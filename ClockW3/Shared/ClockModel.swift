import SwiftUI
import Observation

// MARK: - Clock City Model
struct ClockCity: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let timeZoneIdentifier: String

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    // Инициализатор с прямым TimeZone (для удобства)
    init(name: String, timeZone: TimeZone) {
        self.name = name
        self.timeZoneIdentifier = timeZone.identifier
    }

    // Инициализатор с строкой
    init(name: String, timeZoneIdentifier: String) {
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    static func == (lhs: ClockCity, rhs: ClockCity) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Default Cities
extension ClockCity {
    static let defaultCities: [ClockCity] = WorldCity.defaultCities.map {
        ClockCity(name: $0.name, timeZoneIdentifier: $0.timeZoneIdentifier)
    }
}

// MARK: - Clock State (для основного приложения)
@MainActor
@Observable
class ClockState {
    var currentTime: Date = Date()
    var cities: [ClockCity] = ClockCity.defaultCities
    var rotationAngle: CGFloat = 0  // Текущий угол вращения контейнера

    init() {}
}
