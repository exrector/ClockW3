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
        SmallWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallWidgetEntry) -> ()) {
        let entry = SmallWidgetEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SmallWidgetEntry] = []

        // Генерируем timeline на следующие 60 минут с обновлением каждую минуту
        let currentDate = Date()
        for minuteOffset in 0 ..< 60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = SmallWidgetEntry(date: entryDate)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry
struct SmallWidgetEntry: TimelineEntry {
    let date: Date
}

// MARK: - Widget Entry View
struct ClockW3SmallWidgetEntryView: View {
    var entry: SmallWidgetProvider.Entry
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let widgetSize = min(geometry.size.width, geometry.size.height)
            // Делаем циферблат в 2 раза больше виджета, чтобы показать ¼
            let fullClockSize = widgetSize * 2

            ZStack {
                // Фон
                Color("ClockBackground")
                    .ignoresSafeArea()

                // Полный циферблат, смещённый так чтобы:
                // - Центр был в левом НИЖНЕМ углу виджета (0, widgetSize)
                // - Виден был сегмент 12-18 часов (верхняя половина левой части циферблата)
                ClockFaceView(
                    interactivityEnabled: false,
                    overrideTime: entry.date,
                    overrideColorScheme: colorScheme
                )
                .frame(width: fullClockSize, height: fullClockSize)
                // Центр циферблата по умолчанию в (fullClockSize/2, fullClockSize/2)
                // Нужно сдвинуть центр в позицию (0, widgetSize) относительно виджета
                // offset x: 0 - fullClockSize/2 = -widgetSize
                // offset y: widgetSize - fullClockSize/2 = 0
                .position(x: 0, y: widgetSize)
            }
            .frame(width: widgetSize, height: widgetSize)
            .clipped() // Обрезаем, показывая только сегмент 12-18 часов
        }
    }
}

// MARK: - Simple Clock Hands
struct SimpleClockHands: View {
    let currentTime: Date
    let radius: CGFloat
    let centerY: CGFloat // Y координата центра (низ виджета)

    var body: some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)

        // Углы стрелок (0° = 3 часа, 90° = 6 часов, 180° = 9 часов, 270° = 12 часов)
        let hourAngle = (Double(hour % 12) * 30 + Double(minute) * 0.5) * .pi / 180
        let minuteAngle = Double(minute) * 6 * .pi / 180

        ZStack(alignment: .bottomLeading) {
            // Часовая стрелка - от левого нижнего угла
            Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                let endX = cos(hourAngle) * radius * 0.6
                let endY = centerY - sin(hourAngle) * radius * 0.6 // Минус для направления вверх
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color.primary, lineWidth: 4)

            // Минутная стрелка - от левого нижнего угла
            Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                let endX = cos(minuteAngle) * radius * 0.9
                let endY = centerY - sin(minuteAngle) * radius * 0.9 // Минус для направления вверх
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color.primary, lineWidth: 2)

            // Центр в левом нижнем углу
            Circle()
                .fill(Color.primary)
                .frame(width: 8, height: 8)
                .position(x: 0, y: centerY)
        }
    }
}

// MARK: - Quarter Clock Face (¼ циферблата)
struct QuarterClockFaceView: View {
    let radius: CGFloat
    let currentTime: Date
    let colorScheme: ColorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Круг циферблата (будет обрезан до ¼)
            Circle()
                .stroke(Color.blue, lineWidth: 4) // Синий для отладки
                .frame(width: radius * 2, height: radius * 2)
                .offset(x: -radius, y: -radius)

            // Тестовая линия от центра вправо
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: radius, y: 0))
            }
            .stroke(Color.red, lineWidth: 3)

            // Тестовая линия от центра вниз
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: radius))
            }
            .stroke(Color.green, lineWidth: 3)

            // Центральный круг для отладки
            Circle()
                .fill(Color.orange)
                .frame(width: 20, height: 20)
                .offset(x: -10, y: -10)

            // Часовые метки (будут видны только в правой нижней четверти)
            ForEach(0..<24) { hour in
                HourTickView(
                    hour: hour,
                    radius: radius,
                    isVisible: isHourInQuarter(hour)
                )
            }

            // Стрелки (только часовая и минутная)
            ClockHandsView(
                currentTime: currentTime,
                radius: radius
            )
        }
    }

    // Определяем какие часы видны в правой нижней четверти (6-12)
    private func isHourInQuarter(_ hour: Int) -> Bool {
        return hour >= 6 && hour < 12
    }
}

// MARK: - Hour Tick
struct HourTickView: View {
    let hour: Int
    let radius: CGFloat
    let isVisible: Bool

    var body: some View {
        if isVisible {
            let angle = Double(hour) * .pi / 12.0 - .pi / 2
            let tickLength: CGFloat = 12
            let tickWidth: CGFloat = 2
            let outerRadius = radius * 0.95
            let innerRadius = outerRadius - tickLength

            Path { path in
                let outerX = cos(angle) * outerRadius
                let outerY = sin(angle) * outerRadius
                let innerX = cos(angle) * innerRadius
                let innerY = sin(angle) * innerRadius

                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: outerX, y: outerY))
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: innerX, y: innerY))
            }
            .stroke(Color.primary, lineWidth: tickWidth)
        }
    }
}

// MARK: - Clock Hands
struct ClockHandsView: View {
    let currentTime: Date
    let radius: CGFloat

    var body: some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let second = calendar.component(.second, from: currentTime)

        // Углы стрелок
        let hourAngle = (Double(hour % 12) + Double(minute) / 60.0) * .pi / 6.0 - .pi / 2
        let minuteAngle = (Double(minute) + Double(second) / 60.0) * .pi / 30.0 - .pi / 2

        ZStack(alignment: .topLeading) {
            // Часовая стрелка
            HandView(
                angle: hourAngle,
                length: radius * 0.5,
                width: 6,
                color: .primary
            )

            // Минутная стрелка
            HandView(
                angle: minuteAngle,
                length: radius * 0.7,
                width: 4,
                color: .primary
            )

            // Центральный круг
            Circle()
                .fill(Color.primary)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Single Hand
struct HandView: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        let endX = cos(angle) * length
        let endY = sin(angle) * length

        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(color, lineWidth: width)
    }
}

// MARK: - Widget
struct ClockW3SmallWidget: Widget {
    let kind: String = "MOWSmallWidget"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: SmallWidgetProvider()) { entry in
            ClockW3SmallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Small")
        .description("Compact time display")
        .supportedFamilies([.systemSmall])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
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
        ClockW3SmallWidgetEntryView(entry: SmallWidgetEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
