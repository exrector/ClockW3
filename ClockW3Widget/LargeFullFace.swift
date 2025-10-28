import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct LargeFullFaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> LargeFullFaceEntry {
        return LargeFullFaceEntry(
            date: Date(),
            colorSchemePreference: "system"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LargeFullFaceEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = LargeFullFaceEntry(
            date: Date(),
            colorSchemePreference: colorPref
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LargeFullFaceEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"

        var entries: [LargeFullFaceEntry] = []
        let now = Date()

        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = LargeFullFaceEntry(
                date: now,
                colorSchemePreference: colorPref
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }

        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = LargeFullFaceEntry(
                date: entryDate,
                colorSchemePreference: colorPref
            )
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .after(nextMinuteStart))
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct LargeFullFaceEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
}

// MARK: - Widget View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct LargeFullFaceWidgetEntryView: View {
    @Environment(\.colorScheme) var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    #endif
    var entry: LargeFullFaceProvider.Entry

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
        #if os(macOS)
        // В активном состоянии (.fullColor) - полноцветная палитра
        // В неактивном состоянии (.accented/.vibrant) - белая монохромная
        if widgetRenderingMode == .fullColor {
            return ClockColorPalette.system(colorScheme: effectiveColorScheme)
        } else {
            return ClockColorPalette.forMacWidget(colorScheme: effectiveColorScheme)
        }
        #else
        return ClockColorPalette.system(colorScheme: effectiveColorScheme)
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            let frameSize = geometry.size

            ZStack {
                palette.background
                    .ignoresSafeArea()
                WidgetClockFaceView(
                    date: entry.date,
                    colorScheme: effectiveColorScheme,
                    palette: palette
                )
                .frame(width: frameSize.width, height: frameSize.height)
                .scaleEffect(0.98)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(contentMode: .fill)
            .clipped()
        }
        .ignoresSafeArea()
        .widgetBackground(palette.background)
    }
}

// MARK: - Widget Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct LargeFullFaceWidget: Widget {
    let kind: String = "MOWLargeFullFace"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: LargeFullFaceProvider()) { entry in
            LargeFullFaceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Full Face")
        .description("Full clock face display")
        .supportedFamilies([.systemLarge])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Preview
#Preview(as: .systemLarge) {
    LargeFullFaceWidget()
} timeline: {
    LargeFullFaceEntry(date: .now, colorSchemePreference: "system")
}
