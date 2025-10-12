import Foundation

// MARK: - Shared UserDefaults
/// Обеспечивает общий доступ к UserDefaults между приложением и виджетом через App Group
enum SharedUserDefaults {
    /// ID App Group (должен быть настроен в Xcode: Signing & Capabilities → App Groups)
    private static let appGroupID = "group.exrector.ClockW3"

    /// Общий UserDefaults для приложения и виджета
    static let shared: UserDefaults = {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            print("⚠️ WARNING: App Group '\(appGroupID)' not configured. Using standard UserDefaults.")
            return UserDefaults.standard
        }
        return userDefaults
    }()

    /// Ключ для хранения выбранных городов
    static let selectedCitiesKey = "selectedCityIdentifiers"
}
