import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications
#if canImport(StoreKit)
import StoreKit
#endif
#if os(macOS)
import AppKit
#endif

// MARK: - Async compatibility helpers for UNUserNotificationCenter
private extension UNUserNotificationCenter {
    func notificationSettingsCompat() async -> UNNotificationSettings {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return await self.notificationSettings()
        } else {
            return await withCheckedContinuation { continuation in
                self.getNotificationSettings { settings in
                    continuation.resume(returning: settings)
                }
            }
        }
        #else
        if #available(iOS 15.0, *) {
            return await self.notificationSettings()
        } else {
            return await withCheckedContinuation { continuation in
                self.getNotificationSettings { settings in
                    continuation.resume(returning: settings)
                }
            }
        }
        #endif
    }

    func pendingNotificationRequestsCompat() async -> [UNNotificationRequest] {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            return await self.pendingNotificationRequests()
        } else {
            return await withCheckedContinuation { continuation in
                self.getPendingNotificationRequests { requests in
                    continuation.resume(returning: requests)
                }
            }
        }
        #else
        if #available(iOS 15.0, *) {
            return await self.pendingNotificationRequests()
        } else {
            return await withCheckedContinuation { continuation in
                self.getPendingNotificationRequests { requests in
                    continuation.resume(returning: requests)
                }
            }
        }
        #endif
    }
}

// MARK: - AppDelegate with Notifications setup
#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Task { @MainActor in
            _ = await ReminderManager.shared.requestPermission()

            // Если пользователь только что дал разрешение и у нас уже есть сохранённое напоминание — пересоздадим расписание
            if let reminder = ReminderManager.shared.currentReminder, reminder.isEnabled {
                await ReminderManager.shared.setReminder(reminder)
            }
        }
    }

    // Показывать баннер/звук, даже если приложение активно
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 Notification will present (macOS)")

        // Если LA отключена, сразу удалим сработавшее одноразовое напоминание
        ReminderManager.shared.pruneExpiredReminderImmediatelyIfNeeded()

        if #available(macOS 11.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 Notification did receive response (macOS)")

        // Если LA отключена, сразу удалим сработавшее одноразовое напоминание
        ReminderManager.shared.pruneExpiredReminderImmediatelyIfNeeded()

        completionHandler()
    }
}
#else
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        setupNotifications()
        return true
    }

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        Task { @MainActor in
            _ = await ReminderManager.shared.requestPermission()
            if let reminder = ReminderManager.shared.currentReminder, reminder.isEnabled {
                await ReminderManager.shared.setReminder(reminder)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("🔔 Notification will present (app in foreground)")

        // Обновляем Live Activity при доставке уведомления
        #if canImport(ActivityKit) && !os(macOS)
        Task { @MainActor in
            if let reminder = ReminderManager.shared.currentReminder {
                print("🔔 Triggering Live Activity update from notification")
                if #available(iOS 16.1, *) {
                    await ReminderManager.shared.forceUpdateLiveActivity(for: reminder)
                }
            }
        }
        #endif

        // Если LA отключена, сразу удалим сработавшее одноразовое напоминание
        ReminderManager.shared.pruneExpiredReminderImmediatelyIfNeeded()

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }

    // Вызывается когда пользователь взаимодействует с уведомлением
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("🔔 Notification did receive response (user tapped)")

        // Обновляем Live Activity когда пользователь нажимает на уведомление
        #if canImport(ActivityKit) && !os(macOS)
        Task { @MainActor in
            if let reminder = ReminderManager.shared.currentReminder {
                print("🔔 Triggering Live Activity update from tap")
                if #available(iOS 16.1, *) {
                    await ReminderManager.shared.forceUpdateLiveActivity(for: reminder)
                }
            }
        }
        #endif

        // Если LA отключена, сразу удалим сработавшее одноразовое напоминание
        ReminderManager.shared.pruneExpiredReminderImmediatelyIfNeeded()

        completionHandler()
    }
}
#endif

// MARK: - ОСНОВНОЕ ПРИЛОЖЕНИЕ (Движущиеся стрелки)
// Это основное приложение с полным функционалом и движущимися стрелками
// В отличие от ПОВОРОТНОГО ЦИФЕРБЛАТА, здесь стрелки движутся
@main
struct SwiftUIClockApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
#if os(macOS)
        let orientation = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.windowOrientationKey) ?? "landscape"
        let defaultSize = orientation == "landscape"
            ? CGSize(width: 893, height: 500)
            : CGSize(width: 449, height: 938)
#endif
        return WindowGroup {
            ContentView()
        }
#if os(macOS)
        .defaultSize(width: defaultSize.width, height: defaultSize.height)
        .windowResizability(.contentSize)
#endif
    }
}



// MARK: - Settings View
struct SettingsView: View {
    // Выбор городов (используем SharedUserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.selectedCitiesKey,
        store: SharedUserDefaults.shared
    ) private var selectedCityIdentifiers: String = ""
    @AppStorage(
        SharedUserDefaults.premiumUnlockedKey,
        store: SharedUserDefaults.shared
    ) private var premiumUnlocked: Bool = false
    @State private var selectedIds: Set<String> = []
    @State private var selectedEntries: [TimeZoneDirectory.Entry] = []
    @State private var showTimeZonePicker = false
    @State private var showMacOSCityPicker = false
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false

    // Цветовая схема (используем SharedUserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.colorSchemeKey,
        store: SharedUserDefaults.shared
    ) private var colorSchemePreference: String = "system"

    // 12/24-часовой формат
    @AppStorage(
        SharedUserDefaults.use12HourFormatKey,
        store: SharedUserDefaults.shared
    ) private var use12HourFormat: Bool = false

    // Режим вида
    @AppStorage(
        SharedUserDefaults.viewModeKey,
        store: SharedUserDefaults.shared
    ) private var viewMode: String = "clock"

#if os(macOS)
    // Ориентация окна для macOS
    @AppStorage(
        SharedUserDefaults.windowOrientationKey,
        store: SharedUserDefaults.shared
    ) private var windowOrientationPreference: String = "landscape"
