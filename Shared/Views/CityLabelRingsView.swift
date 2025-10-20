import SwiftUI

// MARK: - City Label Rings View
struct CityLabelRingsView: View {
    let size: CGSize
    let cities: [WorldCity]
    let currentTime: Date
    let palette: ClockColorPalette

    private var baseRadius: CGFloat {
        min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
    }

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

    // Параметры цветных сегментов (адаптировано из ClockW)
    private static let segmentBandWidthRatio: CGFloat = 0.1  // 4% от baseRadius
    private static let segmentAlpha: CGFloat = 1  // 85% прозрачность

    var body: some View {
        Canvas { context, size in
            let fontSize = min(size.width, size.height) * ClockConstants.labelRingFontSizeRatio

            // Используем умное распределение городов по орбитам (избегаем наложения текста)
            let result = CityOrbitDistribution.distributeCities(
                cities: cities,
                currentTime: currentTime
            )

            var outerRingCities: [WorldCity] = []
            var middleRingCities: [WorldCity] = []

            for city in cities {
                // Рисуем только города, которые успешно размещены
                guard let orbit = result.assignment[city.id] else { continue }
                if orbit == 1 {
                    outerRingCities.append(city)
                } else {
                    middleRingCities.append(city)
                }
            }

            // Рисуем цветные сегменты для внешнего кольца
            drawColorSegments(
                context: context,
                cities: outerRingCities,
                radius: baseRadius * ClockConstants.outerLabelRingRadius,
                bandWidth: baseRadius * Self.segmentBandWidthRatio,
                fontSize: fontSize,
                color: palette.secondaryColor.opacity(Self.segmentAlpha)
            )

            // Рисуем цветные сегменты для среднего кольца
            drawColorSegments(
                context: context,
                cities: middleRingCities,
                radius: baseRadius * ClockConstants.middleLabelRingRadius,
                bandWidth: baseRadius * Self.segmentBandWidthRatio,
                fontSize: fontSize,
                color: palette.secondaryColor.opacity(Self.segmentAlpha)
            )

            // Рисуем внешнее кольцо
            for city in outerRingCities {
                drawCityLabel(
                    context: context,
                    city: city,
                    radius: baseRadius * ClockConstants.outerLabelRingRadius,
                    fontSize: fontSize
                )
            }

            // Рисуем среднее кольцо
            for city in middleRingCities {
                drawCityLabel(
                    context: context,
                    city: city,
                    radius: baseRadius * ClockConstants.middleLabelRingRadius,
                    fontSize: fontSize
                )
            }
        }
    }

