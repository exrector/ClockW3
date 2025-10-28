import WidgetKit
import SwiftUI

// MARK: - Widget Entry View для большого размера
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3LargeWidgetEntryView: View {
    var entry: LargeWidgetProvider.Entry
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
            let widgetWidth = geometry.size.width
            let widgetHeight = geometry.size.height
            let fullClockSize = max(widgetWidth, widgetHeight) * 2
            let day = Calendar.current.component(.day, from: entry.date)

            ZStack {
                palette.background
                    .ignoresSafeArea()
                SimplifiedClockFace(
                    currentTime: entry.date,
                    palette: palette,
                    use12HourFormat: entry.use12HourFormat,
                    cityTimeZoneIdentifier: entry.cityTimeZoneIdentifier
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
        .widgetBackground(palette.background)
        // Важно: заставляем ассеты и весь UI следовать выбранной схеме, а не системной
        .environment(\.colorScheme, effectiveColorScheme)
    }
    
    // Вспомогательная структура для отображения даты
    private struct FlipDateCard: View {
        let day: Int
        let palette: ClockColorPalette
        let size: CGFloat

        @Environment(\.colorScheme) private var colorScheme

        private var formattedDay: String {
            String(format: "%02d", day)
        }

        var body: some View {
            let isDark = (colorScheme == .dark)

            ZStack {
                if isDark {
                    // В Dark: без заливки (прозрачный «пузырь») — сочетается с остальным светлым контентом
                    Circle()
                        .fill(Color.clear)
                } else {
                    // В Light: как было — тёмный пузырь с лёгким градиентом
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
                }

                Text(formattedDay)
                    .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                    // В Dark — белый (secondaryColor в вашей палитре), в Light — как раньше
                    .foregroundStyle(isDark ? palette.secondaryColor : palette.monthDayText)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(
                        (isDark ? palette.secondaryColor : palette.arrow).opacity(0.18),
                        lineWidth: max(size * 0.02, CGFloat(1))
                    )
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
struct LargeQuarterWidget: Widget {
    let kind: String = "MOWLargeQuarter"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LargeWidgetConfigurationIntent.self,
            provider: LargeWidgetProvider()
        ) { entry in
            ClockW3LargeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Quarter Large")
        .description("Quarter clock face with city selection")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemLarge) {
    LargeQuarterWidget()
} timeline: {
    SmallWidgetEntry(date: .now, colorSchemePreference: "system", use12HourFormat: false, cityTimeZoneIdentifier: nil)
}
