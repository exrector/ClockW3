import SwiftUI

// MARK: - Общие функции рисования часов
struct ClockDrawingHelpers {
    
    // MARK: - Draw Static Elements
    static func drawStaticElements(
        context: GraphicsContext,
        size: CGSize,
        baseRadius: CGFloat,
        center: CGPoint,
        currentTime: Date,
        cities: [ClockCity]
    ) {
        // Фон циферблата
        var circlePath = Path()
        circlePath.addEllipse(in: CGRect(
            x: center.x - baseRadius,
            y: center.y - baseRadius,
            width: baseRadius * 2,
            height: baseRadius * 2
        ))
        context.fill(circlePath, with: .color(.black))

        // 96 тиков
        draw96Ticks(context: context, baseRadius: baseRadius, center: center)

        // 24 цифры часов
        draw24HourNumbers(context: context, size: size, baseRadius: baseRadius, center: center)

        // Два кольца с подписями городов
        drawCityLabelRings(context: context, size: size, baseRadius: baseRadius, center: center, cities: cities, currentTime: currentTime)
    }

    // MARK: - Draw 96 Ticks
    static func draw96Ticks(context: GraphicsContext, baseRadius: CGFloat, center: CGPoint) {
        for i in 0..<96 {
            let isHourTick = (i % 4 == 0)
            let isHalfHourTick = (i % 2 == 0) && !isHourTick

            let innerRadius: CGFloat
            let thickness: CGFloat
            let color: Color

            if isHourTick {
                innerRadius = baseRadius * ClockConstants.hourTickInnerRadius
                thickness = baseRadius * ClockConstants.hourTickThickness
                color = .white
            } else if isHalfHourTick {
                innerRadius = baseRadius * ClockConstants.halfHourTickInnerRadius
                thickness = baseRadius * ClockConstants.halfHourTickThickness
                color = .gray
            } else {
                innerRadius = baseRadius * ClockConstants.quarterTickInnerRadius
                thickness = baseRadius * ClockConstants.quarterTickThickness
                color = Color(white: 0.3)
            }

            let outerRadius = baseRadius * ClockConstants.tickOuterRadius
            // 96 тиков: тик 0 = 18:00 (справа), каждый тик = 15 минут = 3.75°
            let angle = CGFloat(i) * 3.75 * .pi / 180  // Начинаем с 0° (справа)

            let startPoint = pointOnCircle(center: center, radius: innerRadius, angle: angle)
            let endPoint = pointOnCircle(center: center, radius: outerRadius, angle: angle)

            var path = Path()
            path.move(to: startPoint)
            path.addLine(to: endPoint)

            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        }
    }

    // MARK: - Draw 24 Hour Numbers
    static func draw24HourNumbers(context: GraphicsContext, size: CGSize, baseRadius: CGFloat, center: CGPoint) {
        let fontSize = min(size.width, size.height) * ClockConstants.numberFontSizeRatio
        // SF Pro Text для мелких кеглей (< 20pt)
        let font = Font.system(size: fontSize, weight: .regular, design: .default)

        for hour in 1...24 {
            let angle = hourNumberAngle(hour: hour)
            let position = pointOnCircle(center: center, radius: baseRadius * ClockConstants.numberRadius, angle: angle)

            let text = String(format: "%02d", hour)

            var resolvedContext = context
            resolvedContext.translateBy(x: position.x, y: position.y)

            resolvedContext.draw(
                Text(text)
                    .font(font)
                    .foregroundColor(.white),
                at: .zero,
                anchor: .center
            )
        }
    }

    // MARK: - Draw City Label Rings
    static func drawCityLabelRings(context: GraphicsContext, size: CGSize, baseRadius: CGFloat, center: CGPoint, cities: [ClockCity], currentTime: Date) {
        guard !cities.isEmpty else { return }

        let fontSize = min(size.width, size.height) * ClockConstants.labelRingFontSizeRatio
        let font = Font.system(size: fontSize, weight: .regular, design: .default)

        // Разделяем города на две группы (четные и нечетные индексы)
        var outerRingCities: [ClockCity] = []
        var middleRingCities: [ClockCity] = []

        for (index, city) in cities.enumerated() {
            if index % 2 == 0 {
                outerRingCities.append(city)
            } else {
                middleRingCities.append(city)
            }
        }

        // Рисуем внешнее кольцо
        for city in outerRingCities {
            let angle = calculateArrowAngle(for: city, at: currentTime)
            drawCityLabelOnRing(
                context: context,
                cityName: city.name,
                angle: angle,
                radius: baseRadius * ClockConstants.outerLabelRingRadius,
                center: center,
                font: font,
                fontSize: fontSize
            )
        }

        // Рисуем среднее кольцо
        for city in middleRingCities {
            let angle = calculateArrowAngle(for: city, at: currentTime)
            drawCityLabelOnRing(
                context: context,
                cityName: city.name,
                angle: angle,
                radius: baseRadius * ClockConstants.middleLabelRingRadius,
                center: center,
                font: font,
                fontSize: fontSize
            )
        }
    }

