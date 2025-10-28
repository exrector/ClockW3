//
//  ClockW3MediumWidget.swift
//  ПОВОРОТНЫЙ ЦИФЕРБЛАТ (Статичная стрелка) - Medium виджет
//  Показывает верхнюю ПОЛОВИНУ циферблата (от 9 через 12 до 3)
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider для Medium виджета
struct MediumWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumWidgetEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return MediumWidgetEntry(date: Date(), colorSchemePreference: "system", use12HourFormat: use12Hour)
    }

    func getSnapshot(in context: Context, completion: @escaping (MediumWidgetEntry) -> ()) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        let entry = MediumWidgetEntry(date: Date(), colorSchemePreference: colorPref, use12HourFormat: use12Hour)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumWidgetEntry>) -> ()) {
        var entries: [MediumWidgetEntry] = []

        // Читаем настройки при каждом обновлении timeline
        _ = SharedUserDefaults.usingAppGroup
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)

        let now = Date()
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        // Рассчитываем точное время начала следующей минуты
        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            // Fallback
            let entry = MediumWidgetEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour)
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }

        // 1) Немедленный entry на текущий момент — чтобы изменения настроек применялись мгновенно после reload
        entries.append(MediumWidgetEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour))

        // 2) Генерируем timeline на следующие 60 минут с обновлением каждую минуту, начиная с начала следующей минуты
        for minuteOffset in 0 ..< 60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = MediumWidgetEntry(date: entryDate, colorSchemePreference: colorPref, use12HourFormat: use12Hour)
            entries.append(entry)
        }

        // Позволяем системе перезагрузиться, когда таймлайн закончится
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry для Medium виджета
struct MediumWidgetEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let use12HourFormat: Bool
}

/// Bubble-style date badge for the medium widget.
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

// MARK: - Medium Widget Entry View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct ClockW3MediumWidgetEntryView: View {
    var entry: MediumWidgetProvider.Entry
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
            let widgetSize = geometry.size
            let widgetHeight = widgetSize.height
            let scale: CGFloat = 1.1  // Увеличиваем масштаб на 10%
            let fullClockSize = widgetHeight * 2 * scale  // Полный циферблат = двойная высота виджета * масштаб

            ZStack {
#if !os(macOS)
                palette.background
                    .ignoresSafeArea()
#endif
                // ПОВОРОТНЫЙ ЦИФЕРБЛАТ С МИНУТНОЙ ШКАЛОЙ: показываем верхнюю половину
                // Стрелка статична на 270° (вертикально вверх), циферблат вращается
                MediumClockFace(
                    currentTime: entry.date,
                    palette: palette,
                    use12HourFormat: entry.use12HourFormat
                )
                .frame(width: fullClockSize, height: fullClockSize)
                .position(x: widgetSize.width / 2, y: fullClockSize / 2)  // Центр циферблата, верхний край у верха виджета
            }
            .frame(width: widgetSize.width, height: widgetHeight)
            .clipped()
            .environment(\.colorScheme, effectiveColorScheme)
        }
        #if os(macOS)
        .containerBackground(.ultraThinMaterial, for: .widget)
        #else
        .widgetBackground(palette.background)
        #endif
        // Важно: заставляем ассеты и весь UI следовать выбранной схеме, а не системной
        .environment(\.colorScheme, effectiveColorScheme)
    }
}

