import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        var entries: [SimpleEntry] = []
        let currentDate = Date()

        // Обновляем каждую минуту в течение часа
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct SimpleEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget View
struct ClockW3WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) var systemColorScheme
    var entry: Provider.Entry

    // Читаем настройку цветовой схемы из SharedUserDefaults
    private var preferredColorScheme: ColorScheme? {
        let preference = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        switch preference {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil  // nil означает "использовать системную"
        }
    }

    // Выбираем какую схему использовать: настройку пользователя или системную
    private var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? systemColorScheme
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)

            ZStack {
                // Используем фон из палитры
                palette.background

                // Наш циферблат
                ClockFaceView(
                    interactivityEnabled: false,
                    overrideTime: entry.date,
                    overrideColorScheme: effectiveColorScheme  // Передаём выбранную цветовую схему
                )
                .frame(width: size, height: size)
                .allowsHitTesting(false)
            }
        }
        .containerBackground(for: .widget) {
            ClockColorPalette.system(colorScheme: effectiveColorScheme).background
        }
    }
}

// MARK: - Widget Configuration
struct ClockW3Widget: Widget {
    let kind: String = "ClockW3Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClockW3WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("24-hour world clock with time zones")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    ClockW3Widget()
} timeline: {
    SimpleEntry(date: .now)
}
