import WidgetKit
import SwiftUI

// MARK: - Widget Entry View для большого размера
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3LargeWidgetEntryView: View {
    var entry: LargeWidgetProvider.Entry
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
            let widgetWidth = geometry.size.width
            let widgetHeight = geometry.size.height
            let fullClockSize = max(widgetWidth, widgetHeight) * 2
            let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)
            let day = Calendar.current.component(.day, from: entry.date)

            ZStack {
                palette.background
                    .ignoresSafeArea()

                SimplifiedClockFace(
                    currentTime: entry.date,
                    palette: palette,
                    use12HourFormat: entry.use12HourFormat
                )
                .frame(width: fullClockSize, height: fullClockSize)
                .position(x: 0, y: widgetHeight)
            }
            .frame(width: widgetWidth, height: widgetHeight)
            .clipped()
            .overlay(alignment: .topTrailing) {
                FlipDateCard(
                    day: day,
                    palette: palette,
                    size: min(widgetWidth, widgetHeight) * 0.22
                )
                .padding(.top, widgetHeight * 0.045)
                .padding(.trailing, widgetWidth * 0.045)
                .allowsHitTesting(false)
            }
        }
        .widgetBackground(ClockColorPalette.system(colorScheme: effectiveColorScheme).background)
        // Важно: заставляем ассеты и весь UI следовать выбранной схеме, а не системной
        .environment(\.colorScheme, effectiveColorScheme)
    }
    
    // Вспомогательная структура для отображения даты
    private struct FlipDateCard: View {
        let day: Int
        let palette: ClockColorPalette
        let size: CGFloat

        private var formattedDay: String {
            String(format: "%02d", day)
        }

        var body: some View {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.monthDayBackground.opacity(0.9),
                                palette.monthDayBackground.opacity(0.78)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text(formattedDay)
                    .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.monthDayText)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(palette.arrow.opacity(0.18), lineWidth: max(size * 0.02, CGFloat(1)))
            )
            .shadow(color: .black.opacity(0.12), radius: size * 0.12, y: size * 0.04)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day")
            .accessibilityValue("\(day)")
        }
    }
}

// MARK: - Widget
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3LargeWidget: Widget {
    let kind: String = "MOWLargeWidget"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: LargeWidgetProvider()) { entry in
            ClockW3LargeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Large")
        .description("Large clock display")
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
    ClockW3LargeWidget()
} timeline: {
    SmallWidgetEntry(date: .now, colorSchemePreference: "system", use12HourFormat: false)
}
