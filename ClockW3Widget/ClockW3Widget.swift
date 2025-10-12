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

// MARK: - Simple Widget View
struct ClockW3WidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 8) {
                // Иконка часов
                Image(systemName: "clock.fill")
                    .font(.system(size: widgetFamily == .systemSmall ? 40 : 60))
                    .foregroundColor(.white)

                // Текущее время
                Text(entry.date, style: .time)
                    .font(.system(size: widgetFamily == .systemSmall ? 16 : 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                // Дата
                Text(entry.date, style: .date)
                    .font(.system(size: widgetFamily == .systemSmall ? 10 : 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .containerBackground(Color.black, for: .widget)
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
        .description("24-hour world clock widget")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    ClockW3Widget()
} timeline: {
    SimpleEntry(date: .now)
}
