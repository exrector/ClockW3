import Foundation
import Combine
import UserNotifications
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
#endif

// MARK: - Live Activity Preferences
private struct LiveActivityPreferences: Codable {
    var liveActivityEnabled: Bool
    var isTimeSensitive: Bool

    init(
        liveActivityEnabled: Bool = false,
        isTimeSensitive: Bool = false
    ) {
        self.liveActivityEnabled = liveActivityEnabled
        self.isTimeSensitive = isTimeSensitive
    }
}

// MARK: - Reminder Manager
/// Управляет единственным напоминанием циферблата
@MainActor
class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published var currentReminder: ClockReminder?

    // Временное хранение времени для неподтверждённого напоминания
    @Published var temporaryHour: Int?
    @Published var temporaryMinute: Int?
    @Published var temporaryDate: Date?
    @Published var temporaryIsDaily: Bool = false

    // MARK: City selection for Live Activity
    @Published var selectedCityIdentifier: String?
    @Published var selectedCityName: String?
    @Published var isCityTapEnabled: Bool = false

    // Preview-only toggles set from temporary reminder row (before confirmation)
    private var previewLiveActivityEnabled: Bool = false
    private var previewTimeSensitiveEnabled: Bool = false

    private let userDefaults = SharedUserDefaults.shared
    private let reminderKey = "clock_reminder"
    private let notificationIdentifier = "clock_reminder_notification"
    private let liveActivityPreferencesKey = "live_activity_preferences"
    private var updateTimer: Timer?
