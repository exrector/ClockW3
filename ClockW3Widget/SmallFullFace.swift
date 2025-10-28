import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct SmallFullFaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallFullFaceEntry {
        return SmallFullFaceEntry(
            date: Date(),
            colorSchemePreference: "system"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallFullFaceEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = SmallFullFaceEntry(
            date: Date(),
            colorSchemePreference: colorPref
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmallFullFaceEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"

        var entries: [SmallFullFaceEntry] = []
        let now = Date()

        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = SmallFullFaceEntry(
                date: now,
                colorSchemePreference: colorPref
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }

        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = SmallFullFaceEntry(
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
struct SmallFullFaceEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
}

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3ClassicSmallWidgetEntryView: View {
    var entry: SmallFullFaceProvider.Entry
    @Environment(\.colorScheme) private var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    #endif

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
            let frameSize = min(geometry.size.width, geometry.size.height)

            ZStack {
#if !os(macOS)
                palette.background
                    .ignoresSafeArea()
#endif
                WidgetClockFaceView(
                    date: entry.date,
                    colorScheme: effectiveColorScheme,
                    palette: palette
                )
                .frame(width: frameSize, height: frameSize)
                .scaleEffect(0.98)
                .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        #if os(macOS)
        .containerBackground(.ultraThinMaterial, for: .widget)
        #else
        .widgetBackground(palette.background)
        #endif
    }
}

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallFullFaceWidget: Widget {
    let kind: String = "MOWSmallFullFace"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: SmallFullFaceProvider()) { entry in
            ClockW3ClassicSmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Full Face")
        .description("Full clock face in small size")
        .supportedFamilies([.systemSmall])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

#if DEBUG
struct ClockW3ClassicSmallWidget_Previews: PreviewProvider {
    static var previews: some View {
        ClockW3ClassicSmallWidgetEntryView(
            entry: SmallFullFaceEntry(
                date: Date(),
                colorSchemePreference: "system"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
