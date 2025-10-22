import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            colorSchemePreference: "system",
            buildVersion: buildString(),
            appGroupOK: appGroupAvailable()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = SimpleEntry(
            date: Date(),
            colorSchemePreference: colorPref,
            buildVersion: buildString(),
            appGroupOK: appGroupAvailable()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // Читаем настройку цветовой схемы при каждом обновлении timeline
        let appGroupOK = appGroupAvailable()
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let build = buildString()

        var entries: [SimpleEntry] = []
        let now = Date()

        // Получаем точное время начала следующей минуты для синхронизации
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond
        
        // Рассчитываем точное время начала следующей минуты
        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            // Fallback если не удалось рассчитать
            let entry = SimpleEntry(
                date: now,
                colorSchemePreference: colorPref,
                buildVersion: build,
                appGroupOK: appGroupOK
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }

        // Создаём entries для каждой минуты в течение часа, начиная с начала следующей минуты
        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = SimpleEntry(
                date: entryDate,
                colorSchemePreference: colorPref,
                buildVersion: build,
                appGroupOK: appGroupOK
            )
            entries.append(entry)
        }

        // Используем .after с точным временем начала следующей минуты для синхронизации
        let timeline = Timeline(entries: entries, policy: .after(nextMinuteStart))
        completion(timeline)
    }

    private func appGroupAvailable() -> Bool {
        // Если suiteName не удаётся создать — в расширении нет App Group
        return SharedUserDefaults.usingAppGroup
    }

    private func buildString() -> String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (info?["CFBundleVersion"] as? String) ?? "?"
        return "\(short)(\(build))"
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let buildVersion: String
    let appGroupOK: Bool
}

// MARK: - Widget View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var systemColorScheme
    var entry: Provider.Entry

    // Используем значение из entry вместо @AppStorage
    private var effectiveColorScheme: ColorScheme {
        switch entry.colorSchemePreference {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return systemColorScheme
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)
            let frameSize = geometry.size

            switch widgetFamily {
            case .systemMedium:
                MediumLineRibbonView(date: entry.date, colorScheme: effectiveColorScheme)
                    .frame(width: frameSize.width, height: frameSize.height)
                    .allowsHitTesting(false)
            default:
                ZStack {
                    palette.background
                    WidgetClockFaceView(
                        date: entry.date,
                        colorScheme: effectiveColorScheme
                    )
                    .frame(width: frameSize.width, height: frameSize.height)
                    .scaleEffect(0.98)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(contentMode: .fill)
                .clipped()
            }
        }
        .ignoresSafeArea()
        .containerBackground(for: .widget) {
            ClockColorPalette.system(colorScheme: effectiveColorScheme).background
        }
    }
}

// MARK: - Widget Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3Widget: Widget {
    let kind: String = "MOWWidget"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClockW3WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW time")
        .description("M.O.W TIME - 24-hour world clock with time zones")
        .supportedFamilies([.systemMedium, .systemLarge])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    ClockW3Widget()
} timeline: {
    SimpleEntry(date: .now, colorSchemePreference: "system", buildVersion: "0.0(0)", appGroupOK: true)
}