#if canImport(ActivityKit) && !os(macOS)
#endif

    private init() {
        loadReminder()
        // Если нет сохраненного напоминания, создаём временное время по умолчанию
        if currentReminder == nil {
            setDefaultTemporaryTime()
        }
#if canImport(ActivityKit) && !os(macOS)
        reconcileLiveActivityOnLaunch()
        startLiveActivityUpdateTimer()
#endif
        reevaluateCityTapEnabled()
    }
    
    private func setDefaultTemporaryTime() {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // Округляем ВВЕРХ к следующему кратному 15 минутам
        let roundedMinute = ((currentMinute / 15) + 1) * 15

        var hour = currentHour
        var minute = roundedMinute

        // Если минуты >= 60, переходим на следующий час
        if minute >= 60 {
            minute = 0
            hour = (hour + 1) % 24
        }

        temporaryHour = hour
        temporaryMinute = minute

        // Устанавливаем дату по умолчанию на сегодня/завтра
        temporaryDate = ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: now)
        temporaryIsDaily = false

        // Инициализируем превью-настройки из сохранённых предпочтений (один раз при старте цикла превью)
        let prefs = loadLiveActivityPreferences()
        previewLiveActivityEnabled = prefs.liveActivityEnabled
        previewTimeSensitiveEnabled = prefs.isTimeSensitive
    }

    /// Обновляет временное время (пока напоминание не подтверждено)
    func updateTemporaryTime(hour: Int, minute: Int, date: Date? = nil) {
        temporaryHour = hour
        temporaryMinute = minute
        if let date = date {
            temporaryDate = date
        } else if let currentDate = temporaryDate {
            // Обновляем время в текущей дате
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
            components.hour = hour
            components.minute = minute
            components.second = 0
            temporaryDate = calendar.date(from: components) ?? ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: Date())
        } else {
            // Если дата не установлена, вычисляем по умолчанию
            temporaryDate = ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: Date())
        }

        // Ограничение: если дата дальше чем 24 часа — отключаем Live Activity в превью
        if isBeyond24Hours(temporaryDate) {
            previewLiveActivityEnabled = false
            persistPreviewPreferences()
        }
    }

    /// Обновляет временный режим (ежедневный или одноразовый)
    func updateTemporaryMode(isDaily: Bool) {
        temporaryIsDaily = isDaily
        if isDaily {
            // Для daily Live Activity не используется — отключаем превью-переключатель
            previewLiveActivityEnabled = false
            persistPreviewPreferences()
        }
        reevaluateCityTapEnabled()
    }

    /// Подтверждает создание напоминания из временного времени
    func confirmTemporaryReminder() async {
        guard let hour = temporaryHour, let minute = temporaryMinute else { return }

        let now = Date()
        // Daily: дата = nil, LA отключена. One‑time: используем выбранную/авто дату, LA по превью и ограничению 24ч.
        let newReminder: ClockReminder = {
            if temporaryIsDaily {
                return ClockReminder(
                    id: UUID(),
                    hour: hour,
                    minute: minute,
                    date: nil,
                    isEnabled: true,
                    liveActivityEnabled: false,
                    alwaysLiveActivity: false,
                    isTimeSensitive: previewTimeSensitiveEnabled,
                    preserveExactMinute: true
                )
            } else {
                let nextDate = temporaryDate ?? ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: now)
                let autoEnableLA = previewLiveActivityEnabled && !isBeyond24Hours(nextDate)
                return ClockReminder(
                    id: UUID(),
                    hour: hour,
                    minute: minute,
                    date: nextDate,
                    isEnabled: true,
                    liveActivityEnabled: autoEnableLA,
                    alwaysLiveActivity: false,
                    isTimeSensitive: previewTimeSensitiveEnabled,
                    preserveExactMinute: true
                )
            }
        }()

        await setReminder(newReminder)

        // Очищаем временное время
        temporaryHour = nil
        temporaryMinute = nil
        temporaryDate = nil
        temporaryIsDaily = false
        // Не сбрасываем превью-настройки — сохраняем их как предпочтения пользователя
        persistPreviewPreferences()
    }

    // MARK: - Storage

    private func loadReminder() {
        guard let data = userDefaults.data(forKey: reminderKey),
              let reminder = try? JSONDecoder().decode(ClockReminder.self, from: data) else {
            currentReminder = nil
            return
        }
        
        // Если это one-time и его время уже прошло
        if let reminderDate = reminder.date, reminderDate < Date() {
            if reminder.liveActivityEnabled {
                // С LA — оставляем напоминание на окно DONE (до 2 минут), чтобы LA могла показать DONE
                let elapsed = Date().timeIntervalSince(reminderDate)
                if elapsed > 120 {
                    currentReminder = nil
                    userDefaults.removeObject(forKey: reminderKey)
                    return
                } else {
                    currentReminder = reminder
                    return
                }
            } else {
                // Без LA — удаляем немедленно
                currentReminder = nil
                userDefaults.removeObject(forKey: reminderKey)
                return
            }
        }
        
        currentReminder = reminder
    }

    private func saveReminder() {
        if let reminder = currentReminder,
           let data = try? JSONEncoder().encode(reminder) {
            userDefaults.set(data, forKey: reminderKey)
        } else {
            userDefaults.removeObject(forKey: reminderKey)
        }
    }

    private func saveLiveActivityPreferences(from reminder: ClockReminder) {
        let preferences = LiveActivityPreferences(
            liveActivityEnabled: reminder.liveActivityEnabled,
            isTimeSensitive: reminder.isTimeSensitive
        )
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: liveActivityPreferencesKey)
            userDefaults.synchronize()
            print("💾 Saved Live Activity preferences: liveActivityEnabled=\(preferences.liveActivityEnabled), timeSensitive=\(preferences.isTimeSensitive)")
        }
    }

    private func loadLiveActivityPreferences() -> LiveActivityPreferences {
        guard let data = userDefaults.data(forKey: liveActivityPreferencesKey),
              let preferences = try? JSONDecoder().decode(LiveActivityPreferences.self, from: data) else {
            print("📂 No saved Live Activity preferences, using defaults")
            return LiveActivityPreferences()
        }
        print("📂 Loaded Live Activity preferences: liveActivityEnabled=\(preferences.liveActivityEnabled), timeSensitive=\(preferences.isTimeSensitive)")
        return preferences
    }

    // MARK: - Notification Permissions

    /// Запрашивает разрешение на отправку уведомлений
    func requestPermission() async -> Bool {
        do {
            #if os(iOS)
            // Time Sensitive is controlled by entitlement, not by authorization options.
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            #else
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            #endif
            return granted
        } catch {
            return false
        }
    }


    // MARK: - Reminder Management

    /// Создаёт или обновляет напоминание
    func setReminder(_ reminder: ClockReminder) async {
        // Удаляем старое уведомление
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        // Применяем ограничение 24 часов для Live Activity у one-time
        var adjusted = reminder
        if isBeyond24Hours(adjusted.date) {
            adjusted.liveActivityEnabled = false
        }

        currentReminder = adjusted
        saveReminder()

        // Если текущее напоминание не подходит для Live Activity выбора города — очищаем выбор
        reevaluateCityTapEnabled()

        // Создаём новое уведомление если включено
        if adjusted.isEnabled {
            await scheduleNotification(for: adjusted)
        }

        await updateLiveActivityIntegration(for: adjusted)
    }

    /// Обновляет время существующего напоминания
    func updateReminderTime(hour: Int, minute: Int) async {
        guard var reminder = currentReminder else { return }

#if canImport(ActivityKit) && !os(macOS)
        // Любое ручное изменение — завершаем текущую LA (если была), чтобы начать чистый цикл
        if #available(iOS 16.1, *) {
            await endLiveActivity(reminderID: reminder.id)
        }
