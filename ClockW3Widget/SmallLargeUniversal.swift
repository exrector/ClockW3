import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLargeUniversalEntryView: View {
    var entry: SmallWidgetProvider.Entry
    @Environment(\.colorScheme) private var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
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
        let context = timeContext(for: entry.date)

        GeometryReader { geometry in
            let size = geometry.size
            let dividerWidth = max(2, size.width * 0.025)
            let leftWidth = size.width * 0.56
            let rightWidth = size.width - leftWidth - dividerWidth
            let highlightBackground = palette.numbers.opacity(effectiveColorScheme == .light ? 0.12 : 0.35)

            ZStack {
                palette.background
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    leftHourColumn(width: leftWidth, height: size.height, context: context)
                        .frame(width: leftWidth, height: size.height)

                    Rectangle()
                        .fill(palette.arrow)
                        .frame(width: dividerWidth)
                        .accessibilityHidden(true)

                    minuteColumn(width: rightWidth, height: size.height, context: context, highlightBackground: highlightBackground)
                        .frame(width: rightWidth, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .widgetBackground(palette.background)
        .environment(\.colorScheme, effectiveColorScheme)
    }

    private func leftHourColumn(width: CGFloat, height: CGFloat, context: TimeContext) -> some View {
        let labelSize = min(width, height)
        let cityFontSize = labelSize * 0.18
        let offsetFontSize = labelSize * 0.12
        let hourFontSize = height * 0.55
        let ampmFontSize = height * 0.18

        return VStack(alignment: .leading, spacing: height * 0.045) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.cityName)
                    .font(.system(size: cityFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(context.offsetString)
                    .font(.system(size: offsetFontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(palette.secondaryColor.opacity(0.75))
            }
            .padding(.top, height * 0.08)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline, spacing: width * 0.04) {
                Text(context.hourString)
                    .font(.system(size: hourFontSize, weight: .heavy, design: .monospaced))
                    .foregroundStyle(palette.numbers)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .monospacedDigit()

                if let ampm = context.amPmLabel {
                    Text(ampm)
                        .font(.system(size: ampmFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.arrow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(palette.arrow.opacity(0.14))
                        )
                        .accessibilityLabel("Period")
                        .accessibilityValue(ampm)
                }
            }
            .padding(.bottom, height * 0.08)
        }
        .padding(.horizontal, width * 0.08)
    }

    private func minuteColumn(width: CGFloat, height: CGFloat, context: TimeContext, highlightBackground: Color) -> some View {
        let secondarySize = height * 0.18
        let primarySize = height * 0.34

        return VStack(spacing: height * 0.08) {
            Text(context.previousMinuteString)
                .font(.system(size: secondarySize, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondaryColor.opacity(0.5))
                .monospacedDigit()
                .accessibilityLabel("Previous minute")
                .accessibilityValue(context.previousMinuteString)

            Text(context.currentMinuteString)
                .font(.system(size: primarySize, weight: .heavy, design: .monospaced))
                .foregroundStyle(palette.numbers)
                .padding(.horizontal, width * 0.1)
                .padding(.vertical, height * 0.045)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(highlightBackground)
                )
                .monospacedDigit()
                .accessibilityLabel("Current minute")
                .accessibilityValue(context.currentMinuteString)

            Text(context.nextMinuteString)
                .font(.system(size: secondarySize, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.secondaryColor.opacity(0.5))
                .monospacedDigit()
                .accessibilityLabel("Next minute")
                .accessibilityValue(context.nextMinuteString)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, width * 0.08)
        .padding(.vertical, height * 0.12)
    }

    private func resolvedTimeZone() -> TimeZone {
        if let cityTZ = entry.cityTimeZoneIdentifier, let tz = TimeZone(identifier: cityTZ) {
            return tz
        }
        return TimeZone.current
    }

    private func timeContext(for date: Date) -> TimeContext {
        let timeZone = resolvedTimeZone()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour24 = components.hour ?? 0
        let minute = components.minute ?? 0
        let prevMinute = (minute + 59) % 60
        let nextMinute = (minute + 1) % 60

        let displayHour: Int
        let ampmLabel: String?

        if entry.use12HourFormat {
            displayHour = hour24 % 12 == 0 ? 12 : hour24 % 12
            ampmLabel = hour24 < 12 ? "AM" : "PM"
        } else {
            displayHour = hour24
            ampmLabel = nil
        }

        let hourString = String(format: "%02d", displayHour)
        let cityName = TimeZoneDirectory.cityName(forIdentifier: timeZone.identifier)
        let offsetString = TimeZoneDirectory.gmtOffsetString(for: timeZone.identifier, at: date)

        return TimeContext(
            hourString: hourString,
            amPmLabel: ampmLabel,
            minute: minute,
            previousMinute: prevMinute,
            nextMinute: nextMinute,
            cityName: cityName,
            offsetString: offsetString
        )
    }

    private struct TimeContext {
        let hourString: String
        let amPmLabel: String?
        let minute: Int
        let previousMinute: Int
        let nextMinute: Int
        let cityName: String
        let offsetString: String

        var previousMinuteString: String { String(format: "%02d", previousMinute) }
        var currentMinuteString: String { String(format: "%02d", minute) }
        var nextMinuteString: String { String(format: "%02d", nextMinute) }
    }
}

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLargeUniversalWidget: Widget {
    let kind: String = "MOWSmallLargeUniversal"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SmallWidgetConfigurationIntent.self, provider: SmallWidgetProvider()) { entry in
            SmallLargeUniversalEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Small Universal")
        .description("Large hour + stacked minutes with city selection")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

#if DEBUG
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLargeUniversalWidget_Previews: PreviewProvider {
    static var previews: some View {
        SmallLargeUniversalEntryView(
            entry: SmallWidgetEntry(
                date: Date(),
                colorSchemePreference: "system",
                use12HourFormat: true,
                cityTimeZoneIdentifier: nil
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
