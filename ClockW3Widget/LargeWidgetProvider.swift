import WidgetKit
import SwiftUI

// MARK: - Timeline Provider для большого виджета
struct LargeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmallWidgetEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return SmallWidgetEntry(
            date: Date(),
            colorSchemePreference: "system",
            use12HourFormat: use12Hour,
            cityTimeZoneIdentifier: nil
        )
    }

    func snapshot(for configuration: LargeWidgetConfigurationIntent, in context: Context) async -> SmallWidgetEntry {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return SmallWidgetEntry(
            date: Date(),
            colorSchemePreference: colorPref,
            use12HourFormat: use12Hour,
            cityTimeZoneIdentifier: configuration.city?.id
        )
    }

    func timeline(for configuration: LargeWidgetConfigurationIntent, in context: Context) async -> Timeline<SmallWidgetEntry> {
        var entries: [SmallWidgetEntry] = []

        // Читаем настройки при каждом обновлении timeline
        _ = SharedUserDefaults.usingAppGroup
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        let cityIdentifier = configuration.city?.id

        let now = Date()
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        // Рассчитываем точное время начала следующей минуты
        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            // Fallback
            let entry = SmallWidgetEntry(
                date: now,
                colorSchemePreference: colorPref,
                use12HourFormat: use12Hour,
                cityTimeZoneIdentifier: cityIdentifier
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
        }

        // 1) Немедленный entry на текущий момент — чтобы изменения настроек применялись мгновенно после reload
        entries.append(
            SmallWidgetEntry(
                date: now,
                colorSchemePreference: colorPref,
                use12HourFormat: use12Hour,
                cityTimeZoneIdentifier: cityIdentifier
            )
        )

        // 2) Генерируем timeline на следующие 60 минут с обновлением каждую минуту, начиная с начала следующей минуты
        for minuteOffset in 0 ..< 60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = SmallWidgetEntry(
                date: entryDate,
                colorSchemePreference: colorPref,
                use12HourFormat: use12Hour,
                cityTimeZoneIdentifier: cityIdentifier
            )
            entries.append(entry)
        }

        // Позволяем системе перезагрузиться, когда таймлайн закончится
        return Timeline(entries: entries, policy: .atEnd)
    }
}
