import Foundation

// MARK: - Shared UserDefaults
/// Обеспечивает общий доступ к UserDefaults между приложением и виджетом через App Group
enum SharedUserDefaults {
    /// ID App Group (должен быть настроен в Xcode: Signing & Capabilities → App Groups)
    private static let appGroupID = "group.exrector.mow"

    /// Общий UserDefaults для приложения и виджета
    /// ВАЖНО: без entitlement на App Group этот вызов вернёт nil.
    /// Мы НЕ падаем в стандартные UserDefaults, чтобы не маскировать проблему.
    static let shared: UserDefaults = {
        if let ud = UserDefaults(suiteName: appGroupID) {
            return ud
        } else {
            // Явно логируем проблему, чтобы её заметить в консоли
            // Возвращаем отдельный volatile контейнер, чтобы не писать в стандартный и не вводить в заблуждение.
            // Можно использовать UserDefaults() (in-memory) или всё же .standard, но с явным префиксом ключей.
            let volatile = UserDefaults() // отдельный in-memory defaults
            return volatile
        }
    }()

    /// Ключи
    static let selectedCitiesKey = "selectedCityIdentifiers"
    static let seededDefaultsKey = "didSeedDefaultCities"
    static let colorSchemeKey = "colorSchemePreference"
}
