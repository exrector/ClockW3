import Foundation

// MARK: - Shared UserDefaults
/// Обеспечивает общий доступ к UserDefaults между приложением и виджетом через App Group
enum SharedUserDefaults {
    /// ID App Group (должен быть настроен в Xcode: Signing & Capabilities → App Groups)
    private static let appGroupID = "group.exrector.mow"
    private static let fallbackStore = UserDefaults()
    private static let resolvedStore = UserDefaults(suiteName: appGroupID)
    private static var didLogMissingGroup = false

    /// Общий UserDefaults для приложения и виджета
    /// ВАЖНО: без entitlement на App Group этот вызов вернёт nil.
    /// Мы НЕ падаем в стандартные UserDefaults, чтобы не маскировать проблему.
    static let shared: UserDefaults = {
        if let ud = resolvedStore {
            return ud
        } else {
            // Явно логируем проблему, чтобы её заметить в консоли
            // Возвращаем отдельный volatile контейнер, чтобы не писать в стандартный и не вводить в заблуждение.
            // Можно использовать UserDefaults() (in-memory) или всё же .standard, но с явным префиксом ключей.
            logMissingAppGroup()
            return fallbackStore
        }
    }()

    /// Флаг, который помогает быстро проверить наличие App Group
    static var usingAppGroup: Bool {
        resolvedStore != nil
    }

    /// Ключи
    static let selectedCitiesKey = "selectedCityIdentifiers"
    static let seededDefaultsKey = "didSeedDefaultCities"
    static let colorSchemeKey = "colorSchemePreference"
    static let windowOrientationKey = "windowOrientationPreference" // "landscape" или "portrait"
    static let premiumUnlockedKey = "premiumUnlocked"
    static let premiumPurchaseKey = "premiumPurchaseUnlocked"
    static let use12HourFormatKey = "use12HourFormat" // true = 12-hour AM/PM, false = 24-hour
    static let mechanismDebugKey = "debugMechanismEnabled"
    static let viewModeKey = "viewMode" // "clock" или "alternative"

    // DEPRECATED: Custom trial removed in favor of App Store subscriptions
    static let premiumTrialEndKey = "premiumTrialEnd"
    static let premiumTrialUsedKey = "premiumTrialUsed"

    private static func logMissingAppGroup() {
        guard !didLogMissingGroup else { return }
        didLogMissingGroup = true
#if DEBUG
#endif
        assertionFailure("App Group '\(appGroupID)' is not configured. Widgets will not sync settings.")
    }
}