#endif
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Напоминание
    @StateObject private var reminderManager = ReminderManager.shared
    @State private var editContext: ReminderEditContext?
    @StateObject private var storeManager = StoreManager()
    @State private var purchaseAlert: PurchaseAlert?

    private struct ReminderEditContext: Identifiable {
        let reminder: ClockReminder

        var id: UUID { reminder.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            topReminderBlock
                .padding(.horizontal, 24)
#if os(macOS)
                .padding(.vertical, windowOrientationPreference == "portrait" ? 8 : 16)
#else
                .padding(.vertical, 16)
#endif

            ScrollView {
                VStack(spacing: 16) {
                    citiesList

#if os(iOS)
                    Button {
                        showTimeZonePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.body)
                            Text("Choose Cities")
                                .font(.body)
                        }
                        .foregroundStyle(colorScheme == .light ? .black : .white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.primary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: horizontalSizeClass == .regular ? .infinity : 360)
#elseif os(macOS)
                    VStack(spacing: 0) {
                        Button {
                            showMacOSCityPicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Spacer()
                                Image(systemName: showMacOSCityPicker ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Choose Cities")
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if showMacOSCityPicker {
                            TimeZoneSelectionInlineView(selection: $selectedIds, onChanged: persistSelection)
                                .frame(maxHeight: 300)
                        }
                    }
                    .frame(maxWidth: 360)
                    .padding(.top, 8)
#endif

                    themeControls
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)

                    designedByFooter
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            loadSelection()
            initializeColorSchemeIfNeeded()
        }
        .onChange(of: selectedIds) { _, _ in
            persistSelection()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            loadSelection()
        }
        .onChange(of: colorSchemePreference) { _, _ in
            reloadWidgets()
        }
        .sheet(isPresented: $showTimeZonePicker) {
            NavigationStack {
                TimeZoneSelectionView(selection: $selectedIds) { newSelection in
                    selectedIds = newSelection
                }
                #if os(iOS)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.disabled)
                .presentationCompactAdaptation(.none)
                #endif
            }
#if os(macOS)
            .presentationDetents([.fraction(0.55)])
#endif
        }
        .sheet(item: $editContext) { context in
#if os(iOS)
            NavigationStack {
                EditReminderView(reminder: context.reminder) { hour, minute, date in
                    Task { @MainActor in
                        // Если редактируем подтверждённое напоминание - обновляем его
                        if reminderManager.currentReminder != nil {
                            await reminderManager.updateReminderTime(hour: hour, minute: minute)
                        } else {
                            // Если редактируем временное - обновляем временное время с датой
                            reminderManager.updateTemporaryTime(hour: hour, minute: minute, date: date)
                        }
                        editContext = nil
                    }
                }
                .navigationTitle("Edit Reminder")
                // Attach sheet presentation config directly to content (iOS)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
                .presentationBackgroundInteraction(.disabled)
                .presentationCompactAdaptation(.none)
            }
#else
            EditReminderView(reminder: context.reminder) { hour, minute, date in
                Task { @MainActor in
                    // Если редактируем подтверждённое напоминание - обновляем его
                    if reminderManager.currentReminder != nil {
                        await reminderManager.updateReminderTime(hour: hour, minute: minute)
                    } else {
                        // Если редактируем временное - обновляем временное время с датой
                        reminderManager.updateTemporaryTime(hour: hour, minute: minute, date: date)
                    }
                    editContext = nil
                }
            }
#endif
        }
// iOS sheet detents are attached inside the sheet content above
        .alert(item: $purchaseAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Extracted sections to reduce type-checking load

    @ViewBuilder
    private var topReminderBlock: some View {
        VStack(spacing: 16) {
            if let reminder = reminderManager.currentReminder {
                currentReminderRow(reminder: reminder)
            } else if let hour = reminderManager.temporaryHour, let minute = reminderManager.temporaryMinute {
                temporaryReminderRow(hour: hour, minute: minute)
            }
        }
    }

    @ViewBuilder
    private func temporaryReminderRow(hour: Int, minute: Int) -> some View {
        // Создаём временный объект для отображения
        let effectiveDate = reminderManager.temporaryDate ?? ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: Date())
        let isDailyPreview = reminderManager.temporaryIsDaily
        let temporaryReminder = ClockReminder(
            hour: hour,
            minute: minute,
            date: isDailyPreview ? nil : effectiveDate,
            isEnabled: false,
            liveActivityEnabled: ReminderManager.shared.lastPreviewLiveActivityEnabled,
            alwaysLiveActivity: false,
            isTimeSensitive: ReminderManager.shared.lastPreviewTimeSensitiveEnabled,
            preserveExactMinute: true
        )

#if os(iOS)
        let modeChangeHandler: (Bool) -> Void = { isDaily in
            reminderManager.updateTemporaryMode(isDaily: isDaily)
        }
        let liveActivityHandler: (Bool) -> Void = { isEnabled in
            // Сохраняем состояние LA для превью
            ReminderManager.shared.setPreviewLiveActivityEnabled(isEnabled)
        }
        let timeSensitiveHandler: (Bool) -> Void = { isEnabled in
            // Сохраняем состояние Time-Sensitive для превью
            ReminderManager.shared.setPreviewTimeSensitiveEnabled(isEnabled)
        }

        ReminderRow(
            reminder: temporaryReminder,
            isPreview: true,
            use12HourFormat: use12HourFormat,
            onModeChange: modeChangeHandler,
            onLiveActivityToggle: liveActivityHandler,

            onTimeSensitiveToggle: timeSensitiveHandler,
            onEdit: {
                editContext = ReminderEditContext(reminder: temporaryReminder)
            },
            onRemove: nil,
            onConfirm: {
                Task {
                    await reminderManager.confirmTemporaryReminder()
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .center)
#else
        let modeChangeHandler: (Bool) -> Void = { isDaily in
            reminderManager.updateTemporaryMode(isDaily: isDaily)
        }

        ReminderRow(
            reminder: temporaryReminder,
            isPreview: true,
            use12HourFormat: use12HourFormat,
            onModeChange: modeChangeHandler,
            onEdit: {
                editContext = ReminderEditContext(reminder: temporaryReminder)
            },
            onRemove: nil,
            onConfirm: {
                Task {
                    await reminderManager.confirmTemporaryReminder()
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .center)
#endif
    }

    @ViewBuilder
    private func currentReminderRow(reminder: ClockReminder) -> some View {
#if os(iOS)
        let modeChangeHandler: (Bool) -> Void = { isDaily in
            Task {
                await reminderManager.updateReminderRepeat(isDaily: isDaily)
            }
        }
        let liveActivityHandler: (Bool) -> Void = { isEnabled in
            Task {
                await reminderManager.updateLiveActivityEnabled(isEnabled: isEnabled)
            }
        }
        let timeSensitiveHandler: (Bool) -> Void = { isEnabled in
            Task {
                await reminderManager.updateTimeSensitiveEnabled(isEnabled: isEnabled)
            }
        }
        // Кнопки Live/Time‑Sensitive остаются на месте и после подтверждения,
        // но становятся визуально приглушёнными и неактивными.
        // Статусные 3 строки всегда на месте.
        ReminderRow(
            reminder: reminder,
            isPreview: false,
            use12HourFormat: use12HourFormat,
            onModeChange: modeChangeHandler,
            onLiveActivityToggle: liveActivityHandler,
            onTimeSensitiveToggle: timeSensitiveHandler,
            onEdit: {
                editContext = ReminderEditContext(reminder: reminder)
            },
            onRemove: {
                reminderManager.deleteReminder()
            },
            onConfirm: nil
        )
        .frame(maxWidth: .infinity, alignment: .center)
#else
        let modeChangeHandler: (Bool) -> Void = { isDaily in
            Task {
                await reminderManager.updateReminderRepeat(isDaily: isDaily)
            }
        }

        ReminderRow(
            reminder: reminder,
            isPreview: false,
            use12HourFormat: use12HourFormat,
            onModeChange: modeChangeHandler,
            onEdit: {
                editContext = ReminderEditContext(reminder: reminder)
            },
            onRemove: {
                reminderManager.deleteReminder()
            },
            onConfirm: nil
        )
        .frame(maxWidth: .infinity, alignment: .center)
#endif
    }


    @ViewBuilder
    private var citiesList: some View {
        if selectedEntries.isEmpty {
            Text("No cities selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(selectedEntries, id: \.id) { entry in
                    cityRow(for: entry)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func cityRow(for entry: TimeZoneDirectory.Entry) -> some View {
        let removable = entry.id != localCityIdentifier

        // UI реакция: подсветка активной плитки и возможность тапать только при активной LA
        let isSelected = reminderManager.selectedCityIdentifier == entry.id
        #if os(iOS)
        // Тапы по плиткам городов разрешены ТОЛЬКО когда активна Live Activity
        let isTapEnabled = reminderManager.isCityTapEnabled
        #else
        let isTapEnabled = false
        #endif

        CityRow(
            entry: entry,
            isRemovable: removable,
            isSelected: isSelected,
            // Тап активен только если Live Activity реально активна
            isTapEnabled: isTapEnabled,
            onTap: {
                // Тоггл выбора города: повторный тап снимает выбор (только в превью)
                Task { @MainActor in
                    if reminderManager.selectedCityIdentifier == entry.id {
                        reminderManager.clearSelectedCity()
                    } else {
                        await reminderManager.selectCity(name: entry.name, identifier: entry.id)
                    }
                }
            },
            onRemove: {
                removeCity(entry.id)
            }
        )
    }

    // Включать ли тап по плиткам городов (оставлено для возможного будущего использования)
    private var isCityTapEnabled: Bool {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            if let r = ReminderManager.shared.currentReminder {
                return r.date != nil && r.liveActivityEnabled
            }
        }
        return false
        #else
        return false
        #endif
    }
}

// MARK: - Cities selection helpers
extension SettingsView {
    private var localCityIdentifier: String {
        TimeZone.current.identifier
    }

    private var themeCycleTitle: String {
        switch colorSchemePreference {
        case "light": return "Light"
        case "dark": return "Dark"
        default: return "System"
        }
    }

    private var themeCycleIcon: String {
        switch colorSchemePreference {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        default: return "circle.lefthalf.filled"
        }
    }

    private var themeCycleAccessibilityLabel: String {
        "Color scheme: \(themeCycleTitle). Double-tap to switch."
    }

#if os(macOS)
    private var orientationIsPortrait: Bool {
        windowOrientationPreference == "portrait"
    }

    private var orientationTitle: String {
        orientationIsPortrait ? "Portrait" : "Landscape"
    }

    private var orientationIcon: String {
        orientationIsPortrait ? "rectangle.portrait" : "rectangle"
    }

    private var orientationAccessibilityLabel: String {
        "Window orientation: \(orientationIsPortrait ? "portrait" : "landscape")"
    }
#endif

    @ViewBuilder
    private var themeControls: some View {
        HStack(spacing: 16) {
            ColorSchemeButton(
                title: themeCycleTitle,
                systemImage: themeCycleIcon,
                isSelected: true,
                colorScheme: colorScheme,
                accessibilityLabel: themeCycleAccessibilityLabel,
                action: {
                    advanceColorScheme()
                }
            )

            ColorSchemeButton(
                title: use12HourFormat ? "12h" : "24h",
                systemImage: "clock",
                isSelected: false,
                colorScheme: colorScheme,
                accessibilityLabel: "Toggle 12/24 hour format",
                action: {
                    use12HourFormat.toggle()
                    reloadWidgets()
                }
            )

            ColorSchemeButton(
                title: viewMode == "clock" ? "Clock" : "Alt",
                systemImage: viewMode == "clock" ? "stopwatch" : "square.grid.2x2",
                isSelected: false,
                colorScheme: colorScheme,
                accessibilityLabel: "Switch view mode",
                action: {
                    viewMode = viewMode == "clock" ? "alternative" : "clock"
                }
            )

            orientationButton

            PremiumAccessButton(
                isUnlocked: premiumUnlocked,
                isProcessing: storeManager.isPurchasing,
                colorScheme: colorScheme,
                priceText: storeManager.priceText,
                onPurchase: { Task { await attemptPurchase() } },
                onRestore: { Task { await attemptRestore() } }
            )
        }
    }

    @ViewBuilder
    private var orientationButton: some View {
#if os(macOS)
        ColorSchemeButton(
            title: orientationTitle,
            systemImage: orientationIcon,
            isSelected: false,
            colorScheme: colorScheme,
            accessibilityLabel: orientationAccessibilityLabel,
            action: {
                windowOrientationPreference = orientationIsPortrait ? "landscape" : "portrait"
            }
        )
#else
        EmptyView()
#endif
    }

    private func advanceColorScheme() {
        switch colorSchemePreference {
        case "system":
            colorSchemePreference = "light"
        case "light":
            colorSchemePreference = "dark"
        default:
            colorSchemePreference = "system"
        }
        reloadWidgets()
    }

    private func initializeColorSchemeIfNeeded() {
        // Если значение еще не установлено, записываем значение по умолчанию
        if SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) == nil {
            SharedUserDefaults.shared.set(colorSchemePreference, forKey: SharedUserDefaults.colorSchemeKey)
            SharedUserDefaults.shared.synchronize()
        }
    }

    private func loadSelection() {
        var identifiers = selectedCityIdentifiers
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty && !hasSeededDefaults {
            let defaults = WorldCity.initialSelectionIdentifiers()
            identifiers = defaults
            selectedCityIdentifiers = defaults.joined(separator: ",")
            hasSeededDefaults = true
        } else {
            let ensured = WorldCity.ensureLocalIdentifier(in: identifiers)
            if ensured != identifiers {
                identifiers = ensured
                selectedCityIdentifiers = ensured.joined(separator: ",")
            }
            if !identifiers.isEmpty {
                hasSeededDefaults = true
            }
        }

        let newSet = Set(identifiers)
        if newSet != selectedIds {
            selectedIds = newSet
        }
        
        // Обновляем список городов
        updateSelectedEntries()
    }
    
    private func updateSelectedEntries() {
        selectedEntries = selectedIds.compactMap { id -> TimeZoneDirectory.Entry? in
            let name = TimeZoneDirectory.displayName(forIdentifier: id)
            let offset = TimeZoneDirectory.gmtOffsetString(for: id)
            return TimeZoneDirectory.Entry(id: id, name: name, gmtOffset: offset)
        }
        .sorted { lhs, rhs in
            if lhs.id == localCityIdentifier { return true }
            if rhs.id == localCityIdentifier { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func persistSelection() {
        if !selectedIds.contains(localCityIdentifier) {
            selectedIds.insert(localCityIdentifier)
        }

        let validIds = selectedIds.filter { TimeZone(identifier: $0) != nil }
        let others = validIds
            .filter { $0 != localCityIdentifier }
            .sorted {
                TimeZoneDirectory.displayName(forIdentifier: $0)
                    .localizedCaseInsensitiveCompare(TimeZoneDirectory.displayName(forIdentifier: $1)) == .orderedAscending
            }

        var ordered: [String] = []
        if TimeZone(identifier: localCityIdentifier) != nil {
            ordered.append(localCityIdentifier)
        }
        ordered.append(contentsOf: others)

        let sanitized = Set(ordered)
        if sanitized != selectedIds {
            selectedIds = sanitized
            return
        }

        selectedCityIdentifiers = ordered.joined(separator: ",")
        if !ordered.isEmpty {
            hasSeededDefaults = true
        }
        updateSelectedEntries()
        reloadWidgets()
    }

    private func attemptPurchase() async {
        do {
            let result = try await storeManager.purchasePremium()
            switch result {
            case .success:
                purchaseAlert = PurchaseAlert(title: "Premium unlocked", message: "Thank you for supporting ClockW3.")
            case .pending:
                purchaseAlert = PurchaseAlert(title: "Purchase pending", message: "Your purchase is pending approval. We'll unlock premium once it completes.")
            case .cancelled:
                break
            }
        } catch {
            purchaseAlert = PurchaseAlert(title: "Purchase failed", message: error.localizedDescription)
        }
    }

    private func attemptRestore() async {
        do {
            try await storeManager.restorePurchases()
            if premiumUnlocked {
                purchaseAlert = PurchaseAlert(title: "Premium restored", message: "Your premium access is active on this device.")
            } else {
                purchaseAlert = PurchaseAlert(title: "No purchases found", message: "We couldn't find an active premium purchase for this Apple ID.")
            }
        } catch {
            purchaseAlert = PurchaseAlert(title: "Restore failed", message: error.localizedDescription)
        }
    }

    private func removeCity(_ identifier: String) {
       guard identifier != localCityIdentifier else { return }
        selectedIds.remove(identifier)
        updateSelectedEntries()
    }

    private var designedByFooter: some View {
        HStack(spacing: 6) {
            Text("⊗")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.primary)

            Text("Designed by Exrector")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary)
                .kerning(1.5)

            Text("⊕")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.primary)
        }
    }
}

private struct ReminderRow: View {
    let reminder: ClockReminder
    let isPreview: Bool
    let use12HourFormat: Bool
    let onModeChange: ((Bool) -> Void)?
    let onLiveActivityToggle: ((Bool) -> Void)?
    let onTimeSensitiveToggle: ((Bool) -> Void)?
    let onEdit: (() -> Void)?
    let onRemove: (() -> Void)?
    let onConfirm: (() -> Void)?

    @State private var isDailyMode: Bool
#if os(iOS)
    @State private var isLiveActivityEnabled: Bool
    @State private var isTimeSensitiveEnabled: Bool
#endif
    @State private var isConfirming = false
    @Environment(\.colorScheme) private var colorScheme

    init(
        reminder: ClockReminder,
        isPreview: Bool,
        use12HourFormat: Bool,
        onModeChange: ((Bool) -> Void)?,
        onLiveActivityToggle: ((Bool) -> Void)? = nil,
        onTimeSensitiveToggle: ((Bool) -> Void)? = nil,
        onEdit: (() -> Void)?,
        onRemove: (() -> Void)?,
        onConfirm: (() -> Void)?
    ) {
        self.reminder = reminder
        self.isPreview = isPreview
        self.use12HourFormat = use12HourFormat
        self.onModeChange = onModeChange
        self.onLiveActivityToggle = onLiveActivityToggle
        self.onTimeSensitiveToggle = onTimeSensitiveToggle
        self.onEdit = onEdit
        self.onRemove = onRemove
        self.onConfirm = onConfirm
        _isDailyMode = State(initialValue: reminder.isDaily)
#if os(iOS)
        _isLiveActivityEnabled = State(initialValue: reminder.liveActivityEnabled)
        _isTimeSensitiveEnabled = State(initialValue: reminder.isTimeSensitive)
#endif
    }

    private var isPastSelection: Bool {
#if os(iOS)
        let now = Date()
        if isPreview {
            if reminder.isDaily {
                let cal = Calendar.current
                let nowHour = cal.component(.hour, from: now)
                let nowMinute = cal.component(.minute, from: now)
                if reminder.hour < nowHour { return true }
                if reminder.hour == nowHour && reminder.minute < nowMinute { return true }
                return false
            } else if let d = reminder.date {
                return d < now
            }
        }
#endif
        return false
    }

    var body: some View {
        ZStack {
            // Раскладка элементов строки
            HStack {
                let borderColor: Color = colorScheme == .light ? .black : .white

                leftControls(borderColor: borderColor)

                Spacer()

                statusStack

                trailingActionButton
            }
            // Центр - кнопка редактирования времени поверх, чтобы тап гарантированно срабатывал
            editTimeButton
        }
#if os(macOS)
        .padding(.vertical, 6)
#else
        .padding(.vertical, 10)
#endif
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        .onChange(of: reminder.isDaily) { _, newValue in
            if newValue != isDailyMode {
                isDailyMode = newValue
            }
        }
#if os(iOS)
        .onChange(of: reminder.liveActivityEnabled) { _, newValue in
            if newValue != isLiveActivityEnabled {
                isLiveActivityEnabled = newValue
            }
        }
        .onChange(of: reminder.isTimeSensitive) { _, newValue in
            if newValue != isTimeSensitiveEnabled {
                isTimeSensitiveEnabled = newValue
            }
        }
#endif
    }

    // MARK: - Factored subviews to help the compiler

    private var editTimeButton: some View {
        Button {
            // Редактирование доступно только для временного напоминания
            if isPreview {
                onEdit?()
            }
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Text(reminder.formattedTime(use12Hour: use12HourFormat))
                        .monospacedDigit()
                        .font(.headline)
                        .foregroundColor(isPreview ? Color.primary : Color.red)
                    if use12HourFormat {
                        let displayHour = reminder.hour % 12 == 0 ? 12 : reminder.hour % 12
                        let ampm = reminder.hour < 12 ? "AM" : "PM"
                        Text(ampm)
                            .monospacedDigit()
                            .font(.headline)
                            .foregroundColor(isPreview ? Color.primary : Color.red)
                    }
                }
                .lineLimit(1)
                // Всегда показываем строку даты под временем.
                // Для one-time используем дату напоминания.
                // Для daily вычисляем ближайшую дату срабатывания по времени.
                let dateToShow: Date? = {
                    if isDailyMode {
                        return ClockReminder.nextTriggerDate(hour: reminder.hour, minute: reminder.minute, from: Date())
                    } else {
                        return reminder.date
                    }
                }()
                if let d = dateToShow {
                    Text(d, format: Date.FormatStyle().day().month(.wide).year())
                        .font(.caption2)
                        .foregroundColor(isPreview ? (isPastSelection ? Color.red : Color.primary) : Color.red)
                }
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        // Не используем disabled, чтобы не делать текст тусклым; действие и так срабатывает только в превью
        .accessibilityLabel("Edit reminder time")
    }

    @ViewBuilder
    private func leftControls(borderColor: Color) -> some View {

        HStack(spacing: 12) {
            if let onModeChange = onModeChange {
                repeatModeButton(borderColor: borderColor, onModeChange: onModeChange)
            }
#if os(iOS)
            if let onLiveActivityToggle = onLiveActivityToggle {
                liveActivityButton(borderColor: borderColor, onLiveActivityToggle: onLiveActivityToggle)
            }
            if let onTimeSensitiveToggle = onTimeSensitiveToggle {
                timeSensitiveButton(borderColor: borderColor, onTimeSensitiveToggle: onTimeSensitiveToggle)
            }
#endif
        }
    }

    private func repeatModeButton(borderColor: Color, onModeChange: @escaping (Bool) -> Void) -> some View {
        Button {
            // Доступно только для временного напоминания
            guard isPreview else { return }
#if os(iOS)
            guard !isTimeSensitiveEnabled else { return }
#endif
            isDailyMode.toggle()
            onModeChange(isDailyMode)
#if os(iOS)
            if isDailyMode && isLiveActivityEnabled {
                isLiveActivityEnabled = false
                onLiveActivityToggle?(false)
            }
#endif
        } label: {
            let fillColor: Color = isDailyMode
                ? (colorScheme == .light ? .black : .white)
                : .clear
            Circle()
                .fill(fillColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: isDailyMode ? "infinity" : "1.circle.fill")
                        .font(.system(size: isDailyMode ? 10 : 9, weight: .semibold))
                        .foregroundStyle(isDailyMode ? (colorScheme == .light ? .white : .black) : borderColor)
                )
                .shadow(color: isDailyMode ? borderColor.opacity(0.25) : .clear, radius: 3)
                .contentShape(Circle())
#if os(iOS)
                .opacity(isTimeSensitiveEnabled || !isPreview ? 0.3 : 1.0)
#else
                .opacity(!isPreview ? 0.3 : 1.0)
#endif
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
#if os(iOS)
        .disabled(isTimeSensitiveEnabled || !isPreview)
#else
        .disabled(!isPreview)
#endif
        .accessibilityLabel("Toggle reminder repeat mode")
    }

#if os(iOS)
    private func liveActivityButton(borderColor: Color, onLiveActivityToggle: @escaping (Bool) -> Void) -> some View {
        Button {
            // Доступно только для временного напоминания
            guard isPreview else { return }
            // Переключатель LA доступен только для one-time
            guard !isDailyMode else { return }
            // Ограничение 24 часа: не даём включать LA, если дата слишком далека
            if ReminderManager.shared.isBeyond24Hours(reminder.date) { return }
            isLiveActivityEnabled.toggle()
            onLiveActivityToggle(isLiveActivityEnabled)
        } label: {
            Circle()
                .fill(isLiveActivityEnabled ? (colorScheme == .light ? .black : .white) : .clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isLiveActivityEnabled ? (colorScheme == .light ? .white : .black) : borderColor)
                )
                .shadow(color: isLiveActivityEnabled ? borderColor.opacity(0.25) : .clear, radius: 3)
                // Если daily, подтверждённое или >24h — затемняем и блокируем визуально
                .opacity(((isDailyMode || !isPreview) || ReminderManager.shared.isBeyond24Hours(reminder.date)) ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .disabled(!isPreview || ReminderManager.shared.isBeyond24Hours(reminder.date))
        .accessibilityLabel("Toggle Live Activity")
    }

    private func timeSensitiveButton(borderColor: Color, onTimeSensitiveToggle: @escaping (Bool) -> Void) -> some View {
        Button {
            // Доступно только для временного напоминания
            guard isPreview else { return }
            isTimeSensitiveEnabled.toggle()
            onTimeSensitiveToggle(isTimeSensitiveEnabled)
            if isTimeSensitiveEnabled && isDailyMode {
                isDailyMode = false
                onModeChange?(false)
            }
        } label: {
            Circle()
                .fill(isTimeSensitiveEnabled ? .red : .clear)
                .frame(width: 20, height: 20)
                .overlay {
                    Circle()
                        .stroke(isTimeSensitiveEnabled ? .red : borderColor, lineWidth: 1.5)
                }
                .overlay {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isTimeSensitiveEnabled ? .white : borderColor)
                }
                .shadow(color: isTimeSensitiveEnabled ? .red.opacity(0.4) : .clear, radius: 3)
                .opacity(!isPreview ? 0.3 : 1.0)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .disabled(!isPreview)
        .accessibilityLabel("Toggle Time-Sensitive Alert")
    }
#endif

    @ViewBuilder
    private var statusStack: some View {
        VStack(alignment: .center, spacing: 2) {
#if os(iOS)
            // Line 1: repeat mode (always visible)
            Text(isDailyMode ? "Every day" : "One time")
                .font(.caption2)
                .foregroundStyle(isPastSelection ? .red : .primary)
                .multilineTextAlignment(.center)

            // Line 2: Live + MAX24 hint (if >24h)
            if onLiveActivityToggle != nil {
                if ReminderManager.shared.isBeyond24Hours(reminder.date) {
                    HStack(spacing: 4) {
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                        Text("MAX24")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                } else if isLiveActivityEnabled {
                    HStack(spacing: 2) {
                        Text("Live")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                } else {
                    Text("Live")
                        .font(.caption2)
                        .foregroundStyle(.clear)
                }
            } else {
                Text(" ")
                    .font(.caption2)
                    .foregroundStyle(.clear)
            }

            // Line 3: Time-Sensitive state (keeps space when unavailable)
            if onTimeSensitiveToggle != nil {
                Text("Time-Sensitive")
                    .font(.caption2)
                    .foregroundStyle(isTimeSensitiveEnabled ? .red : .clear)
            } else {
                Text(" ")
                    .font(.caption2)
                    .foregroundStyle(.clear)
            }
#else
            // Maintain three lines layout on macOS
            Text(" ")
                .font(.caption2)
                .foregroundStyle(.clear)

            Text(isDailyMode ? "Every day" : "One time")
                .font(.caption2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(" ")
                .font(.caption2)
                .foregroundStyle(.clear)
#endif
        }
    }

    @ViewBuilder
    private var trailingActionButton: some View {
        if isPreview, let onConfirm = onConfirm {
            Button {
                guard !isConfirming else { return }
                isConfirming = true
                onConfirm()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isConfirming = false
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .disabled(isConfirming || isPastSelection)
            .accessibilityLabel("Confirm reminder")
        } else if let onRemove = onRemove {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove reminder")
        }
    }
}

private struct PurchaseAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PremiumAccessButton: View {
    let isUnlocked: Bool
    let isProcessing: Bool
    let colorScheme: ColorScheme
    let priceText: String?
    let onPurchase: () -> Void
    let onRestore: () -> Void

    var body: some View {
        Button(action: primaryAction) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(circleFill)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(circleBorder, lineWidth: 2)
                        )
                        .shadow(color: shadowColor, radius: 3)

                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(progressTint)
                    } else {
                        Image(systemName: isUnlocked ? "heart.fill" : "lock.fill")
                            .font(.title2)
                            .foregroundColor(iconColor)
                    }
                }

                Text(labelText)
                    .font(.caption)
                    .foregroundStyle(labelColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .contextMenu {
            if !isUnlocked {
                Button("Unlock Premium", action: onPurchase)
            }
            Button("Restore Purchases", action: onRestore)
        }
        .accessibilityLabel(isUnlocked ? "Premium unlocked" : "Unlock premium access")
    }

    private func primaryAction() {
        if isUnlocked {
            onRestore()
        } else {
            onPurchase()
        }
    }

    private var circleFill: Color { Color.primary.opacity(colorScheme == .light ? 0.05 : 0.08) }

    private var circleBorder: Color { colorScheme == .light ? .black.opacity(0.6) : .white.opacity(0.7) }

    private var shadowColor: Color { Color.primary.opacity(0.1) }

    private var iconColor: Color {
        if isUnlocked { return .red }
        return colorScheme == .light ? .black : .white
    }

    private var progressTint: Color { colorScheme == .light ? .black : .white }

    private var labelColor: Color { colorScheme == .light ? .black : .white }

    private var labelText: String {
        if isUnlocked {
            return "Premium"
        }
        return priceText ?? "Unlock"
    }
}

private struct CityRow: View {
    let entry: TimeZoneDirectory.Entry
    let isRemovable: Bool
    let isSelected: Bool
    let isTapEnabled: Bool
    let onTap: (() -> Void)?
    let onRemove: () -> Void

    init(entry: TimeZoneDirectory.Entry, isRemovable: Bool, isSelected: Bool = false, isTapEnabled: Bool = false, onTap: (() -> Void)? = nil, onRemove: @escaping () -> Void) {
        self.entry = entry
        self.isRemovable = isRemovable
        self.isSelected = isSelected
        self.isTapEnabled = isTapEnabled
        self.onTap = onTap
        self.onRemove = onRemove
    }

    var body: some View {
        ZStack {
            // Центральный текст - строго по центру
            VStack(alignment: .center, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .red : .primary)
                Text(entry.gmtOffset)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .opacity(isTapEnabled ? 1.0 : 0.7)

            // Кнопка справа поверх
            HStack {
                Spacer()
                
                if isRemovable {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(entry.name)")
                } else {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(entry.name) pinned")
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? Color.red : Color.primary, lineWidth: 1)
        )
        .frame(maxWidth: 360)
        #if os(iOS)
        .overlay(
            GeometryReader { geo in
                // Зона тапа, которая исключает правую область с кнопкой удаления.
                let deleteTouchWidth: CGFloat = 44
                let horizontalPadding: CGFloat = 16
                let tappableWidth = max(0, geo.size.width - (deleteTouchWidth + horizontalPadding))
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: tappableWidth, height: geo.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard isTapEnabled else { return }
                            onTap?()
                        }
                    Spacer(minLength: deleteTouchWidth + horizontalPadding)
                }
            }
        )
        #endif
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#if canImport(WidgetKit)
private extension SettingsView {
    func reloadWidgets() {
        // Принудительно синхронизируем
        SharedUserDefaults.shared.synchronize()

        // Перезагружаем виджеты
        WidgetCenter.shared.reloadAllTimelines()

        // Также попробуем перезагрузить конкретные kinds
        WidgetCenter.shared.reloadTimelines(ofKind: "MOWWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "MOWSmallWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "MOWMediumWidget")
        
        // Дополнительная синхронизация для macOS
        #if os(macOS)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
#else
private extension SettingsView {
    func reloadWidgets() {}
}
#endif

// MARK: - Time Zone Picker
struct TimeZoneSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @Binding var selection: Set<String>
    let onConfirm: (Set<String>) -> Void

    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var attemptedCityId: String?

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        let currentTime = Date()
        let baseEntries = searchText.isEmpty ? entries : entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }

        return baseEntries.sorted { lhs, rhs in
            guard let lhsTZ = TimeZone(identifier: lhs.id),
                  let rhsTZ = TimeZone(identifier: rhs.id) else {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            var lhsCal = Calendar.current
            lhsCal.timeZone = lhsTZ
            let lhsHour = lhsCal.component(.hour, from: currentTime)
            let lhsMinute = lhsCal.component(.minute, from: currentTime)

            var rhsCal = Calendar.current
            rhsCal.timeZone = rhsTZ
            let rhsHour = rhsCal.component(.hour, from: currentTime)
            let rhsMinute = rhsCal.component(.minute, from: currentTime)

            let lhsTime = lhsHour * 60 + lhsMinute
            let rhsTime = rhsHour * 60 + rhsMinute

            return lhsTime < rhsTime
        }
    }

    var body: some View {
        List(filteredEntries) { entry in
            Button {
                toggle(entry.id)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.name)
                        Text(entry.gmtOffset)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selection.contains(entry.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden) // show system sheet card rounded corners
        .background(Color.clear)
        .navigationTitle("Select Cities")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    selection.insert(localCityIdentifier)
                    onConfirm(selection)
                    dismiss()
                }
            }
#if os(iOS)
            ToolbarItem(placement: .bottomBar) {
                Button("Reset") {
                    selection = Set(WorldCity.initialSelectionIdentifiers())
                    selection.insert(localCityIdentifier)
                }
            }
#endif
        }
        .alert("Computer says no", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(conflictMessage)
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            // Проверяем конфликт ПЕРЕД добавлением
            var testSelection = selection
            testSelection.insert(identifier)
            let testCities = WorldCity.cities(from: Array(testSelection))

            let result = CityOrbitDistribution.distributeCities(
                cities: testCities,
                currentTime: Date()
            )

            if result.hasConflicts {
                attemptedCityId = identifier
                conflictMessage = result.conflictMessage ?? "This city conflicts with existing cities"
                showConflictAlert = true
            } else {
                selection.insert(identifier)
            }
        }
    }

    private var localCityIdentifier: String {
        TimeZone.current.identifier
    }
}

// MARK: - Time Zone Selection Inline View (for macOS)
struct TimeZoneSelectionInlineView: View {
    @Binding var selection: Set<String>
    let onChanged: () -> Void
    @State private var searchText = ""

    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var attemptedCityId: String?

    private let entries = TimeZoneDirectory.allEntries()

    private var filteredEntries: [TimeZoneDirectory.Entry] {
        let currentTime = Date()
        let baseEntries = searchText.isEmpty ? entries : entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(searchText) ||
            entry.gmtOffset.localizedCaseInsensitiveContains(searchText)
        }

        return baseEntries.sorted { lhs, rhs in
            guard let lhsTZ = TimeZone(identifier: lhs.id),
                  let rhsTZ = TimeZone(identifier: rhs.id) else {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            var lhsCal = Calendar.current
            lhsCal.timeZone = lhsTZ
            let lhsHour = lhsCal.component(.hour, from: currentTime)
            let lhsMinute = lhsCal.component(.minute, from: currentTime)

            var rhsCal = Calendar.current
            rhsCal.timeZone = rhsTZ
            let rhsHour = rhsCal.component(.hour, from: currentTime)
            let rhsMinute = rhsCal.component(.minute, from: currentTime)

            let lhsTime = lhsHour * 60 + lhsMinute
            let rhsTime = rhsHour * 60 + rhsMinute

            return lhsTime < rhsTime
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search cities...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button("Reset") {
                    selection = Set(WorldCity.initialSelectionIdentifiers())
                    selection.insert(localCityIdentifier)
                    onChanged()
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEntries) { entry in
                        Button {
                            toggle(entry.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.body)
                                    Text(entry.gmtOffset)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selection.contains(entry.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .alert("Computer says no", isPresented: $showConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(conflictMessage)
        }
    }

    private func toggle(_ identifier: String) {
        if selection.contains(identifier) {
            if identifier == localCityIdentifier { return }
            selection.remove(identifier)
        } else {
            // Проверяем конфликт ПЕРЕД добавлением
            var testSelection = selection
            testSelection.insert(identifier)
            let testCities = WorldCity.cities(from: Array(testSelection))

            let result = CityOrbitDistribution.distributeCities(
                cities: testCities,
                currentTime: Date()
            )

            if result.hasConflicts {
                attemptedCityId = identifier
                conflictMessage = result.conflictMessage ?? "This city conflicts with existing cities"
                showConflictAlert = true
            } else {
                selection.insert(identifier)
            }
        }
        onChanged()
    }

    private var localCityIdentifier: String {
        TimeZone.current.identifier
    }
}

// MARK: - Edit Reminder View
private struct EditReminderView: View {
    let reminder: ClockReminder
    let onSave: (Int, Int, Date?) -> Void

    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var selectedDay: Int
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(reminder: ClockReminder, onSave: @escaping (Int, Int, Date?) -> Void) {
        self.reminder = reminder
        self.onSave = onSave
        self._selectedHour = State(initialValue: reminder.hour)
        self._selectedMinute = State(initialValue: reminder.minute)

        // Если у напоминания есть дата, используем её, иначе вычисляем следующую дату
        let initialDate = reminder.date ?? ClockReminder.nextTriggerDate(hour: reminder.hour, minute: reminder.minute, from: Date())
        let calendar = Calendar.current
        self._selectedDay = State(initialValue: calendar.component(.day, from: initialDate))
        self._selectedMonth = State(initialValue: calendar.component(.month, from: initialDate))
        self._selectedYear = State(initialValue: calendar.component(.year, from: initialDate))
    }

    private var selectedDate: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay
        components.hour = selectedHour
        components.minute = selectedMinute
        components.second = 0
        return calendar.date(from: components) ?? Date()
    }

    private var currentDate: Date { Date() }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: currentDate)
        return Array(currentYear...(currentYear + 10))
    }

    private func availableDays(for month: Int, year: Int) -> [Int] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }
        return Array(range)
    }

    var body: some View {
        VStack(spacing: 0) {
#if os(macOS)
            // Header (macOS)
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Edit Reminder")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    // Передаём дату только для one-time напоминаний
                    if reminder.isDaily {
                        onSave(selectedHour, selectedMinute, nil)
                    } else {
                        onSave(selectedHour, selectedMinute, selectedDate)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .fontWeight(.semibold)
                .disabled(!reminder.isDaily && selectedDate < Date())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color("ClockBackground"))
#endif

            // Preview
            VStack(spacing: 6) {
                Text(String(format: "%02d:%02d", selectedHour, selectedMinute))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                if !reminder.isDaily {
                    // Date below time in format like 31 April 2025 (localized)
                    Text(selectedDate, format: Date.FormatStyle().day().month(.wide).year())
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
#if os(iOS)
            .background(Color.clear)
#else
            .background(Color("ClockBackground"))
#endif

            Divider()

            // Pickers
            VStack(spacing: 0) {
                if reminder.isDaily {
                    // Только время для daily
                    HStack(spacing: 4) {
                        pickerColumn(title: "Hour", selection: $selectedHour, range: 0..<24)
                        Text(":").font(.largeTitle).foregroundStyle(.secondary)
                        pickerColumn(title: "Min", selection: $selectedMinute, range: 0..<60)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    // Дата + время для one-time
                    HStack(spacing: 4) {
                        dayPickerColumn
                        monthPickerColumn
                        yearPickerColumn
                        Divider().frame(height: 100)
                        pickerColumn(title: "Hour", selection: $selectedHour, range: 0..<24)
                        Text(":").font(.largeTitle).foregroundStyle(.secondary)
                        pickerColumn(title: "Min", selection: $selectedMinute, range: 0..<60)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .frame(maxWidth: .infinity)
#if os(iOS)
            .background(Color.clear)
#else
            .background(Color("ClockBackground"))
#endif
            .contentShape(Rectangle())
#if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
            )
#endif

            #if os(iOS)
            // Notice about Live Activity limit (iOS only)
            Text("Changing date beyond 24 hours will deactivate Live Activity.")
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            #endif
        }
#if os(iOS)
        // Let the system sheet card (with rounded corners) show through
        .background(Color.clear)
#else
        .background(Color("ClockBackground"))
#endif
#if os(macOS)
        .frame(width: 400, height: 300)
#else
        .frame(maxWidth: .infinity)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if reminder.isDaily {
                        onSave(selectedHour, selectedMinute, nil)
                    } else {
                        onSave(selectedHour, selectedMinute, selectedDate)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!reminder.isDaily && selectedDate < Date())
            }
        }
#endif
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func pickerColumn(title: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .tag(value)
                        .font(.system(.title3, design: .rounded))
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
            .frame(width: 60, height: 100)
            .clipped()
#else
            .pickerStyle(.menu)
            .frame(width: 60, height: 30)
#endif
        }
#if os(iOS)
        .background(
            Color.clear
                .frame(width: 100, height: 220)
                .contentShape(Rectangle())
        )
#endif
    }

    @ViewBuilder
    private var dayPickerColumn: some View {
        VStack(spacing: 4) {
            Text("Day")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedDay) {
                ForEach(availableDays(for: selectedMonth, year: selectedYear), id: \.self) { day in
                    Text(String(format: "%02d", day))
                        .tag(day)
                        .font(.system(.title3, design: .rounded))
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
            .frame(width: 60, height: 100)
            .clipped()
#else
            .pickerStyle(.menu)
            .frame(width: 60, height: 30)
#endif
        }
#if os(iOS)
        .background(
            Color.clear
                .frame(width: 100, height: 220)
                .contentShape(Rectangle())
        )
#endif
    }

    @ViewBuilder
    private var monthPickerColumn: some View {
        VStack(spacing: 4) {
            Text("Month")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(String(format: "%02d", month))
                        .tag(month)
                        .font(.system(.title3, design: .rounded))
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
            .frame(width: 60, height: 100)
            .clipped()
#else
            .pickerStyle(.menu)
            .frame(width: 60, height: 30)
#endif
            .onChange(of: selectedMonth) { _, _ in
                // Корректируем день если он выходит за пределы нового месяца
                let availableDays = availableDays(for: selectedMonth, year: selectedYear)
                if !availableDays.contains(selectedDay) {
                    selectedDay = availableDays.last ?? 1
                }
            }
        }
#if os(iOS)
        .background(
            Color.clear
                .frame(width: 100, height: 220)
                .contentShape(Rectangle())
        )
#endif
    }

    @ViewBuilder
    private var yearPickerColumn: some View {
        VStack(spacing: 4) {
            Text("Year")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(format: "%04d", year))
                        .tag(year)
                        .font(.system(.title3, design: .rounded))
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
            .frame(width: 70, height: 100)
            .clipped()
#else
            .pickerStyle(.menu)
            .frame(width: 70, height: 30)
#endif
            .onChange(of: selectedYear) { _, _ in
                // Корректируем день если он выходит за пределы (високосный год)
                let availableDays = availableDays(for: selectedMonth, year: selectedYear)
                if !availableDays.contains(selectedDay) {
                    selectedDay = availableDays.last ?? 1
                }
            }
        }
#if os(iOS)
        .background(
            Color.clear
                .frame(width: 110, height: 220)
                .contentShape(Rectangle())
        )
#endif
    }

    private var headerBackgroundColor: Color {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var backgroundColor: Color {
#if os(macOS)
        Color(nsColor: .textBackgroundColor)
#else
        Color(uiColor: .systemBackground)
#endif
    }
}

// MARK: - Color Scheme Button
private struct ColorSchemeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let accessibilityLabel: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? (colorScheme == .light ? Color.black : Color.white) : Color.clear)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(colorScheme == .light ? Color.black : Color.white, lineWidth: 2)
                        )
                        .shadow(color: isSelected ? (colorScheme == .light ? Color.black.opacity(0.25) : Color.white.opacity(0.25)) : .clear, radius: 4)
                    
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(isSelected ? (colorScheme == .light ? .white : .black) : (colorScheme == .light ? .black : .white))
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(colorScheme == .light ? .black : .white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? "\(title) color scheme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview
#if DEBUG
struct SwiftUIClockApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