    // MARK: - Draw City Label On Ring (вертикально вдоль радиуса, как буква Т)
    static func drawCityLabelOnRing(context: GraphicsContext, cityName: String, angle: CGFloat, radius: CGFloat, center: CGPoint, font: Font, fontSize: CGFloat) {
        let position = pointOnCircle(center: center, radius: radius, angle: angle)

        // Разбиваем название на отдельные буквы
        let letters = cityName.map { String($0) }

        // Расстояние между буквами (примерно высота буквы + отступ)
        let letterSpacing = fontSize * 0.9

        var labelContext = context
        labelContext.translateBy(x: position.x, y: position.y)

        // Поворачиваем контекст "головой наружу" (от центра)
        let textAngle = angle + .pi / 2
        labelContext.rotate(by: Angle(radians: textAngle))

        // Рисуем каждую букву вертикально
        let totalHeight = CGFloat(letters.count - 1) * letterSpacing
        var currentY = -totalHeight / 2

        for letter in letters {
            let text = Text(letter)
                .font(font)
                .foregroundColor(Color("ClockSecondary"))

            labelContext.draw(text, at: CGPoint(x: 0, y: currentY), anchor: .center)
            currentY += letterSpacing
        }
    }

    // MARK: - Draw Globe
    static func drawGlobe(context: GraphicsContext, baseRadius: CGFloat, center: CGPoint, rotationAngle: CGFloat = 0) {
        // Глобус теперь рисуется в CityArrowsView с изображением
        // Эта функция больше не используется, но оставлена для совместимости
    }

    // MARK: - Draw Rotating Elements (стрелки + подписи + weekday bubbles)
    static func drawRotatingElements(
        context: GraphicsContext,
        size: CGSize,
        baseRadius: CGFloat,
        center: CGPoint,
        rotationAngle: CGFloat,
        cities: [ClockCity],
        currentTime: Date
    ) {
        for city in cities {
            // Вычисляем угол стрелки для города
            let arrowAngle = calculateArrowAngle(for: city, at: currentTime)

            // КЛЮЧЕВОЙ МОМЕНТ: угол с учётом вращения контейнера
            let totalAngle = arrowAngle + rotationAngle

            // Рисуем стрелку
            drawCityArrow(
                context: context,
                city: city,
                angle: totalAngle,
                baseRadius: baseRadius,
                center: center
            )

            // Рисуем подпись города на середине стрелки
            drawCityLabel(
                context: context,
                city: city,
                angle: totalAngle,
                baseRadius: baseRadius,
                center: center,
                size: size
            )

            // Рисуем weekday bubble на конце стрелки
            drawWeekdayBubble(
                context: context,
                city: city,
                angle: totalAngle,
                baseRadius: baseRadius,
                center: center,
                size: size,
                currentTime: currentTime
            )
        }
    }

    // MARK: - Draw City Arrow
    static func drawCityArrow(context: GraphicsContext, city: ClockCity, angle: CGFloat, baseRadius: CGFloat, center: CGPoint) {
        let endRadius = baseRadius * ClockConstants.arrowLineEndRadius
        let endPoint = pointOnCircle(center: center, radius: endRadius, angle: angle)

        var arrowPath = Path()
        arrowPath.move(to: center)
        arrowPath.addLine(to: endPoint)

        context.stroke(
            arrowPath,
            with: .color(Color("ClockPrimary")),
            style: StrokeStyle(lineWidth: baseRadius * ClockConstants.arrowThicknessRatio, lineCap: .round)
        )
    }

