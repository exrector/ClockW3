import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - World City Model (портированная из AppWorldCity)
struct WorldCity: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var timeZoneIdentifier: String

    init(name: String, timeZoneIdentifier: String) {
        self.id = UUID()
        self.name = name
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    var iataCode: String {
        // IATA коды аэропортов (3 буквы) для известных городов
        let iataCodes: [String: String] = [
            // Америка
            "New York": "NYC",
            "Los Angeles": "LAX",
            "San Francisco": "SFO",
            "Chicago": "CHI",
            "Miami": "MIA",
            "Denver": "DEN",
            "Phoenix": "PHX",

            // Европа
            "London": "LON",
            "Paris": "PAR",
            "Berlin": "BER",
            "Rome": "ROM",
            "Madrid": "MAD",
            "Amsterdam": "AMS",
            "Brussels": "BRU",
            "Vienna": "VIE",
            "Prague": "PRG",
            "Warsaw": "WAW",
            "Athens": "ATH",
            "Lisbon": "LIS",
            "Dublin": "DUB",
            "Copenhagen": "CPH",
            "Stockholm": "STO",
            "Oslo": "OSL",
            "Helsinki": "HEL",
            "Moscow": "MOW",
            "Saint Petersburg": "LED",

            // Азия
            "Tokyo": "TYO",
            "Shanghai": "SHA",
            "Beijing": "BJS",
            "Hong Kong": "HKG",
            "Singapore": "SIN",
            "Dubai": "DXB",
            "Bangkok": "BKK",
            "Seoul": "SEL",
            "Delhi": "DEL",
            "Mumbai": "BOM",
            "Istanbul": "IST",
            "Tel Aviv": "TLV",

            // Океания
            "Sydney": "SYD",
            "Melbourne": "MEL",
            "Auckland": "AKL",

            // Южная Америка
            "Rio de Janeiro": "RIO",
            "Sao Paulo": "SAO",
            "Buenos Aires": "BUE",

            // Африка
            "Cairo": "CAI",
            "Johannesburg": "JNB",
            "Cape Town": "CPT"
        ]

        let cityName = TimeZoneDirectory.cityName(forIdentifier: timeZoneIdentifier)

        if let iata = iataCodes[cityName] {
            return iata
        }

        // Для неизвестных городов - первые 3 буквы заглавными
        return String(cityName.prefix(3)).uppercased()
    }
}

// MARK: - Default Cities
extension WorldCity {
    static var defaultCities: [WorldCity] {
        recommendedTimeZoneIdentifiers.compactMap { WorldCity.make(identifier: $0) }
    }

    static func make(identifier: String) -> WorldCity {
        let resolvedName = TimeZoneDirectory.cityName(forIdentifier: identifier)
        return WorldCity(name: resolvedName, timeZoneIdentifier: identifier)
    }

    static var recommendedTimeZoneIdentifiers: [String] {
        let base = TimeZone.current.identifier
        let defaults = [
            base,
            "Europe/London",
            "America/New_York",
            "Europe/Berlin",
            "Asia/Tokyo",
            "Asia/Shanghai"
        ]
        var seen = Set<String>()
        return defaults.filter { seen.insert($0).inserted }
    }

    static func cities(from identifiers: [String]) -> [WorldCity] {
        identifiers.compactMap { identifier in
            guard TimeZone(identifier: identifier) != nil else { return nil }
            return WorldCity.make(identifier: identifier)
        }
    }
}

enum TimeZoneDirectory {
    struct Entry: Identifiable, Hashable {
        let id: String
        let name: String
        let gmtOffset: String

        var displayName: String { "\(name) (\(gmtOffset))" }
    }

    static func cityName(forIdentifier identifier: String) -> String {
        let parts = identifier.split(separator: "/")
        return parts.last?.replacingOccurrences(of: "_", with: " ") ?? identifier
    }

    static func displayName(forIdentifier identifier: String) -> String {
        let city = cityName(forIdentifier: identifier)
        let parts = identifier.split(separator: "/")
        if parts.count > 1 {
            let region = parts.first?.replacingOccurrences(of: "_", with: " ") ?? ""
            if !region.isEmpty {
                return "\(city) — \(region)"
            }
        }
        return city
    }

    static func gmtOffsetString(for identifier: String, at date: Date = Date()) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "GMT" }
        let seconds = tz.secondsFromGMT(for: date)
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        return String(format: "GMT%+02d:%02d", hours, minutes)
    }

    static func allEntries() -> [Entry] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { id in
            guard TimeZone(identifier: id) != nil else { return nil }
            let name = displayName(forIdentifier: id)
            let offset = gmtOffsetString(for: id)
            return Entry(id: id, name: name, gmtOffset: offset)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