#endif

        // Если это one-time напоминание, пересчитываем дату
        let updatedDate = reminder.date != nil
            ? ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: Date())
            : nil

        reminder = ClockReminder(
            id: reminder.id,
            hour: hour,
            minute: minute,
            date: updatedDate,
            isEnabled: reminder.isEnabled,
            liveActivityEnabled: reminder.liveActivityEnabled,
            isTimeSensitive: reminder.isTimeSensitive,
            preserveExactMinute: true
        )
        await setReminder(reminder)
    }

    /// Обновляет режим повторения: ежедневно или один раз
    func updateReminderRepeat(isDaily: Bool, referenceDate: Date = Date()) async {
        guard var reminder = currentReminder else { return }
        guard reminder.isDaily != isDaily else { return }

#if canImport(ActivityKit) && !os(macOS)
        if #available(iOS 16.1, *) {
            await endLiveActivity(reminderID: reminder.id)
        }
#endif

        let nextDate = isDaily
            ? nil
            : ClockReminder.nextTriggerDate(hour: reminder.hour, minute: reminder.minute, from: referenceDate)

        // Если переключаемся на daily — Live Activity для текущего напоминания отключаем (она не используется для daily)
        let newLiveActivityEnabled = isDaily ? false : reminder.liveActivityEnabled

        reminder = ClockReminder(
            id: reminder.id,
            hour: reminder.hour,
            minute: reminder.minute,
            date: nextDate,
            isEnabled: reminder.isEnabled,
            liveActivityEnabled: newLiveActivityEnabled,
            isTimeSensitive: reminder.isTimeSensitive,
            preserveExactMinute: true
        )
        await setReminder(reminder)
    }

    /// Удаляет напоминание
    /// - Parameter endLiveActivity: завершить ли активную Live Activity немедленно (по умолчанию true).
    func deleteReminder(endLiveActivity: Bool = true) {
        let reminderID = currentReminder?.id
#if canImport(ActivityKit) && !os(macOS)
#endif
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        currentReminder = nil
        saveReminder()
        // Создаём временное время по умолчанию
        print("✨ Creating temporary time after deletion")
        setDefaultTemporaryTime()
        clearSelectedCity()
        reevaluateCityTapEnabled()

#if canImport(ActivityKit) && !os(macOS)
        if endLiveActivity, let reminderID, #available(iOS 16.1, *) {
            Task { await self.endLiveActivity(reminderID: reminderID) }
        }