    // MARK: - Draw City Label (ретина-чёткий текст на середине стрелки)
    static func drawCityLabel(context: GraphicsContext, city: ClockCity, angle: CGFloat, baseRadius: CGFloat, center: CGPoint, size: CGSize) {
        let endRadius = baseRadius * ClockConstants.arrowLineEndRadius
        let endPoint = pointOnCircle(center: center, radius: endRadius, angle: angle)
        let midPoint = CGPoint(
            x: (center.x + endPoint.x) / 2,
            y: (center.y + endPoint.y) / 2
        )

        let fontSize = min(size.width, size.height) * 0.04
        // SF Pro Text для мелких кеглей (< 20pt)
        let font = Font.system(size: fontSize, weight: .semibold, design: .default)

        var labelContext = context
        labelContext.translateBy(x: midPoint.x, y: midPoint.y)

        // Переворачиваем текст если он вверх ногами (между 90° и 270°)
        var textAngle = angle
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let positiveAngle = normalizedAngle < 0 ? normalizedAngle + 2 * .pi : normalizedAngle

        // Если угол между π/2 (90°) и 3π/2 (270°) - переворачиваем на 180°
        if positiveAngle > .pi / 2 && positiveAngle < 3 * .pi / 2 {
            textAngle += .pi  // Переворот на 180°
        }

        labelContext.rotate(by: Angle(radians: textAngle))

        let text = Text("  \(city.name)  ")
            .font(font)
            .foregroundColor(Color("ClockPrimary"))

        labelContext.draw(text, at: .zero, anchor: .center)
    }

    // MARK: - Draw Weekday Bubble
    static func drawWeekdayBubble(context: GraphicsContext, city: ClockCity, angle: CGFloat, baseRadius: CGFloat, center: CGPoint, size: CGSize, currentTime: Date) {
        let weekdayRadius = baseRadius * 1.0
        let weekdayPosition = pointOnCircle(center: center, radius: weekdayRadius, angle: angle)

        guard let timeZone = city.timeZone else { return }

        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: currentTime)

        let bubbleRadius = baseRadius * 0.035
        let fontSize = min(size.width, size.height) * 0.03
        // SF Pro Text для мелких кеглей (< 20pt)
        let font = Font.system(size: fontSize, weight: .bold, design: .default)

        var bubbleContext = context
        bubbleContext.translateBy(x: weekdayPosition.x, y: weekdayPosition.y)

        // Переворачиваем текст если он вверх ногами (между 90° и 270°)
        var textAngle = angle
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 2 * .pi)
        let positiveAngle = normalizedAngle < 0 ? normalizedAngle + 2 * .pi : normalizedAngle

        // Если угол между π/2 (90°) и 3π/2 (270°) - переворачиваем на 180°
        if positiveAngle > .pi / 2 && positiveAngle < 3 * .pi / 2 {
            textAngle += .pi  // Переворот на 180°
        }

        bubbleContext.rotate(by: Angle(radians: textAngle))

        // Фон пузыря
        var bubblePath = Path()
        bubblePath.addEllipse(in: CGRect(
            x: -bubbleRadius,
            y: -bubbleRadius,
            width: bubbleRadius * 2,
            height: bubbleRadius * 2
        ))
        bubbleContext.fill(bubblePath, with: .color(.yellow))

        // Цифра дня недели
        bubbleContext.draw(
            Text("\(weekday)")
                .font(font)
                .foregroundColor(.white),
            at: .zero,
            anchor: .center
        )
    }

    // MARK: - Helper Methods
    static func calculateArrowAngle(for city: ClockCity, at currentTime: Date) -> CGFloat {
        guard let timeZone = city.timeZone else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let hour = Double(calendar.component(.hour, from: currentTime))
        let minute = Double(calendar.component(.minute, from: currentTime))

        let hour24 = hour + minute / 60.0
        // iOS координаты: 18:00 = 0° (справа →), 12:00 = -90° (вверху ↑)
        let degrees = hour24 * 15.0 - 270.0  // 18:00 - 270° = 0° (право)
        return CGFloat(degrees) * .pi / 180.0
    }

    static func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    static func hourNumberAngle(hour: Int) -> CGFloat {
        // iOS координаты: 0° справа, Y вниз
        // 12 вверху (-90°), 18 справа (0°), 24 внизу (90°), 6 слева (180°/-180°)
        let degrees = CGFloat(hour - 18) * 15.0  // 18 = 0° (справа)
        return degrees * .pi / 180.0
    }
}