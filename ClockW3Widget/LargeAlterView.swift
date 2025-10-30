import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct LargeAlterEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
}

// MARK: - Timeline Provider
struct LargeAlterProvider: TimelineProvider {
    func placeholder(in context: Context) -> LargeAlterEntry {
        return LargeAlterEntry(
            date: Date(),
            colorSchemePreference: "system"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LargeAlterEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = LargeAlterEntry(
            date: Date(),
            colorSchemePreference: colorPref
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LargeAlterEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        
        var entries: [LargeAlterEntry] = []
        let now = Date()
        
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond
        
        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = LargeAlterEntry(
                date: now,
                colorSchemePreference: colorPref
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }
        
        // Немедленный entry
        entries.append(
            LargeAlterEntry(
                date: now,
                colorSchemePreference: colorPref
            )
        )
        
        // Timeline на 60 минут
        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = LargeAlterEntry(
                date: entryDate,
                colorSchemePreference: colorPref
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Widget View
struct LargeAlterWidgetView: View {
    var entry: LargeAlterProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private var overrideColorScheme: ColorScheme? {
        switch entry.colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            AlternativeClockView(
                overrideColorScheme: overrideColorScheme,
                overrideTime: entry.date,
                overrideCityName: nil
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .widgetBackground(overrideColorScheme == .dark ? Color.black : Color.white)
    }
}

// MARK: - Widget Configuration
struct LargeAlterWidget: Widget {
    let kind: String = "LargeAlterWidget"
    
    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: LargeAlterProvider()) { entry in
            LargeAlterWidgetView(entry: entry)
        }
        .configurationDisplayName("Alternative Clock")
        .description("Alternative clock view with drum selector")
        .supportedFamilies([.systemLarge])
        
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}