// MARK: - Widget Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumHalfWidget: Widget {
    let kind: String = "MOWMediumHalf"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: MediumWidgetProvider()) { entry in
            ClockW3MediumWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Medium")
        .description("Upper half of rotating clock face")
        .supportedFamilies([.systemMedium])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Medium Clock Face с минутной шкалой
struct MediumClockFace: View {
    let currentTime: Date
    let palette: ClockColorPalette
    let use12HourFormat: Bool

    private let staticArrowAngle: Double = -Double.pi / 2  // 270° - стрелка вертикально вверх

    var body: some View {
        Canvas { context, size in
            let baseRadius = min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let rotationAngle = rotationOffset(for: currentTime)

            drawBackground(context: context, center: center, baseRadius: baseRadius)

            let calendar = Calendar.current
            let month = calendar.component(.month, from: currentTime)
            let day = calendar.component(.day, from: currentTime)
            let hour = calendar.component(.hour, from: currentTime)
            let minute = calendar.component(.minute, from: currentTime)

            drawMonthScale(context: context, center: center, baseRadius: baseRadius, currentMonth: month)
            drawDayScale(context: context, center: center, baseRadius: baseRadius, currentDay: day)
            drawRedRingBetweenDayAndHour(context: context, center: center, baseRadius: baseRadius)
            drawHourScale(context: context, center: center, baseRadius: baseRadius, currentHour: hour)
            drawMinuteScale(context: context, center: center, baseRadius: baseRadius, currentMinute: minute)
            drawLocalCityOrbit(context: context, center: center, baseRadius: baseRadius, rotationAngle: rotationAngle)

            // Шестерёнка в центре ЦИФЕРБЛАТА (там где начинается стрелка)
            // Рисуем её ДО стрелки и центрального диска, чтобы поворот canvas не влиял на остальные элементы
            drawGear(context: context, center: center, baseRadius: baseRadius)

            drawArrow(context: context, center: center, baseRadius: baseRadius)
            drawCenterDisc(context: context, center: center, baseRadius: baseRadius)
        }
    }

    private func drawBackground(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat) {
        let rect = CGRect(
            x: center.x - baseRadius,
            y: center.y - baseRadius,
            width: baseRadius * 2,
            height: baseRadius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(palette.background))
    }

    private func drawMonthScale(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, currentMonth: Int) {
        // Орбита месяцев: 12 месяцев, одна строка, все цифры одинаковой высоты
        // Вращается так, чтобы текущий месяц был под стрелкой (270°)
        let totalMonths = 12

        // Все цифры одинакового размера, как в других орбитах
        let fontSize = baseRadius * 0.12

        // Орбита месяцев (самая внутренняя, увеличенный зазор до дней 0.55)
        let orbitRadius = baseRadius * 0.43

        // Вычисляем угол для текущего месяца
        let monthAngle = (Double(currentMonth - 1) / Double(totalMonths)) * 2.0 * .pi
        let rotationOffset = staticArrowAngle - monthAngle

        for month in 1...totalMonths {
            let angle = (Double(month - 1) / Double(totalMonths)) * 2.0 * .pi + rotationOffset
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: orbitRadius,
                angle: angle
            )

            var textContext = context
            textContext.translateBy(x: position.x, y: position.y)
            textContext.rotate(by: Angle(radians: angle + .pi / 2))
            textContext.scaleBy(x: 0.6, y: 1.0)  // Сжимаем по ширине на 60%

            let text = Text(String(format: "%02d", month))
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced).width(.condensed))
                .foregroundColor(palette.numbers)

            textContext.draw(text, at: .zero, anchor: .center)
        }
    }

    private func drawRedRingBetweenDayAndHour(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat) {
        // Красная окружность между орбитой дней и орбитой часов (0.70)
        let ringRadius = baseRadius * 0.625  // Зазор 0.05 до часов
        let ringWidth = baseRadius * 0.01   // Узкая полоска

        let ringPath = Path(ellipseIn: CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))

        context.stroke(
            ringPath,
            with: .color(palette.arrow),
            style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
        )
    }

    private func drawDayScale(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, currentDay: Int) {
        // Орбита дней месяца: 31 день, одна строка, все цифры одинаковой высоты
        // Вращается так, чтобы текущий день был под стрелкой (270°)
        let totalDays = 31

        // Все цифры одинакового размера, как в часовой орбите
        let fontSize = baseRadius * 0.12

        // Орбита дней (зазор 0.05 до красной линии 0.625)
        let orbitRadius = baseRadius * 0.55

        // Вычисляем угол для текущего дня
        let dayAngle = (Double(currentDay - 1) / Double(totalDays)) * 2.0 * .pi
        let rotationOffset = staticArrowAngle - dayAngle

        for day in 1...totalDays {
            let angle = (Double(day - 1) / Double(totalDays)) * 2.0 * .pi + rotationOffset
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: orbitRadius,
                angle: angle
            )

            var textContext = context
            textContext.translateBy(x: position.x, y: position.y)
            textContext.rotate(by: Angle(radians: angle + .pi / 2))
            textContext.scaleBy(x: 0.6, y: 1.0)  // Сжимаем по ширине на 60%

            let text = Text(String(format: "%02d", day))
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced).width(.condensed))
                .foregroundColor(palette.numbers)

            textContext.draw(text, at: .zero, anchor: .center)
        }
    }

    private func drawHourScale(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, currentHour: Int) {
        // Часовая шкала: одна строка, все цифры одинаковой высоты, БЕЗ штрихов
        // Вращается так, чтобы текущий час был под стрелкой (270°)
        // Для 12-часового: 1-12 часов (вместо 0-11)
        // Для 24-часового: 0-23 часов
        let totalHours = use12HourFormat ? 12 : 24

        // Все цифры одинакового размера, равного большим цифрам минутной орбиты
        let fontSize = baseRadius * 0.12  // Как большие цифры в минутной орбите

        // Орбита часов (увеличенный зазор до минутной орбиты)
        let orbitRadius = baseRadius * 0.70

        // Вычисляем угол для текущего часа
        let hourToShow: Int
        if use12HourFormat {
            // В 12-часовом формате: 0->12, 1->1, 2->2, ..., 12->12, 13->1, ...
            hourToShow = (currentHour % 12 == 0) ? 12 : (currentHour % 12)
        } else {
            hourToShow = currentHour
        }

        // Позиция на циферблате (для расчета угла используем 0-based индекс)
        let hourIndex = use12HourFormat ? (hourToShow == 12 ? 0 : hourToShow) : hourToShow
        let hourAngle = (Double(hourIndex) / Double(totalHours)) * 2.0 * .pi
        let rotationOffset = staticArrowAngle - hourAngle

        for hour in 0..<totalHours {
            let angle = (Double(hour) / Double(totalHours)) * 2.0 * .pi + rotationOffset
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: orbitRadius,
                angle: angle
            )

            var textContext = context
            textContext.translateBy(x: position.x, y: position.y)
            textContext.rotate(by: Angle(radians: angle + .pi / 2))
            textContext.scaleBy(x: 0.6, y: 1.0)  // Сжимаем по ширине на 60%

            // Отображаемая цифра
            let displayHour = use12HourFormat ? (hour == 0 ? 12 : hour) : hour
            let text = Text(String(format: "%02d", displayHour))
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced).width(.condensed))
                .foregroundColor(palette.numbers)

            textContext.draw(text, at: .zero, anchor: .center)
        }
    }

    private func drawMinuteScale(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, currentMinute: Int) {
        // Минутная шкала: две строки (два радиуса)
        // Вращается так, чтобы текущая минута была под стрелкой (270°)
        // Внешняя строка - цифры, нижняя строка - штрихи
        // 0, 5, 10, 15... - большая цифра занимает ОБЕ строки, БЕЗ штрихов
        // 1, 2, 3, 4, 6, 7... - маленькая цифра на внешней строке + штрих на нижней строке
        let totalMinutes = 60

        // Размеры - абсолютные значения
        let largeFontSize = baseRadius * 0.12    // Большая цифра (увеличена для компенсации сжатия по ширине 0.6)
        let smallFontSize = baseRadius * 0.05    // Маленькая цифра
        let gapSize = baseRadius * 0.008         // Зазор между цифрой и штрихом
        let tickLength = baseRadius * 0.03       // Длина штриха
        let tickWidth = baseRadius * 0.0025      // Толщина штриха

        // Две строки орбиты (рассчитываем от центра, ближе к орбите города 0.95)
        let centerRadius = baseRadius * 0.82      // Центр между цифрами и штрихами
        let outerLineRadius = centerRadius + (smallFontSize + gapSize) / 2  // Внешняя строка (для цифр)
        let innerLineRadius = centerRadius - (gapSize + tickLength) / 2     // Нижняя строка (для штрихов)

        // Вычисляем угол для текущей минуты
        let minuteAngle = (Double(currentMinute) / 60.0) * 2.0 * .pi
        let rotationOffset = staticArrowAngle - minuteAngle

        for minute in 0..<totalMinutes {
            let is5MinuteMark = minute % 5 == 0
            let angle = (Double(minute) / 60.0) * 2.0 * .pi + rotationOffset

            if is5MinuteMark {
                // 0, 5, 10, 15... - большая цифра на обеих строках, БЕЗ штриха
                let centerRadius = (outerLineRadius + innerLineRadius) / 2
                let position = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: centerRadius,
                    angle: angle
                )

                var textContext = context
                textContext.translateBy(x: position.x, y: position.y)
                textContext.rotate(by: Angle(radians: angle + .pi / 2))
                textContext.scaleBy(x: 0.6, y: 1.0)  // Сжимаем по ширине на 60%, высота остается 100%

                let text = Text(String(format: "%02d", minute))
                    .font(.system(size: largeFontSize, weight: .semibold, design: .monospaced).width(.condensed))
                    .foregroundColor(palette.numbers)

                textContext.draw(text, at: .zero, anchor: .center)
            } else {
                // 1, 2, 3, 4, 6, 7... - маленькая цифра на внешней строке + штрих на нижней строке

                // Цифра на внешней строке
                let numberPosition = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: outerLineRadius,
                    angle: angle
                )

                var textContext = context
                textContext.translateBy(x: numberPosition.x, y: numberPosition.y)
                textContext.rotate(by: Angle(radians: angle + .pi / 2))

                let text = Text(String(format: "%02d", minute))
                    .font(.system(size: smallFontSize, weight: .regular, design: .monospaced))
                    .foregroundColor(palette.minorTicks)

                textContext.draw(text, at: .zero, anchor: .center)

                // Штрих на нижней строке
                let tickOuterPoint = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: innerLineRadius + tickLength / 2,
                    angle: angle
                )
                let tickInnerPoint = AngleCalculations.pointOnCircle(
                    center: center,
                    radius: innerLineRadius - tickLength / 2,
                    angle: angle
                )

                var path = Path()
                path.move(to: tickOuterPoint)
                path.addLine(to: tickInnerPoint)

                context.stroke(
                    path,
                    with: .color(palette.minorTicks.opacity(0.7)),
                    style: StrokeStyle(lineWidth: tickWidth, lineCap: .round)
                )
            }
        }
    }

    private func drawLocalCityOrbit(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, rotationAngle: Double) {
        let orbitRadius = baseRadius * ClockConstants.outerLabelRingRadius
        let fontSize = baseRadius * 2 * ClockConstants.labelRingFontSizeRatio
        let cityName = TimeZone.current.identifier.components(separatedBy: "/").last ?? "LOCAL"
        let characters = Array(cityName.uppercased())

        // Рисуем название города БЕЗ подложки, как в оригинале
        if !characters.isEmpty {
            let letterSpacing = Double(fontSize) * 0.8
            let totalWidth = Double(max(characters.count - 1, 0)) * letterSpacing

            // Название города центрируется над статичной стрелкой
            let startAngle = staticArrowAngle - totalWidth / (2 * Double(orbitRadius))

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

            // Рисуем зубчатую дугу на свободных участках (без подложки под текстом)
            let angularWidth = totalWidth / Double(orbitRadius)
            let padding = (Double(fontSize) * 0.8) / Double(baseRadius) * 0.7
            let occupiedStart = staticArrowAngle - angularWidth / 2 - padding
            let occupiedEnd = staticArrowAngle + angularWidth / 2 + padding

            let freeRanges = calculateFreeRanges(
                occupiedRanges: [(start: occupiedStart, end: occupiedEnd)]
            )

            for range in freeRanges where range.end > range.start {
                drawGearTeeth(
                    context: context,
                    center: center,
                    baseRadius: baseRadius,
                    orbitRadius: orbitRadius,
                    startAngle: range.start,
                    endAngle: range.end
                )
            }
        }
    }

    private func drawGearTeeth(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat, orbitRadius: CGFloat, startAngle: Double, endAngle: Double) {
        // Параметры зубчиков для орбиты города
        let segmentWidth = baseRadius * 0.1  // Ширина сегмента (полная)
        let innerRadius = orbitRadius - segmentWidth / 2  // Внутренняя граница
        let middleRadius = orbitRadius  // Средняя линия (где обычно дуга)
        let outerRadius = orbitRadius + segmentWidth / 2.2  // Зубцы выступают ещё больше наружу (увеличено)

        // Количество зубцов на данной дуге
        let arcLength = endAngle - startAngle
        let toothAngularWidth = 0.15  // Угловая ширина одного зубца (в радианах)
        let toothCount = Int(arcLength / toothAngularWidth)

        guard toothCount > 0 else { return }

        let actualToothWidth = arcLength / Double(toothCount)
        let gapRatio: CGFloat = 0.5  // 50% зубец, 50% промежуток

        var path = Path()

        // Начинаем с внутреннего радиуса
        let firstPoint = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(startAngle)),
            y: center.y + innerRadius * CGFloat(sin(startAngle))
        )
        path.move(to: firstPoint)

        // Рисуем зубчатую внешнюю линию
        for i in 0..<toothCount {
            let toothStartAngle = startAngle + Double(i) * actualToothWidth
            let toothMidAngle = toothStartAngle + actualToothWidth * Double(gapRatio) / 2
            let toothEndAngle = toothStartAngle + actualToothWidth * Double(gapRatio)
            let gapEndAngle = toothStartAngle + actualToothWidth

            // Поднимаемся на среднюю линию
            let middleStart = CGPoint(
                x: center.x + middleRadius * CGFloat(cos(toothStartAngle)),
                y: center.y + middleRadius * CGFloat(sin(toothStartAngle))
            )
            path.addLine(to: middleStart)

            // Зубец выступает наружу
            let outerMid = CGPoint(
                x: center.x + outerRadius * CGFloat(cos(toothMidAngle)),
                y: center.y + outerRadius * CGFloat(sin(toothMidAngle))
            )
            path.addLine(to: outerMid)

            // Возвращаемся на среднюю линию
            let middleEnd = CGPoint(
                x: center.x + middleRadius * CGFloat(cos(toothEndAngle)),
                y: center.y + middleRadius * CGFloat(sin(toothEndAngle))
            )
            path.addLine(to: middleEnd)

            // Дуга по средней линии до следующего зубца (промежуток)
            if i < toothCount - 1 {
                path.addArc(
                    center: center,
                    radius: middleRadius,
                    startAngle: Angle(radians: toothEndAngle),
                    endAngle: Angle(radians: gapEndAngle),
                    clockwise: false
                )
            } else {
                // Последний зубец - дуга до конца
                path.addArc(
                    center: center,
                    radius: middleRadius,
                    startAngle: Angle(radians: toothEndAngle),
                    endAngle: Angle(radians: endAngle),
                    clockwise: false
                )
            }
        }

        // Возвращаемся по внутренней дуге
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: endAngle),
            endAngle: Angle(radians: startAngle),
            clockwise: true
        )

        path.closeSubpath()

        context.fill(path, with: .color(palette.secondaryColor))
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

    private func drawArrow(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat) {
        let arrowThickness = baseRadius * 0.005  // Очень тонкая стрелка
        let arrowEndRadius = baseRadius * 0.88  // В воздухе между минутной орбитой (0.82) и орбитой города (0.95)
        let arrowEndPosition = AngleCalculations.pointOnCircle(
            center: center,
            radius: arrowEndRadius,
            angle: staticArrowAngle
        )

        var path = Path()
        path.move(to: center)
        path.addLine(to: arrowEndPosition)

        context.stroke(
            path,
            with: .color(palette.arrow),
            style: StrokeStyle(lineWidth: arrowThickness, lineCap: .round)
        )
    }

    private func drawCenterDisc(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat) {
        let radius = baseRadius * ClockConstants.centerButtonVisualRatio
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(palette.centerCircle))
    }

    private func drawGear(context: GraphicsContext, center: CGPoint, baseRadius: CGFloat) {
        // Рисуем шестерёнку с такой же геометрией как внешняя орбита
        let gearWidth = baseRadius * 0.12  // Ширина кольца шестерёнки (уменьшена)
        let middleRadius = baseRadius * 0.30  // Средняя линия
        let innerRadius = middleRadius - gearWidth / 2  // Внутренняя граница
        let outerRadius = middleRadius + gearWidth / 2.5  // Внешняя граница (зубцы выступают)
        let holeRadius = innerRadius * 0.6  // Отверстие в центре

        let toothCount = 12  // Количество зубцов (уменьшено)
        let arcLength = 2.0 * .pi
        let actualToothWidth = arcLength / Double(toothCount)
        let gapRatio: CGFloat = 0.5  // 50% зубец, 50% промежуток

        var path = Path()

        // Начинаем с внутреннего радиуса
        let firstPoint = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(Double(0))),
            y: center.y + innerRadius * CGFloat(sin(Double(0)))
        )
        path.move(to: firstPoint)

        // Рисуем зубчатую внешнюю линию
        for i in 0..<toothCount {
            let toothStartAngle = Double(i) * actualToothWidth
            let toothMidAngle = toothStartAngle + actualToothWidth * Double(gapRatio) / 2
            let toothEndAngle = toothStartAngle + actualToothWidth * Double(gapRatio)
            let gapEndAngle = toothStartAngle + actualToothWidth

            // Поднимаемся на среднюю линию
            let middleStart = CGPoint(
                x: center.x + middleRadius * CGFloat(cos(toothStartAngle)),
                y: center.y + middleRadius * CGFloat(sin(toothStartAngle))
            )
            path.addLine(to: middleStart)

            // Зубец выступает наружу
            let outerMid = CGPoint(
                x: center.x + outerRadius * CGFloat(cos(toothMidAngle)),
                y: center.y + outerRadius * CGFloat(sin(toothMidAngle))
            )
            path.addLine(to: outerMid)

            // Возвращаемся на среднюю линию
            let middleEnd = CGPoint(
                x: center.x + middleRadius * CGFloat(cos(toothEndAngle)),
                y: center.y + middleRadius * CGFloat(sin(toothEndAngle))
            )
            path.addLine(to: middleEnd)

            // Дуга по средней линии до следующего зубца (промежуток)
            if i < toothCount - 1 {
                path.addArc(
                    center: center,
                    radius: middleRadius,
                    startAngle: Angle(radians: toothEndAngle),
                    endAngle: Angle(radians: gapEndAngle),
                    clockwise: false
                )
            } else {
                // Последний зубец - дуга до конца
                path.addArc(
                    center: center,
                    radius: middleRadius,
                    startAngle: Angle(radians: toothEndAngle),
                    endAngle: Angle(radians: 2.0 * .pi),
                    clockwise: false
                )
            }
        }

        // Возвращаемся по внутренней дуге
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: 2.0 * .pi),
            endAngle: Angle(radians: 0),
            clockwise: true
        )

        path.closeSubpath()

        // Тип окраски как у внешней шестерёнки (palette.secondaryColor) в обычном режиме
        context.fill(path, with: .color(palette.secondaryColor))

        // Рисуем внутреннее отверстие
        let holePath = Path(ellipseIn: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))

        context.fill(holePath, with: .color(palette.background))
    }

    private func rotationOffset(for time: Date) -> Double {
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = components.hour, let minute = components.minute else {
            return 0
        }

        let hourToUse = use12HourFormat ? (hour % 12 == 0 ? 12 : hour % 12) : hour
        let hourValue = use12HourFormat ? Double(hourToUse) + Double(minute) / 60.0 : Double(hour) + Double(minute) / 60.0

        let baseAngle = use12HourFormat ?
            (hourValue / 12.0) * 2.0 * .pi :
            ClockConstants.calculateArrowAngle(hour24: hourValue)

        return ClockConstants.normalizeAngle(staticArrowAngle - baseAngle)
    }
}

// MARK: - Preview
#if DEBUG
struct ClockW3MediumWidget_Previews: PreviewProvider {
    static var previews: some View {
        ClockW3MediumWidgetEntryView(
            entry: MediumWidgetEntry(
                date: Date(),
                colorSchemePreference: "system",
                use12HourFormat: false
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif
