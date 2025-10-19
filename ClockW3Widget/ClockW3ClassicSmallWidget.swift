import WidgetKit
import SwiftUI

struct ClockW3ClassicSmallWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) private var systemColorScheme

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
            let frameSize = min(geometry.size.width, geometry.size.height)
            let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)

            ZStack {
                palette.background
                WidgetClockFaceView(
                    date: entry.date,
                    colorScheme: effectiveColorScheme
                )
                .frame(width: frameSize, height: frameSize)
                .scaleEffect(0.98)
                .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .widgetBackground(ClockColorPalette.system(colorScheme: effectiveColorScheme).background)
    }
}

struct ClockW3ClassicSmallWidget: Widget {
    let kind: String = "MOWClassicSmallWidget"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClockW3ClassicSmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Classic Small")
        .description("Original full-face clock in compact size")
        .supportedFamilies([.systemSmall])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
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
            entry: SimpleEntry(
                date: Date(),
                colorSchemePreference: "system",
                buildVersion: "0.0(0)",
                appGroupOK: true
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
