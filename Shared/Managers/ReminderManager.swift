import Foundation
import Combine
import UserNotifications
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
#endif

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
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // Создаем следующую дату для one-time напоминания
        let nextDate = ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: now)
        
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

    // MARK: - Notification Permissions

    /// Запрашивает разрешение на отправку уведомлений
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
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
        await setReminder(preview)
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
            liveActivityEnabled: reminder.liveActivityEnabled
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
            liveActivityEnabled: reminder.liveActivityEnabled
        )
        await setReminder(reminder)
    }

    /// Удаляет напоминание
    func deleteReminder() {
        let reminderID = currentReminder?.id
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        currentReminder = nil
        saveReminder()
        // Сразу создаем новый preview
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
        content.sound = .default
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
            await endLiveActivity(reminderID: reminder.id)
            return
        }

        // Live Activity только для однократных напоминаний
        guard !reminder.isDaily else {
            await endLiveActivity(reminderID: reminder.id)
            return
        }

        if #available(iOS 16.2, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        }

        let scheduledDate = reminder.nextScheduledDate()
        let now = Date()
        let hasTriggered = scheduledDate <= now

        let contentState = ReminderLiveActivityAttributes.ContentState(
            scheduledDate: scheduledDate,
            hasTriggered: hasTriggered
        )

        // Если напоминание сработало, закрываем через 2 минуты
        // Иначе staleDate не устанавливаем
        let staleDate = hasTriggered ? now.addingTimeInterval(120) : nil

        if let existing = Activity<ReminderLiveActivityAttributes>.activities.first(where: { $0.attributes.reminderID == reminder.id }) {
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: staleDate)
                await existing.update(content)
            } else {
                await existing.update(using: contentState)
            }

            // Если сработало, удаляем напоминание через 2 минуты
            if hasTriggered {
                Task {
                    try? await Task.sleep(nanoseconds: 120_000_000_000) // 2 минуты
                    await MainActor.run {
                        self.deleteReminder()
                    }
                }
            }
        } else {
            // Не создаем новую Live Activity если напоминание уже сработало
            guard !hasTriggered else { return }

            let attributes = ReminderLiveActivityAttributes(reminderID: reminder.id, title: "THE M.O.W TIME")
            if #available(iOS 16.2, *) {
                let content = ActivityContent(state: contentState, staleDate: staleDate)
                _ = try? Activity<ReminderLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } else {
                _ = try? Activity<ReminderLiveActivityAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: nil
                )
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
#endif
}
