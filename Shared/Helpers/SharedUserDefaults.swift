import Foundation

// MARK: - Shared UserDefaults
/// Обеспечивает общий доступ к UserDefaults между приложением и виджетом через App Group
enum SharedUserDefaults {
    /// ID App Group (должен быть настроен в Xcode: Signing & Capabilities → App Groups)
    private static let appGroupID = "group.exrector.ClockW3"

    /// Общий UserDefaults для приложения и виджета
    static let shared: UserDefaults = {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return UserDefaults.standard
        }
        return userDefaults
    }()

    /// Ключ для хранения выбранных городов
    static let selectedCitiesKey = "selectedCityIdentifiers"
    static let seededDefaultsKey = "didSeedDefaultCities"

    /// Ключ для хранения предпочтения цветовой схемы (system/light/dark)
    static let colorSchemeKey = "colorSchemePreference"
}
