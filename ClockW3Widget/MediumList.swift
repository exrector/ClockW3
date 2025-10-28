import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct MediumListProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumListEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return MediumListEntry(
            date: Date(),
            colorSchemePreference: "system",
            use12HourFormat: use12Hour
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MediumListEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        let entry = MediumListEntry(
            date: Date(),
            colorSchemePreference: colorPref,
            use12HourFormat: use12Hour
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumListEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)

        var entries: [MediumListEntry] = []
        let now = Date()

        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = MediumListEntry(
                date: now,
                colorSchemePreference: colorPref,
                use12HourFormat: use12Hour
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }

        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = MediumListEntry(
                date: entryDate,
                colorSchemePreference: colorPref,
                use12HourFormat: use12Hour
            )
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .after(nextMinuteStart))
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct MediumListEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let use12HourFormat: Bool
}

// MARK: - Widget View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumListWidgetEntryView: View {
    @Environment(\.colorScheme) var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    #endif
    var entry: MediumListProvider.Entry

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

    private var palette: ClockColorPalette {
        return ClockColorPalette.system(colorScheme: effectiveColorScheme)
    }

    var body: some View {
        #if os(macOS)
        let isMacInactive = widgetRenderingMode != .fullColor
        #else
        let isMacInactive = false
        #endif
        MediumLineRibbonView(
            date: entry.date,
            colorScheme: effectiveColorScheme,
            use12HourFormat: entry.use12HourFormat,
            isMacInactiveMode: isMacInactive
        )
        .ignoresSafeArea()
        #if os(macOS)
        .containerBackground(.ultraThinMaterial, for: .widget)
        #else
        .widgetBackground(palette.background)
        #endif
    }
}

// MARK: - Widget Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumListWidget: Widget {
    let kind: String = "MOWMediumList"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: MediumListProvider()) { entry in
            MediumListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW List")
        .description("List of cities with local times")
        .supportedFamilies([.systemMedium])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    MediumListWidget()
} timeline: {
    MediumListEntry(date: .now, colorSchemePreference: "system", use12HourFormat: false)
}
