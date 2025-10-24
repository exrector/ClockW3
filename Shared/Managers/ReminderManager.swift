import Foundation
import Combine
import UserNotifications
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
#endif

// MARK: - Live Activity Preferences
private struct LiveActivityPreferences: Codable {
    var liveActivityEnabled: Bool
    var alwaysLiveActivity: Bool

    init(liveActivityEnabled: Bool = false, alwaysLiveActivity: Bool = false) {
        self.liveActivityEnabled = liveActivityEnabled
        self.alwaysLiveActivity = alwaysLiveActivity
    }
}

// MARK: - Reminder Manager
/// Управляет единственным напоминанием циферблата
@MainActor
class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published var currentReminder: ClockReminder?
    @Published var previewReminder: ClockReminder?  // Временное напоминание (не сохраняется)

    private let userDefaults = SharedUserDefaults.shared
    private let reminderKey = "clock_reminder"
    private let notificationIdentifier = "clock_reminder_notification"
    private let liveActivityPreferencesKey = "live_activity_preferences"
    private var updateTimer: Timer?

    private init() {
        loadReminder()
        // Создаем дефолтный preview при старте если нет сохраненного
        if currentReminder == nil {
            createDefaultPreview()
        }
#if canImport(ActivityKit) && !os(macOS)
        reconcileLiveActivityOnLaunch()
        startLiveActivityUpdateTimer()
#endif
    }
    
    private func createDefaultPreview() {
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

        // Создаем следующую дату для one-time напоминания
        let nextDate = ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: now)

        // Preview создаётся БЕЗ предпочтений - они применятся при confirmPreview() если нужно
        previewReminder = ClockReminder(hour: hour, minute: minute, date: nextDate)
    }

    // MARK: - Storage

    private func loadReminder() {
        guard let data = userDefaults.data(forKey: reminderKey),
              let reminder = try? JSONDecoder().decode(ClockReminder.self, from: data) else {
            currentReminder = nil
            return
        }
        
        // Проверяем не истекло ли one-time напоминание
        if let reminderDate = reminder.date, reminderDate < Date() {
            // Напоминание истекло, удаляем
            currentReminder = nil
            userDefaults.removeObject(forKey: reminderKey)
            return
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
            alwaysLiveActivity: reminder.alwaysLiveActivity
        )
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: liveActivityPreferencesKey)
            userDefaults.synchronize()
            print("💾 Saved Live Activity preferences: liveActivityEnabled=\(preferences.liveActivityEnabled), alwaysLiveActivity=\(preferences.alwaysLiveActivity)")
        }
    }

    private func loadLiveActivityPreferences() -> LiveActivityPreferences {
        guard let data = userDefaults.data(forKey: liveActivityPreferencesKey),
              let preferences = try? JSONDecoder().decode(LiveActivityPreferences.self, from: data) else {
            print("📂 No saved Live Activity preferences, using defaults")
            return LiveActivityPreferences()
        }
        print("📂 Loaded Live Activity preferences: liveActivityEnabled=\(preferences.liveActivityEnabled), alwaysLiveActivity=\(preferences.alwaysLiveActivity)")
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

    // MARK: - Preview Management

    /// Устанавливает временное напоминание (для предпросмотра)
    func setPreviewReminder(_ reminder: ClockReminder) {
        previewReminder = reminder
    }

    /// Очищает временное напоминание
    func clearPreviewReminder() {
        previewReminder = nil
        // Если нет сохраненного напоминания, сразу создаем новый preview
        if currentReminder == nil {
            createDefaultPreview()
        }
    }

    /// Подтверждает preview и создаёт реальное напоминание
    func confirmPreview() async {
        guard let preview = previewReminder else { return }

        // ВСЕГДА загружаем сохранённые предпочтения (если пользователь включал бесконечность)
        let preferences = loadLiveActivityPreferences()

        // Если включена бесконечность в предпочтениях - применяем её
        let finalReminder = ClockReminder(
            id: preview.id,
            hour: preview.hour,
            minute: preview.minute,
            date: preview.date,
            isEnabled: preview.isEnabled,
            liveActivityEnabled: preferences.liveActivityEnabled,
            alwaysLiveActivity: preferences.alwaysLiveActivity,
            isTimeSensitive: preview.isTimeSensitive
        )

        if preferences.alwaysLiveActivity {
            print("✅ Confirming preview with saved preferences (always-on mode): liveActivityEnabled=\(preferences.liveActivityEnabled)")
        } else {
            print("✅ Confirming preview without preferences (normal mode)")
        }

        await setReminder(finalReminder)
        clearPreviewReminder()
    }

    // MARK: - Reminder Management

    /// Создаёт или обновляет напоминание
    func setReminder(_ reminder: ClockReminder) async {
        // Удаляем старое уведомление
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        currentReminder = reminder
        saveReminder()

        // Создаём новое уведомление если включено
        if reminder.isEnabled {
            await scheduleNotification(for: reminder)
        }

        await updateLiveActivityIntegration(for: reminder)
    }

    /// Обновляет время существующего напоминания
    func updateReminderTime(hour: Int, minute: Int) async {
        guard var reminder = currentReminder else { return }

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
            alwaysLiveActivity: reminder.alwaysLiveActivity,
            isTimeSensitive: reminder.isTimeSensitive
        )
        await setReminder(reminder)
    }

    /// Обновляет режим повторения: ежедневно или один раз
    func updateReminderRepeat(isDaily: Bool, referenceDate: Date = Date()) async {
        guard var reminder = currentReminder else { return }
        guard reminder.isDaily != isDaily else { return }

        let nextDate = isDaily
            ? nil
            : ClockReminder.nextTriggerDate(hour: reminder.hour, minute: reminder.minute, from: referenceDate)

        reminder = ClockReminder(
            id: reminder.id,
            hour: reminder.hour,
            minute: reminder.minute,
            date: nextDate,
            isEnabled: reminder.isEnabled,
            liveActivityEnabled: reminder.liveActivityEnabled,
            alwaysLiveActivity: reminder.alwaysLiveActivity,
            isTimeSensitive: reminder.isTimeSensitive
        )
        await setReminder(reminder)
    }

    /// Удаляет напоминание
    func deleteReminder() {
        let reminderID = currentReminder?.id
        // НЕ сохраняем предпочтения при удалении - они уже сохранены при включении alwaysLiveActivity
        if let reminder = currentReminder {
            print("🗑️ Deleting reminder: liveActivityEnabled=\(reminder.liveActivityEnabled), alwaysLiveActivity=\(reminder.alwaysLiveActivity)")
        } else {
            print("🗑️ Deleting reminder, but currentReminder is nil")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        currentReminder = nil
        saveReminder()
        // Сразу создаем новый preview
        print("✨ Creating new preview after deletion")
        createDefaultPreview()

#if canImport(ActivityKit) && !os(macOS)
        if let reminderID, #available(iOS 16.1, *) {
            Task {
                await self.endLiveActivity(reminderID: reminderID)
            }
        }
#endif
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
            if reminder.date != nil {
            } else {
            }
        } catch {
        }
    }

    /// Обновляет флаг Live Activity
    func updateLiveActivityEnabled(isEnabled: Bool) async {
        guard var reminder = currentReminder else { return }
        guard reminder.liveActivityEnabled != isEnabled else { return }
        reminder.liveActivityEnabled = isEnabled
        await setReminder(reminder)
    }

    /// Обновляет флаг Time-Sensitive Alert
    func updateTimeSensitiveEnabled(isEnabled: Bool) async {
        guard var reminder = currentReminder else { return }
        guard reminder.isTimeSensitive != isEnabled else { return }
        reminder.isTimeSensitive = isEnabled
        await setReminder(reminder)
    }

    /// Обновляет флаг Always Live Activity
    func updateAlwaysLiveActivity(isEnabled: Bool) async {
        guard var reminder = currentReminder else { return }
        guard reminder.alwaysLiveActivity != isEnabled else { return }
        reminder.alwaysLiveActivity = isEnabled

        if isEnabled {
            // ВКЛЮЧЕНИЕ: сохраняем предпочтения НАВСЕГДА
            reminder.liveActivityEnabled = true
            saveLiveActivityPreferences(from: ClockReminder(
                id: reminder.id,
                hour: reminder.hour,
                minute: reminder.minute,
                date: reminder.date,
                isEnabled: reminder.isEnabled,
                liveActivityEnabled: true,
                alwaysLiveActivity: true,
                isTimeSensitive: reminder.isTimeSensitive
            ))
            print("🔒 Always-on mode ENABLED - preferences saved forever")
        } else {
            // ВЫКЛЮЧЕНИЕ: очищаем сохранённые предпочтения
            saveLiveActivityPreferences(from: ClockReminder(
                id: reminder.id,
                hour: reminder.hour,
                minute: reminder.minute,
                date: reminder.date,
                isEnabled: reminder.isEnabled,
                liveActivityEnabled: false,
                alwaysLiveActivity: false,
                isTimeSensitive: reminder.isTimeSensitive
            ))
            print("🔓 Always-on mode DISABLED - preferences cleared")
        }

        await setReminder(reminder)
    }

    private func updateLiveActivityIntegration(for reminder: ClockReminder) async {
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOS 16.1, *) {
            await updateLiveActivity(for: reminder)
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
            } else {
                await self.terminateOrphanedActivities()
            }
        }
    }

    @available(iOS 16.1, *)
    private func startLiveActivityUpdateTimer() {
        // Обновляем Live Activity каждые 10 секунд для проверки статуса
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let reminder = self.currentReminder else { return }
                await self.updateLiveActivity(for: reminder)
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
    }

    @available(iOS 16.1, *)
    private func updateLiveActivity(for reminder: ClockReminder) async {
        guard reminder.liveActivityEnabled, reminder.isEnabled else {
            print("⏸️ Live Activity disabled or reminder disabled")
            await endLiveActivity(reminderID: reminder.id)
            return
        }

        // Live Activity только для однократных напоминаний (если не включен always-on режим)
        guard !reminder.isDaily || reminder.alwaysLiveActivity else {
            print("⏸️ Daily reminder without always-on mode")
            await endLiveActivity(reminderID: reminder.id)
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

        print("🔄 updateLiveActivity: scheduledDate=\(scheduledDate), now=\(now), hasTriggered=\(hasTriggered)")

        let contentState = ReminderLiveActivityAttributes.ContentState(
            scheduledDate: scheduledDate,
            hasTriggered: hasTriggered
        )

        // Если напоминание сработало, закрываем через 2 минуты
        // Иначе staleDate не устанавливаем
        let staleDate = hasTriggered ? now.addingTimeInterval(120) : nil

        if let existing = Activity<ReminderLiveActivityAttributes>.activities.first(where: { $0.attributes.reminderID == reminder.id }) {
            print("📝 Updating existing Live Activity with hasTriggered=\(hasTriggered)")
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: staleDate)
                await existing.update(content)
                print("✅ Live Activity updated successfully")
            } else {
                await existing.update(using: contentState)
                print("✅ Live Activity updated successfully (iOS 16.1)")
            }

            // Если сработало, удаляем напоминание через 2 минуты
            if hasTriggered {
                print("⏳ Scheduling reminder deletion in 2 minutes")
                Task {
                    try? await Task.sleep(nanoseconds: 120_000_000_000) // 2 минуты
                    await MainActor.run {
                        print("🗑️ Deleting triggered reminder")
                        self.deleteReminder()
                    }
                }
            }
        } else {
            // Не создаем новую Live Activity если напоминание уже сработало
            guard !hasTriggered else {
                print("❌ Not creating Live Activity - already triggered")
                return
            }

            print("🆕 Creating NEW Live Activity for reminder")
            let attributes = ReminderLiveActivityAttributes(reminderID: reminder.id, title: "THE M.O.W TIME")
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: staleDate)
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
    }

    // Публичный метод для принудительного обновления Live Activity (вызывается из AppDelegate при уведомлении)
    @available(iOS 16.1, *)
    func forceUpdateLiveActivity(for reminder: ClockReminder) async {
        print("💥 Force updating Live Activity")
        await updateLiveActivity(for: reminder)
    }
#endif
}