#endif
    }

    /// Удаляет сработавшее одноразовое напоминание после окна DONE
    private func cleanupExpiredReminderIfNeeded(now: Date = Date()) {
        guard let reminder = currentReminder,
              let reminderDate = reminder.date else {
            return
        }

        if now >= reminderDate {
            print("🗑️ Auto-removing one-time reminder at trigger time")
            deleteReminder()
        }
    }

    /// Публичная очистка: если одноразовое напоминание уже сработало и LA отключена — удалить немедленно.
    func pruneExpiredReminderImmediatelyIfNeeded(now: Date = Date()) {
        guard let reminder = currentReminder, let reminderDate = reminder.date else { return }
        guard now >= reminderDate, reminder.liveActivityEnabled == false else { return }
        print("🗑️ Pruning expired reminder immediately due to notification (no LA)")
        deleteReminder()
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(for reminder: ClockReminder) async {
        let content = UNMutableNotificationContent()
        content.title = "THE M.O.W TIME"
        content.body = "Check the world time \(reminder.formattedTime)"

        #if os(iOS)
        if reminder.isTimeSensitive {
            // Time-Sensitive alert с максимальной громкостью
            content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
            content.interruptionLevel = .timeSensitive
        } else {
            content.sound = .default
        }
        #else
        content.sound = .default
        #endif

        content.categoryIdentifier = "CLOCK_REMINDER"

        let trigger: UNNotificationTrigger

        if let targetDate = reminder.date {
            // Однократное напоминание на конкретную дату
            let calendar = Calendar.current
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        } else {
            // Ежедневное повторяющееся напоминание
            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.minute

            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
        }
    }

    /// Обновляет флаг Live Activity
    func updateLiveActivityEnabled(isEnabled: Bool) async {
        guard var reminder = currentReminder else { return }
        // Запрещаем включать Live Activity у ежедневных напоминаний
        if reminder.isDaily && isEnabled {
            // Игнорируем попытку включить LA для daily
            return
        }
        // Ограничение 24 часа: не позволяем включить LA если дата слишком далека
        if isEnabled, isBeyond24Hours(reminder.date) {
            // Принудительно выключаем
            reminder.liveActivityEnabled = false
            await setReminder(reminder)
            return
        }
        guard reminder.liveActivityEnabled != isEnabled else { return }
        reminder.liveActivityEnabled = isEnabled
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOS 16.1, *) {
            if isEnabled == false {
                await endLiveActivity(reminderID: reminder.id)
            }
        }
#endif
        await setReminder(reminder)
    }

    // MARK: - Helpers
    /// Возвращает true если дата дальше чем через 24 часа от текущего момента
    func isBeyond24Hours(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return date.timeIntervalSince(Date()) > 24 * 60 * 60
    }

    /// Обновляет флаг Time-Sensitive Alert
    func updateTimeSensitiveEnabled(isEnabled: Bool) async {
        guard var reminder = currentReminder else { return }
        guard reminder.isTimeSensitive != isEnabled else { return }
        reminder.isTimeSensitive = isEnabled
        await setReminder(reminder)
    }

    // Always Live Activity removed

    // MARK: - Preview toggles (for temporary reminder before confirmation)
    func setPreviewLiveActivityEnabled(_ isEnabled: Bool) {
        previewLiveActivityEnabled = isEnabled
        persistPreviewPreferences()
        reevaluateCityTapEnabled()
    }

    // Always Live Activity removed

    func setPreviewTimeSensitiveEnabled(_ isEnabled: Bool) {
        previewTimeSensitiveEnabled = isEnabled
        persistPreviewPreferences()
    }

    private func persistPreviewPreferences() {
        let stub = ClockReminder(
            hour: 0,
            minute: 0,
            date: nil,
            isEnabled: false,
            liveActivityEnabled: previewLiveActivityEnabled,
            alwaysLiveActivity: false,
            isTimeSensitive: previewTimeSensitiveEnabled,
            preserveExactMinute: true
        )
        saveLiveActivityPreferences(from: stub)
    }

    // Expose preview preferences for UI defaults
    var lastPreviewLiveActivityEnabled: Bool { previewLiveActivityEnabled }
    var lastPreviewTimeSensitiveEnabled: Bool { previewTimeSensitiveEnabled }

    // MARK: - City selection API

    /// Пользователь выбрал город на плитке — обновляем Live Activity.
    func selectCity(name: String, identifier: String) async {
        // Выбор города разрешён только до подтверждения (в режиме превью)
        guard isCityTapEnabled else { return }
        selectedCityIdentifier = identifier
        // В Live Activity показываем ТОЛЬКО название города (без региона/прочего)
        selectedCityName = TimeZoneDirectory.cityName(forIdentifier: identifier)
        reevaluateCityTapEnabled()
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOS 16.1, *) {
            // После подтверждения города выбирать нельзя, поэтому currentReminder здесь всегда nil
        }
