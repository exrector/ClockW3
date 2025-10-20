//
//  ClockW3SmallWidget.swift
//  ClockW3Widget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider
struct SmallWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallWidgetEntry {
        SmallWidgetEntry(date: Date(), colorSchemePreference: "system")
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallWidgetEntry) -> ()) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = SmallWidgetEntry(date: Date(), colorSchemePreference: colorPref)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SmallWidgetEntry] = []

        // Читаем настройку цветовой схемы при каждом обновлении timeline
        let appGroupOK = SharedUserDefaults.usingAppGroup
        print("📱 SmallWidget getTimeline - appGroupOK: \(appGroupOK)")
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        print("📱 SmallWidget getTimeline - colorPref: \(colorPref)")

        // Генерируем timeline на следующие 60 минут с обновлением каждую минуту
        let currentDate = Date()
        for minuteOffset in 0 ..< 60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SmallWidgetEntry(date: entryDate, colorSchemePreference: colorPref)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct SmallWidgetEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
}

/// Bubble-style date badge for the small widget.
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

// MARK: - Widget Entry View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3SmallWidgetEntryView: View {
    var entry: SmallWidgetProvider.Entry
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
            let widgetSize = min(geometry.size.width, geometry.size.height)
            let fullClockSize = widgetSize * 2
            let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)
            let day = Calendar.current.component(.day, from: entry.date)

            ZStack {
                palette.background
                    .ignoresSafeArea()

                SimplifiedClockFace(
                    currentTime: entry.date,
                    palette: palette
                )
                .frame(width: fullClockSize, height: fullClockSize)
                .position(x: 0, y: widgetSize)
            }
            .frame(width: widgetSize, height: widgetSize)
            .clipped()
            .overlay(alignment: .topTrailing) {
                FlipDateCard(
                    day: day,
                    palette: palette,
                    size: widgetSize * 0.22
                )
                .padding(.top, widgetSize * 0.045)
                .padding(.trailing, widgetSize * 0.045)
                .allowsHitTesting(false)
            }
        }
        .widgetBackground(ClockColorPalette.system(colorScheme: effectiveColorScheme).background)
    }
}

// MARK: - Simplified Clock Face (только для виджета)
struct SimplifiedClockFace: View {
    let currentTime: Date
    let palette: ClockColorPalette
    private let staticArrowAngle: Double = -Double.pi / 4  // 315°
    private let tickDotRadiusRatio: CGFloat = 0.86
    private let numberRingRadiusRatio: CGFloat = 0.72
    private let hourAngleStep: Double = ClockConstants.hourTickStepRadians  // 15°
    private let minuteBubbleRadiusRatio: CGFloat = 0.075
    private let minuteBubbleGapRatio: CGFloat = 0.03
    private let totalHourMarks = 24

    var body: some View {
        Canvas { context, size in
            let baseRadius = min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rotationAngle = rotationOffset(for: currentTime)

            drawBackground(context: context, center: center, baseRadius: baseRadius)
            drawTicks(context: context, center: center, baseRadius: baseRadius, rotationAngle: rotationAngle)
            drawNumbers(context: context, center: center, baseRadius: baseRadius, rotationAngle: rotationAngle)

            if let localInfo = makeLocalCityInfo(for: currentTime) {
                drawLocalCityOrbit(
                    context: context,
                    center: center,
                    baseRadius: baseRadius,
                    info: localInfo
                )
                drawArrow(
                    context: context,
                    center: center,
                    baseRadius: baseRadius,
                    info: localInfo
                )
            }

            drawCenterDisc(context: context, center: center, baseRadius: baseRadius)
        }
    }

    private func drawBackground(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat
    ) {
        let rect = CGRect(
            x: center.x - baseRadius,
            y: center.y - baseRadius,
            width: baseRadius * 2,
            height: baseRadius * 2
        )

        context.fill(Path(ellipseIn: rect), with: .color(palette.background))
    }

