import Foundation
import Combine
import UserNotifications

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

    private init() {
        loadReminder()
    }

    // MARK: - Storage

    private func loadReminder() {
        guard let data = userDefaults.data(forKey: reminderKey),
              let reminder = try? JSONDecoder().decode(ClockReminder.self, from: data) else {
            currentReminder = nil
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
            print("Failed to request notification permission: \(error)")
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
    }

    /// Включает/выключает напоминание
    func toggleReminder() async {
        guard var reminder = currentReminder else { return }
        reminder.isEnabled.toggle()
        await setReminder(reminder)
    }

    /// Обновляет время существующего напоминания
    func updateReminderTime(hour: Int, minute: Int) async {
        guard var reminder = currentReminder else { return }
        reminder = ClockReminder(
            id: reminder.id,
            hour: hour,
            minute: minute,
            date: reminder.date,
            isEnabled: reminder.isEnabled
        )
        await setReminder(reminder)
    }

    /// Удаляет напоминание
    func deleteReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        currentReminder = nil
        saveReminder()
    }

    // MARK: - Notification Scheduling

    private func scheduleNotification(for reminder: ClockReminder) async {
        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Время \(reminder.formattedTime)"
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
                print("One-time notification scheduled for \(reminder.formattedTime) on \(reminder.typeDescription)")
            } else {
                print("Daily notification scheduled for \(reminder.formattedTime)")
            }
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
}