#endif
    }

    /// Сбрасывает выбранный город и обновляет Live Activity.
    func clearSelectedCity() {
        selectedCityIdentifier = nil
        selectedCityName = nil
        reevaluateCityTapEnabled()
    }

    private func reevaluateCityTapEnabled() {
        #if os(iOS)
        if #available(iOS 16.1, *) {
            // Правило: в превью тапы по городам доступны только когда переключатель LA включён.
            // После подтверждения напоминания — тапы всегда отключены.
            let inPreview = (currentReminder == nil) && (temporaryHour != nil) && (temporaryMinute != nil)
            isCityTapEnabled = inPreview && previewLiveActivityEnabled
        } else {
            isCityTapEnabled = false
        }
        #else
        isCityTapEnabled = false
        #endif
    }

    private func updateLiveActivityIntegration(for reminder: ClockReminder) async {
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOS 16.1, *) {
            await updateLiveActivity(for: reminder)
            await purgeExtraneousActivities(keeping: reminder.id)
        }
#endif
    }

#if canImport(ActivityKit) && !os(macOS)
    @available(iOS 16.1, *)
    private func reconcileLiveActivityOnLaunch() {
        Task { [weak self] in
            guard let self else { return }
            if let reminder = self.currentReminder {
                await self.updateLiveActivity(for: reminder)
                await self.purgeExtraneousActivities(keeping: reminder.id)
            } else {
                // Нет активного напоминания — завершаем все активности
                await self.terminateOrphanedActivities()
            }
        }
    }

    @available(iOS 16.1, *)
    private func startLiveActivityUpdateTimer() {
        // Обновляем Live Activity каждые 10 секунд для проверки статуса
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.reevaluateCityTapEnabled()
                if let reminder = self.currentReminder {
                    await self.updateLiveActivity(for: reminder)
                }
                self.cleanupExpiredReminderIfNeeded()
            }
        }
    }

    @available(iOS 16.1, *)
    private func terminateOrphanedActivities() async {
        let activities = Activity<ReminderLiveActivityAttributes>.activities
        for activity in activities {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        clearSelectedCity()
        reevaluateCityTapEnabled()
    }

    @available(iOS 16.1, *)
    private func purgeExtraneousActivities(keeping reminderID: UUID) async {
        let activities = Activity<ReminderLiveActivityAttributes>.activities
        for activity in activities where activity.attributes.reminderID != reminderID {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
        reevaluateCityTapEnabled()
    }

    @available(iOS 16.1, *)
    private func updateLiveActivity(for reminder: ClockReminder) async {
        // Live Activity показываем ТОЛЬКО для одноразовых напоминаний
        guard reminder.date != nil else {
            print("⏸️ Live Activity is only for one-time reminders")
            await endLiveActivity(reminderID: reminder.id)
            clearSelectedCity()
            reevaluateCityTapEnabled()
            return
        }

        guard reminder.liveActivityEnabled, reminder.isEnabled else {
            print("⏸️ Live Activity disabled or reminder disabled")
            await endLiveActivity(reminderID: reminder.id)
            clearSelectedCity()
            reevaluateCityTapEnabled()
            return
        }

        if #available(iOS 16.2, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("⏸️ Live Activities not authorized")
                return
            }
        }

        let scheduledDate = reminder.nextScheduledDate()
        let now = Date()

        let hasTriggered = scheduledDate <= now

        print("🔄 updateLiveActivity (one-time): scheduledDate=\(scheduledDate), now=\(now), hasTriggered=\(hasTriggered)")

        let contentState = ReminderLiveActivityAttributes.ContentState(
            endDate: scheduledDate,
            hasFinished: hasTriggered,
            selectedCityName: selectedCityName
        )

        if let existing = Activity<ReminderLiveActivityAttributes>.activities.first(where: { $0.attributes.reminderID == reminder.id }) {
            print("📝 Updating existing Live Activity with hasTriggered=\(hasTriggered)")
            if #available(iOS 16.2, *) {
                // Устанавливаем staleDate = scheduledDate, чтобы система прекратила обновления после истечения
                let content = ActivityContent(state: contentState, staleDate: scheduledDate)
                await existing.update(content)
                print("✅ Live Activity updated successfully")
            } else {
                await existing.update(using: contentState)
                print("✅ Live Activity updated successfully (iOS 16.1)")
            }

            // Обновляем флаг доступности тапов
            reevaluateCityTapEnabled()

            if hasTriggered {
                // Не завершаем LA: UI сам покажет "после" по времени.
                // Дадим системе зафиксировать контент перед удалением reminder.
                clearSelectedCity()
                reevaluateCityTapEnabled()
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch {}
                print("🗑️ Deleting reminder after LA update (no end)")
                self.deleteReminder(endLiveActivity: false)
            }
        } else {
            // Не создаем новую Live Activity если напоминание уже сработало
            guard !hasTriggered else {
                print("❌ Not creating Live Activity - already triggered")
                clearSelectedCity()
                reevaluateCityTapEnabled()
                return
            }

            print("🆕 Creating NEW Live Activity for reminder (one-time)")
            let attributes = ReminderLiveActivityAttributes(reminderID: reminder.id, title: "⊕ THE M.O.W TIME ⊗")
            if #available(iOS 16.2, *) {
                // Устанавливаем staleDate = scheduledDate, чтобы система прекратила обновления после истечения
                let content = ActivityContent(state: contentState, staleDate: scheduledDate)
                let result = try? Activity<ReminderLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                if result != nil {
                    print("✅ Live Activity created successfully")
                } else {
                    print("❌ Failed to create Live Activity")
                }
            } else {
                let result = try? Activity<ReminderLiveActivityAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
                if result != nil {
                    print("✅ Live Activity created successfully (iOS 16.1)")
                } else {
                    print("❌ Failed to create Live Activity (iOS 16.1)")
                }
            }
            // Убираем любые посторонние активности — должна быть только одна
            await purgeExtraneousActivities(keeping: reminder.id)
            // Новый LA создан — разрешаем тап по городам
            reevaluateCityTapEnabled()
        }
    }

    @available(iOS 16.1, *)
    private func endLiveActivity(reminderID: UUID) async {
        guard let activity = Activity<ReminderLiveActivityAttributes>.activities.first(where: { $0.attributes.reminderID == reminderID }) else {
            return
        }
        if #available(iOS 16.2, *) {
            let content = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(content, dismissalPolicy: .immediate)
        } else {
            await activity.end(dismissalPolicy: .immediate)
        }
        clearSelectedCity()
        reevaluateCityTapEnabled()
    }

    // Публичный метод для принудительного обновления Live Activity (вызывается из AppDelegate при уведомлении)
    @available(iOS 16.1, *)
    func forceUpdateLiveActivity(for reminder: ClockReminder) async {
        print("💥 Force updating Live Activity")
        await updateLiveActivity(for: reminder)
    }
#endif
}
