/*
DEVELOPER NOTE — Live Activity: как это должно работать

1. Что такое "Always Live Activity"
• Это только пользовательское ПРЕДПОЧТЕНИЕ: автоматически включать Live Activity у НОВЫХ одноразовых (one-time) напоминаний.
• Это НЕ “вечная” активность и НЕ запуск Live Activity для ежедневных напоминаний.
• Переключение “Always Live Activity” не должно “насильно” включать Live Activity у текущего ежедневного напоминания.

2. Когда запускаем Live Activity
• ТОЛЬКО для одноразовых напоминаний (reminder.date != nil).
• Для ежедневных (date == nil) Live Activity НИКОГДА не создаём и не обновляем — сразу завершаем, если вдруг есть.

3. DONE vs новый таймер
• Виджет должен показывать DONE, когда фактическое время напоминания прошло.
• НЕЛЬЗЯ мгновенно «перескакивать» на следующую дату и тем самым перерисовывать обратный отсчёт вместо DONE.
• Для one-time можно держать stale/DONE окно (например, 2 минуты), затем удалить напоминание.
• Для daily Live Activity не используется вообще, поэтому глитч “новый таймер вместо DONE” исключён.

4. Поведение при создании/подтверждении напоминания
• Если включено предпочтение “Always Live Activity” и напоминание одноразовое — liveActivityEnabled включаем автоматически для ЭТОГО нового напоминания.
• Если напоминание ежедневное — liveActivityEnabled игнорируем (оставляем false), Live Activity не запускаем.

5. UI переключатели
• Переключатель Live Activity должен быть доступен только для one-time напоминаний.
• Для daily отображайте его в состоянии “выкл.” и блокируйте нажатие (чтобы не было ложного ожидания, что LA заработает).
• Переключатель “Always Live Activity” меняет только предпочтение для будущих one-time напоминаний; не должен пытаться включать LA у daily прямо сейчас.

6. Делегаты уведомлений и таймеры в фоне
• Не рассчитывайте, что таймеры в приложении будут работать в фоне. Виджет Live Activity должен уметь показать DONE сам, основываясь на scheduledDate и текущем времени.
• Любые force-обновления из AppDelegate — это “подстраховка” при возврате в foreground, но не единственный механизм.

7. Безопасные инварианты (проверяйте перед правками)
• if reminder.isDaily == true → Live Activity запрещена (end, если есть).
• if reminder.date != nil && reminder.liveActivityEnabled == true → Live Activity разрешена.
• “Always Live Activity” НЕ означает “держать Live Activity постоянно”; это всего лишь автозапуск LA при СОЗДАНИИ one-time напоминания.

Конец заметки.
*/

import Foundation
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit

@available(iOS 16.1, *)
struct ReminderLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Время окончания (момент срабатывания напоминания)
        var endDate: Date
        // Флаг завершения, устанавливается менеджером при триггере
        var hasFinished: Bool
        // Дополнительно: выбранный пользователем город для отображения (опционально)
        var selectedCityName: String?
    }

    // Идентификатор напоминания для связи Activity с моделью
    var reminderID: UUID
    // Заголовок для UI активности
    var title: String
}
#endif