    // MARK: - Draw Color Segments
    private func drawColorSegments(
        context: GraphicsContext,
        cities: [WorldCity],
        radius: CGFloat,
        bandWidth: CGFloat,
        fontSize: CGFloat,
        color: Color
    ) {
        // Вычисляем занятые угловые диапазоны (где есть текст)
        var occupiedRanges: [(start: Double, end: Double)] = []

        for city in cities {
            guard let timeZone = city.timeZone else { continue }

            var calendar = Calendar.current
            calendar.timeZone = timeZone

            let hour = Double(calendar.component(.hour, from: currentTime))
            let minute = Double(calendar.component(.minute, from: currentTime))
            let hour24 = hour + minute / 60.0
            let centerAngle = ClockConstants.calculateArrowAngle(hour24: hour24)

            // Вычисляем угловую ширину текста
            let cityCode = city.iataCode
            let letterCount = cityCode.count
            let letterSpacing = fontSize * 0.8
            // ВАЖНО: используем (letterCount - 1) как при рисовании текста
            let totalWidth = CGFloat(letterCount - 1) * letterSpacing
            let angularWidth = totalWidth / radius

            // Добавляем небольшой отступ чтобы не залезать на текст
            // Используем фиксированный угловой зазор независимо от радиуса орбиты
            let padding = (fontSize * 0.8) / Double(baseRadius) * 0.7
            let startAngle = centerAngle - angularWidth / 2 - padding
            let endAngle = centerAngle + angularWidth / 2 + padding

            occupiedRanges.append((start: startAngle, end: endAngle))
        }

        // Находим свободные диапазоны
        let freeRanges = calculateFreeRanges(occupiedRanges: occupiedRanges)

        // Рисуем цветные сегменты в свободных диапазонах
        for range in freeRanges {
            let startAngle = range.start
            let endAngle = range.end

            // Создаем путь для дуги
            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startAngle),
                endAngle: Angle(radians: endAngle),
                clockwise: false
            )

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: bandWidth, lineCap: .butt)
            )
        }
    }

    // MARK: - Calculate Free Ranges
    private func calculateFreeRanges(occupiedRanges: [(start: Double, end: Double)]) -> [(start: Double, end: Double)] {
        guard !occupiedRanges.isEmpty else {
            // Если нет занятых диапазонов, вся окружность свободна
            return [(start: 0, end: 2 * .pi)]
        }

        // Нормализуем все углы к диапазону [0, 2π] и разбиваем пересекающие 0°
        var normalized: [(start: Double, end: Double)] = []

        for range in occupiedRanges {
            var start = range.start
            var end = range.end

            // Нормализуем к [0, 2π]
            while start < 0 { start += 2 * .pi }
            while start >= 2 * .pi { start -= 2 * .pi }
            while end < 0 { end += 2 * .pi }
            while end >= 2 * .pi { end -= 2 * .pi }

            // Если диапазон пересекает 0° (start > end), разбиваем на два
            if start > end {
                normalized.append((start: start, end: 2 * .pi))
                normalized.append((start: 0, end: end))
            } else {
                normalized.append((start: start, end: end))
            }
        }

        // Объединяем перекрывающиеся диапазоны
        normalized.sort { $0.start < $1.start }
        var merged: [(start: Double, end: Double)] = []

        for range in normalized {
            if merged.isEmpty {
                merged.append(range)
            } else {
                let last = merged.count - 1
                if range.start <= merged[last].end {
                    // Перекрываются - объединяем
                    merged[last].end = max(merged[last].end, range.end)
                } else {
                    merged.append(range)
                }
            }
        }

        // Находим свободные диапазоны по всей окружности [0, 2π]
        var freeRanges: [(start: Double, end: Double)] = []

        if merged.isEmpty {
            return [(start: 0, end: 2 * .pi)]
        }

        // Проверяем начало окружности (от 0 до первого занятого)
        if merged[0].start > 0 {
            freeRanges.append((start: 0, end: merged[0].start))
        }

        // Проверяем промежутки между занятыми диапазонами
        for i in 0..<(merged.count - 1) {
            let gapStart = merged[i].end
            let gapEnd = merged[i + 1].start
            if gapStart < gapEnd {
                freeRanges.append((start: gapStart, end: gapEnd))
            }
        }

        // Проверяем конец окружности (от последнего занятого до 2π)
        if merged[merged.count - 1].end < 2 * .pi {
            freeRanges.append((start: merged[merged.count - 1].end, end: 2 * .pi))
        }

        return freeRanges
    }

    private func drawCityLabel(context: GraphicsContext, city: WorldCity, radius: CGFloat, fontSize: CGFloat) {
        guard let timeZone = city.timeZone else { return }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let hour = Double(calendar.component(.hour, from: currentTime))
        let minute = Double(calendar.component(.minute, from: currentTime))
        let hour24 = hour + minute / 60.0
        let angle = ClockConstants.calculateArrowAngle(hour24: hour24)

        // Используем IATA код вместо полного названия
        let cityCode = city.iataCode
        let letters = cityCode.map { String($0) }

        // Рисуем каждую букву по дуге
        let letterSpacing = fontSize * 0.8  // Угловое расстояние между буквами
        let totalWidth = CGFloat(letters.count - 1) * letterSpacing
        let startAngle = angle - totalWidth / (2 * radius)  // Центрируем текст

        let font = Font.system(size: fontSize, weight: .regular, design: .default)

        let isLocalCity = city.timeZoneIdentifier == TimeZone.current.identifier
        let textColor = isLocalCity ? palette.arrow : palette.numbers

        for (index, letter) in letters.enumerated() {
            let letterAngle = startAngle + (CGFloat(index) * letterSpacing) / radius
            let position = AngleCalculations.pointOnCircle(
                center: center,
                radius: radius,
                angle: letterAngle
            )

            var letterContext = context
            letterContext.translateBy(x: position.x, y: position.y)

            // Поворачиваем букву "головой наружу" (перпендикулярно радиусу)
            letterContext.rotate(by: Angle(radians: letterAngle + .pi / 2))

            let text = Text(letter)
                .font(font)
                .foregroundColor(textColor)

            letterContext.draw(text, at: .zero, anchor: .center)
        }
    }
}