    private func drawTicks(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        rotationAngle: Double
    ) {
        let minutesPerTick: Double = 10
        let ticksPerHour = Int(60 / minutesPerTick)  // 6
        let totalTicks = ticksPerHour * totalHourMarks
        let sizeScale: CGFloat = 1.3 * 1.15         // +30% и дополнительно +15%

        for index in 0..<totalTicks {
            let isHourTick = index % ticksPerHour == 0
            let isHalfHourTick = (index % (ticksPerHour / 2) == 0) && !isHourTick  // каждые 30 минут

            let dotDiameter: CGFloat
            let color: Color

            if isHourTick {
                dotDiameter = baseRadius * ClockConstants.hourTickThickness * 3.0 * sizeScale
                color = palette.hourTicks
            } else if isHalfHourTick {
                dotDiameter = baseRadius * ClockConstants.halfHourTickThickness * 2.5 * sizeScale
                color = palette.minorTicks
            } else {
                dotDiameter = baseRadius * ClockConstants.quarterTickThickness * 2.0 * sizeScale
                color = palette.minorTicks.opacity(0.85)
            }

            let minutesFromBase = Double(index) * minutesPerTick
            let angle = minutesFromBase / 60.0 * hourAngleStep + rotationAngle

            let dotCenter = AngleCalculations.pointOnCircle(
                center: center,
                radius: baseRadius * tickDotRadiusRatio,
                angle: angle
            )

            let rect = CGRect(
                x: dotCenter.x - dotDiameter / 2,
                y: dotCenter.y - dotDiameter / 2,
                width: dotDiameter,
                height: dotDiameter
            )

            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func drawNumbers(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        rotationAngle: Double
    ) {
        let fontSize = baseRadius * 2 * ClockConstants.numberFontSizeRatio
        let baseHour = 18

        for index in 0..<totalHourMarks {
            let rawHour = (baseHour + index) % 24
            let displayHour = rawHour == 0 ? 24 : rawHour
            let angle = Double(index) * hourAngleStep + rotationAngle
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: baseRadius * numberRingRadiusRatio,
                angle: angle
            )

            let text = Text(String(format: "%02d", displayHour))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(palette.numbers)

            context.draw(text, at: position, anchor: .center)
        }
    }

    private func drawLocalCityOrbit(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        info: LocalCityInfo
    ) {
        let orbitRadius = baseRadius * ClockConstants.outerLabelRingRadius
        let fontSize = baseRadius * 2 * ClockConstants.labelRingFontSizeRatio
        let characters = Array(info.displayName.uppercased())

        if !characters.isEmpty {
            let letterSpacing = Double(fontSize) * 0.8
            let totalWidth = Double(max(characters.count - 1, 0)) * letterSpacing
            let startAngle = info.arrowAngle - totalWidth / (2 * Double(orbitRadius))

            for (index, character) in characters.enumerated() {
                let letterAngle = startAngle + Double(index) * letterSpacing / Double(orbitRadius)
                let position = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: orbitRadius,
                    angle: letterAngle
                )

                if character != " " {
                    var letterContext = context
                    letterContext.translateBy(x: position.x, y: position.y)
                    letterContext.rotate(by: Angle(radians: letterAngle + .pi / 2))

                    let text = Text(String(character))
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(palette.arrow)

                    letterContext.draw(text, at: .zero, anchor: .center)
                }
            }

            let angularWidth = totalWidth / Double(orbitRadius)
            let padding = (Double(fontSize) * 0.8) / Double(baseRadius) * 0.7
            let occupiedStart = info.arrowAngle - angularWidth / 2 - padding
            let occupiedEnd = info.arrowAngle + angularWidth / 2 + padding

            let freeRanges = calculateFreeRanges(
                occupiedRanges: [(start: occupiedStart, end: occupiedEnd)]
            )

            let segmentWidth = baseRadius * 0.1

            for range in freeRanges where range.end > range.start {
                var path = Path()
                path.addArc(
                    center: center,
                    radius: orbitRadius,
                    startAngle: Angle(radians: range.start),
                    endAngle: Angle(radians: range.end),
                    clockwise: false
                )

                context.stroke(
                    path,
                    with: .color(palette.secondaryColor),
                    style: StrokeStyle(lineWidth: segmentWidth, lineCap: .butt)
                )
            }
        }
    }

    private func drawArrow(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        info: LocalCityInfo
    ) {
        let arrowThickness = baseRadius * ClockConstants.arrowThicknessRatio * 1.4
        let bubbleOrbitRatio = minuteBubbleOrbitRatio()
        let arrowEndRatio = max(bubbleOrbitRatio - minuteBubbleRadiusRatio - minuteBubbleGapRatio, 0.12)
        let arrowEndRadius = baseRadius * arrowEndRatio
        let arrowEndPosition = AngleCalculations.pointOnCircle(
            center: center,
            radius: arrowEndRadius,
            angle: info.arrowAngle
        )

        var path = Path()
        path.move(to: center)
        path.addLine(to: arrowEndPosition)

        context.stroke(
            path,
            with: .color(palette.arrow),
            style: StrokeStyle(lineWidth: arrowThickness, lineCap: .round)
        )

        drawMinuteBubble(
            context: context,
            position: minuteBubblePosition(
                center: center,
                baseRadius: baseRadius,
                angle: info.arrowAngle
            ),
            baseRadius: baseRadius,
            minute: info.minute
        )

        let markerPosition = AngleCalculations.pointOnCircle(
            center: center,
            radius: baseRadius * tickDotRadiusRatio,
            angle: info.arrowAngle
        )
        let markerSize = baseRadius * 0.03 * 1.35
        let markerRect = CGRect(
            x: markerPosition.x - markerSize / 2,
            y: markerPosition.y - markerSize / 2,
            width: markerSize,
            height: markerSize
        )

        context.fill(Path(ellipseIn: markerRect), with: .color(palette.arrow))
    }

