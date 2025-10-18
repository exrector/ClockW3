import Foundation
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit

@available(iOS 16.1, *)
struct ReminderLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Фактическое время ближайшего напоминания
        var scheduledDate: Date
        /// Флаг, указывающий что напоминание сработало (время прошло)
        var hasTriggered: Bool
    }

    /// Идентификатор напоминания, чтобы синхронизировать активность и модель
    var reminderID: UUID
    /// Заголовок, который можно использовать в UI активности
    var title: String
}
#endif
