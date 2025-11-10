import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLargeUniversalEntryView: View {
    var entry: SmallWidgetProvider.Entry
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.widgetFamily) private var widgetFamily
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
            let isWideFamily = widgetFamily == .systemLarge
            let size = geometry.size
            let dividerWidth = max(2, size.width * 0.02)
            let contentWidth = max(0, size.width - dividerWidth)
            let leftWidth = contentWidth / 2
            let rightWidth = leftWidth
            let minuteOffsets = [-1, 0, 1]
            let baseDimension = min(leftWidth, size.height)

            let leftLayout = LeftColumnLayout(
                cityFontSize: baseDimension * (isWideFamily ? 0.18 : 0.21),
                hourFontSize: baseDimension * (isWideFamily ? 0.58 : 0.54),
                ampmFontSize: baseDimension * (isWideFamily ? 0.18 : 0.2),
                topPadding: size.height * 0.045,
                bottomPadding: size.height * 0.05,
                horizontalPadding: max(leftWidth * 0.06, 4),
                ampmLineHeight: baseDimension * 0.28
            )

            let minuteLayout = MinuteColumnLayout(
                offsets: minuteOffsets,
                fontSize: baseDimension * 0.2,
                horizontalPadding: max(rightWidth * 0.08, 4)
            )

            ZStack {
                palette.background
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    leftHourColumn(width: leftWidth, height: size.height, context: context, layout: leftLayout)
                        .frame(width: leftWidth, height: size.height)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.arrow.opacity(0.0),
                                    palette.arrow,
                                    palette.arrow.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: dividerWidth)
                        .padding(.vertical, size.height * 0.19)
                        .accessibilityHidden(true)

                    minuteColumn(
                        width: rightWidth,
                        height: size.height,
                        context: context,
                        layout: minuteLayout
                    )
                        .frame(width: rightWidth, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .overlay(alignment: .top) {
                Text(context.cityName)
                    .font(.system(size: leftLayout.cityFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, leftLayout.topPadding)
                    .padding(.horizontal, leftLayout.horizontalPadding)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                amPmLabelView(
                    text: context.amPmLabel ?? "AM",
                    visible: context.amPmLabel != nil,
                    fontSize: leftLayout.ampmFontSize,
                    isLightBackground: effectiveColorScheme == .light
                )
                .frame(maxWidth: .infinity)
                .frame(height: leftLayout.ampmLineHeight, alignment: .center)
                .padding(.horizontal, leftLayout.horizontalPadding)
                .padding(.bottom, leftLayout.bottomPadding)
                .allowsHitTesting(false)
            }
        }
        .widgetBackground(palette.background)
        .environment(\.colorScheme, effectiveColorScheme)
    }

    private func leftHourColumn(width: CGFloat, height: CGFloat, context: TimeContext, layout: LeftColumnLayout) -> some View {
        Text(context.hourString)
            .font(.system(size: layout.hourFontSize, weight: .heavy, design: .monospaced))
            .foregroundStyle(palette.numbers)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .allowsTightening(true)
            .monospacedDigit()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.horizontalPadding)
    }

    @ViewBuilder
    private func amPmLabelView(
        text: String,
        visible: Bool,
        fontSize: CGFloat,
        isLightBackground: Bool
    ) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(isLightBackground ? Color.black : Color.white)
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(!visible)
            .accessibilityLabel(visible ? "Period" : "")
            .accessibilityValue(visible ? text : "")
    }

    private func minuteColumn(
        width: CGFloat,
        height: CGFloat,
        context: TimeContext,
        layout: MinuteColumnLayout
    ) -> some View {
        let items = minuteItems(baseMinute: context.minute, offsets: layout.offsets)

        return VStack {
            Spacer()
            Text(items.first?.text ?? "")
                .font(.system(size: layout.fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.numbers)
                .monospacedDigit()
                .offset(y: height * -0.08)
                .accessibilityLabel("Previous minute")
                .accessibilityValue(items.first?.text ?? "")

            Text(items[1].text)
                .font(.system(size: layout.fontSize, weight: .heavy, design: .monospaced))
                .foregroundStyle(palette.arrow)
                .monospacedDigit()
                .accessibilityLabel("Current minute")
                .accessibilityValue(items[1].text)

            Text(items.last?.text ?? "")
                .font(.system(size: layout.fontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.numbers)
                .monospacedDigit()
                .offset(y: height * 0.08)
                .accessibilityLabel("Next minute")
                .accessibilityValue(items.last?.text ?? "")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, layout.horizontalPadding)
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
        return TimeContext(
            hourString: hourString,
            amPmLabel: ampmLabel,
            minute: minute,
            cityName: cityName
        )
    }

    private struct TimeContext {
        let hourString: String
        let amPmLabel: String?
        let minute: Int
        let cityName: String

    }

    private struct LeftColumnLayout {
        let cityFontSize: CGFloat
        let hourFontSize: CGFloat
        let ampmFontSize: CGFloat
        let topPadding: CGFloat
        let bottomPadding: CGFloat
        let horizontalPadding: CGFloat
        let ampmLineHeight: CGFloat
    }

    private struct MinuteColumnLayout {
        let offsets: [Int]
        let fontSize: CGFloat
        let horizontalPadding: CGFloat
    }

    private struct MinuteItem: Identifiable {
        let offset: Int
        let value: Int

        var id: Int { offset }
        var text: String { String(format: "%02d", value) }
        var isCurrent: Bool { offset == 0 }
    }

    private func minuteItems(baseMinute: Int, offsets: [Int]) -> [MinuteItem] {
        offsets.map { offset in
            let value = (baseMinute + offset) % 60
            let normalized = value >= 0 ? value : value + 60
            return MinuteItem(offset: offset, value: normalized)
        }
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
        .supportedFamilies([.systemSmall, .systemLarge])
        .contentMarginsDisabled()
    }
}

#if DEBUG
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLargeUniversalWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmallLargeUniversalEntryView(
                entry: SmallWidgetEntry(
                    date: Date(),
                    colorSchemePreference: "system",
                    use12HourFormat: true,
                    cityTimeZoneIdentifier: nil
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemSmall))

            SmallLargeUniversalEntryView(
                entry: SmallWidgetEntry(
                    date: Date(),
                    colorSchemePreference: "system",
                    use12HourFormat: false,
                    cityTimeZoneIdentifier: nil
                )
            )
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
#endif