    private func minuteBubblePosition(
        center: CGPoint,
        baseRadius: CGFloat,
        angle: Double
    ) -> CGPoint {
        let bubbleRadius = minuteBubbleOrbitRatio()
        return AngleCalculations.pointOnCircle(
            center: center,
            radius: baseRadius * bubbleRadius,
            angle: angle
        )
    }

    private func drawMinuteBubble(
        context: GraphicsContext,
        position: CGPoint,
        baseRadius: CGFloat,
        minute: Int
    ) {
        let bubbleRadius = baseRadius * minuteBubbleRadiusRatio
        let bubbleRect = CGRect(
            x: position.x - bubbleRadius,
            y: position.y - bubbleRadius,
            width: bubbleRadius * 2,
            height: bubbleRadius * 2
        )

        let bubblePath = Path(ellipseIn: bubbleRect)

        context.fill(
            bubblePath,
            with: .color(palette.background.opacity(0.9))
        )
        context.stroke(
            bubblePath,
            with: .color(palette.arrow),
            lineWidth: bubbleRadius * 0.18
        )

        let minuteText = Text(String(format: "%02d", minute))
            .font(.system(size: bubbleRadius * 1.2, weight: .bold, design: .rounded))
            .foregroundColor(palette.arrow)

        context.draw(minuteText, at: position, anchor: .center)
    }

    private func drawCenterDisc(
        context: GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat
    ) {
        let radius = baseRadius * ClockConstants.centerButtonVisualRatio
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.fill(Path(ellipseIn: rect), with: .color(palette.centerCircle))
    }

    private func makeLocalCityInfo(for time: Date) -> LocalCityInfo? {
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.minute], from: time)
        guard let minute = components.minute else { return nil }

        let city = WorldCity.make(identifier: timeZone.identifier)

        return LocalCityInfo(displayName: city.name, arrowAngle: staticArrowAngle, minute: minute)
    }
    
    private func minuteBubbleOrbitRatio() -> CGFloat {
        min(tickDotRadiusRatio + 0.09, 0.55)
    }
    
    private func rotationOffset(for time: Date) -> Double {
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else {
            return 0
        }

        let hour24 = Double(hour) + Double(minute) / 60.0
        let baseAngle = ClockConstants.calculateArrowAngle(hour24: hour24)
        return ClockConstants.normalizeAngle(staticArrowAngle - baseAngle)
    }

    private func calculateFreeRanges(
        occupiedRanges: [(start: Double, end: Double)]
    ) -> [(start: Double, end: Double)] {
        guard !occupiedRanges.isEmpty else {
            return [(start: 0, end: 2 * .pi)]
        }

        var normalized: [(start: Double, end: Double)] = []

        for range in occupiedRanges {
            var start = range.start
            var end = range.end

            while start < 0 { start += 2 * .pi }
            while start >= 2 * .pi { start -= 2 * .pi }
            while end < 0 { end += 2 * .pi }
            while end >= 2 * .pi { end -= 2 * .pi }

            if start > end {
                normalized.append((start: start, end: 2 * .pi))
                normalized.append((start: 0, end: end))
            } else {
                normalized.append((start: start, end: end))
            }
        }

        normalized.sort { $0.start < $1.start }
        var merged: [(start: Double, end: Double)] = []

        for range in normalized {
            if merged.isEmpty {
                merged.append(range)
            } else {
                let lastIndex = merged.count - 1
                if range.start <= merged[lastIndex].end {
                    merged[lastIndex].end = max(merged[lastIndex].end, range.end)
                } else {
                    merged.append(range)
                }
            }
        }

        if merged.isEmpty {
            return [(start: 0, end: 2 * .pi)]
        }

        var freeRanges: [(start: Double, end: Double)] = []

        if merged[0].start > 0 {
            freeRanges.append((start: 0, end: merged[0].start))
        }

        if merged.count > 1 {
            for index in 0..<(merged.count - 1) {
                let gapStart = merged[index].end
                let gapEnd = merged[index + 1].start
                if gapStart < gapEnd {
                    freeRanges.append((start: gapStart, end: gapEnd))
                }
            }
        }

        if let last = merged.last, last.end < 2 * .pi {
            freeRanges.append((start: last.end, end: 2 * .pi))
        }

        return freeRanges
    }

    private struct LocalCityInfo {
        let displayName: String
        let arrowAngle: Double
        let minute: Int
    }
}

// MARK: - Widget
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3SmallWidget: Widget {
    let kind: String = "MOWSmallWidget"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: SmallWidgetProvider()) { entry in
            ClockW3SmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Small")
        .description("Compact time display")
        .supportedFamilies([.systemSmall])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ClockW3SmallWidget_Previews: PreviewProvider {
    static var previews: some View {
        ClockW3SmallWidgetEntryView(
            entry: SmallWidgetEntry(date: Date(), colorSchemePreference: "system")
        )
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
