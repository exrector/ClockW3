#if os(iOS) || os(visionOS)
import UIKit
typealias PlatformView = UIView
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
#elseif os(macOS)
import AppKit
typealias PlatformView = NSView
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
#endif

// MARK: - Core Graphics Clock View
#if os(iOS) || os(visionOS)
class CoreGraphicsClockView: UIView {

    // MARK: - Properties
    private var cities: [ClockCity] = []
    private var currentTime: Date = Date()

    // MARK: - Rotating Container (ключевой элемент для вращения)
    private var rotatingContainer: CALayer!

    private var arrowLayers: [String: CAShapeLayer] = [:]
    private var textLayers: [String: CATextLayer] = [:]
    private var weekdayLayers: [String: CALayer] = [:]  // Контейнеры для weekday bubble + text

    // MARK: - Physics Properties
    private var angularVelocity: CGFloat = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?
    private let angularDamping: CGFloat = 0.985
    private let snapVelocityThreshold: CGFloat = 0.08

    // MARK: - Magnetic tick properties
    private let hourTickStep: CGFloat = 15 * .pi / 180          // 15° per hour
    private let halfHourTickStep: CGFloat = 7.5 * .pi / 180     // 7.5° per half hour
    private let quarterHourTickStep: CGFloat = 3.75 * .pi / 180 // 3.75° per quarter hour
    private var lastHourTickIndex: Int? = nil
    private var lastHalfTickIndex: Int? = nil

    // MARK: - Gesture Properties
    private var isDragging = false
    private var previousDragAngle: CGFloat = 0
    private var touchHistory: [(time: TimeInterval, angle: CGFloat)] = []

    private var baseRadius: CGFloat {
        min(bounds.width, bounds.height) / 2.0 * 0.85
    }

    private var centerPoint: CGPoint {
        CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .black

        // Создаём вращающийся контейнер
        rotatingContainer = CALayer()
        rotatingContainer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        rotatingContainer.bounds = bounds
        layer.addSublayer(rotatingContainer)

        // Дефолтные города (используем основную модель ClockCity)
        cities = [
            ClockCity(name: "Local", timeZone: .current),
            ClockCity(name: "Beijing", timeZoneIdentifier: "Asia/Shanghai"),
            ClockCity(name: "NYC", timeZoneIdentifier: "America/New_York"),
            ClockCity(name: "London", timeZoneIdentifier: "Europe/London"),
            ClockCity(name: "Tokyo", timeZoneIdentifier: "Asia/Tokyo")
        ]

        // Таймер для обновления времени (каждую минуту)
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }

        // Добавляем gesture recognizer для вращения
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(panGesture)

        // Запускаем CADisplayLink для плавной физики
        displayLink = CADisplayLink(target: self, selector: #selector(updatePhysics))
        displayLink?.add(to: .main, forMode: .common)
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        // Пересоздаём слои при изменении размера
        removeAllArrowLayers()
        setupArrowLayers()
        updateTime()
    }

    // MARK: - Drawing Static Elements (Core Graphics)
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Фон часов
        drawClockBackground(in: ctx)

        // 96 тиков
        drawTicks(in: ctx)

        // 24 цифры часов
        drawHourNumbers(in: ctx)

        // Дни месяца
        drawMonthDays(in: ctx)

        // Центральный глобус
        drawGlobe(in: ctx)
    }
}

// MARK: - Draw Clock Background (общие методы для обеих платформ)
extension CoreGraphicsClockView {
    private func drawClockBackground(in ctx: CGContext) {
        ctx.setFillColor(PlatformColor.black.cgColor)

        #if os(iOS) || os(visionOS)
        let circlePath = UIBezierPath(
            arcCenter: centerPoint,
            radius: baseRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        ctx.addPath(circlePath.cgPath)
        #elseif os(macOS)
        ctx.addEllipse(in: CGRect(
            x: centerPoint.x - baseRadius,
            y: centerPoint.y - baseRadius,
            width: baseRadius * 2,
            height: baseRadius * 2
        ))
        #endif
        ctx.fillPath()
    }

    // MARK: - Draw Ticks (96)
    private func drawTicks(in ctx: CGContext) {
        for i in 0..<96 {
            let isHourTick = (i % 4 == 0)
            let isHalfHourTick = (i % 2 == 0) && !isHourTick

            let innerRadius: CGFloat
            let thickness: CGFloat
            let color: PlatformColor

            if isHourTick {
                innerRadius = baseRadius * 0.78
                thickness = baseRadius * 0.011
                color = .white
            } else if isHalfHourTick {
                innerRadius = baseRadius * 0.8
                thickness = baseRadius * 0.0073
                color = .gray
            } else {
                innerRadius = baseRadius * 0.82
                thickness = baseRadius * 0.0045
                color = .darkGray
            }

            let outerRadius = baseRadius * 0.85
            let angle = CGFloat(i - 72) * 3.75 * .pi / 180

            let startPoint = pointOnCircle(center: centerPoint, radius: innerRadius, angle: angle)
            let endPoint = pointOnCircle(center: centerPoint, radius: outerRadius, angle: angle)

            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(thickness)
            ctx.setLineCap(.round)

            ctx.move(to: startPoint)
            ctx.addLine(to: endPoint)
            ctx.strokePath()
        }
    }

    // MARK: - Draw Hour Numbers (24)
    private func drawHourNumbers(in ctx: CGContext) {
        let fontSize = bounds.width * 0.05
        let font = PlatformFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PlatformColor.white
        ]

        for hour in 1...24 {
            let angle = hourNumberAngle(hour: hour)
            let position = pointOnCircle(center: centerPoint, radius: baseRadius * 0.70, angle: angle)

            let text = String(format: "%02d", hour)
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()

            let textRect = CGRect(
                x: position.x - textSize.width / 2,
                y: position.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            attributedText.draw(in: textRect)
        }
    }

    // MARK: - Draw Month Days
    private func drawMonthDays(in ctx: CGContext) {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: currentTime)
        let fontSize = bounds.width * 0.04
        let font = PlatformFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        for day in 1...31 {
            let angle = dayAngle(day: day)
            let position = pointOnCircle(center: centerPoint, radius: baseRadius * 0.93, angle: angle)

            let isCurrentDay = (day == currentDay)

            // Фон для текущего дня
            if isCurrentDay {
                ctx.setFillColor(PlatformColor.white.cgColor)
                let bubbleRadius = baseRadius * 0.06
                ctx.fillEllipse(in: CGRect(
                    x: position.x - bubbleRadius,
                    y: position.y - bubbleRadius,
                    width: bubbleRadius * 2,
                    height: bubbleRadius * 2
                ))
            }

            // Текст дня
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isCurrentDay ? PlatformColor.black : PlatformColor.lightGray
            ]

            let text = String(format: "%02d", day)
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()

            // Поворот текста
            ctx.saveGState()
            ctx.translateBy(x: position.x, y: position.y)
            ctx.rotate(by: angle - .pi / 2)

            let textRect = CGRect(
                x: -textSize.width / 2,
                y: -textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )

            attributedText.draw(in: textRect)
            ctx.restoreGState()
        }
    }

    // MARK: - Draw Globe
    private func drawGlobe(in ctx: CGContext) {
        let globeRadius = baseRadius * 0.62

        // Градиент
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            PlatformColor.systemBlue.withAlphaComponent(0.3).cgColor,
            PlatformColor.systemBlue.withAlphaComponent(0.1).cgColor,
            PlatformColor.clear.cgColor
        ] as CFArray

        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1])!

        ctx.saveGState()
        ctx.addEllipse(in: CGRect(
            x: centerPoint.x - globeRadius,
            y: centerPoint.y - globeRadius,
            width: globeRadius * 2,
            height: globeRadius * 2
        ))
        ctx.clip()

        ctx.drawRadialGradient(
            gradient,
            startCenter: centerPoint,
            startRadius: 0,
            endCenter: centerPoint,
            endRadius: globeRadius,
            options: []
        )

        ctx.restoreGState()
    }

    // MARK: - Setup Arrow Layers (CAShapeLayer + CATextLayer)
    private func setupArrowLayers() {
        for city in cities {
            // CAShapeLayer для стрелки
            let arrowLayer = CAShapeLayer()
            arrowLayer.lineWidth = baseRadius * 0.01
            arrowLayer.strokeColor = city.platformColor.cgColor
            arrowLayer.lineCap = .round
            arrowLayer.fillColor = PlatformColor.clear.cgColor
            rotatingContainer.addSublayer(arrowLayer)  // ДОБАВЛЯЕМ В ROTATING CONTAINER!
            arrowLayers[city.id.uuidString] = arrowLayer

            // CATextLayer для подписи города (РЕТИНА-ЧЁТКИЙ!)
            let textLayer = CATextLayer()
            textLayer.string = city.name
            textLayer.fontSize = baseRadius * 0.08
            textLayer.font = PlatformFont.systemFont(ofSize: baseRadius * 0.08, weight: .semibold)
            textLayer.foregroundColor = city.platformColor.cgColor
            textLayer.backgroundColor = PlatformColor.black.cgColor
            textLayer.cornerRadius = baseRadius * 0.02
            textLayer.alignmentMode = .center

            #if os(iOS) || os(visionOS)
            textLayer.contentsScale = UIScreen.main.scale
            #elseif os(macOS)
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            #endif

            let textSize = (city.name as NSString).size(withAttributes: [
                .font: PlatformFont.systemFont(ofSize: baseRadius * 0.08, weight: .semibold)
            ])
            textLayer.bounds = CGRect(
                x: 0, y: 0,
                width: textSize.width + baseRadius * 0.1,
                height: textSize.height + baseRadius * 0.04
            )

            rotatingContainer.addSublayer(textLayer)
            textLayers[city.id.uuidString] = textLayer
        }
    }

    // MARK: - Update Time
    func updateTime() {
        currentTime = Date()

        for city in cities {
            let angle = calculateArrowAngle(for: city)
            updateArrow(for: city, angle: angle)
        }

        // Перерисовываем только дни месяца
        setNeedsDisplay()
    }

    // MARK: - Update Arrow (CALayer Animation)
    private func updateArrow(for city: ClockCity, angle: CGFloat) {
        guard let arrowLayer = arrowLayers[city.id.uuidString],
              let textLayer = textLayers[city.id.uuidString] else { return }

        let endRadius = baseRadius * 0.7

        // ВАЖНО: координаты ВНУТРИ rotatingContainer - центр в (0, 0)
        let containerCenter = CGPoint.zero
        let endPoint = pointOnCircle(center: containerCenter, radius: endRadius, angle: angle)

        // Обновляем путь стрелки (от центра контейнера)
        let path = CGMutablePath()
        path.move(to: containerCenter)
        path.addLine(to: endPoint)
        arrowLayer.path = path

        // Позиция текста (середина стрелки)
        let midPoint = CGPoint(
            x: (containerCenter.x + endPoint.x) / 2,
            y: (containerCenter.y + endPoint.y) / 2
        )

        // Обновляем позицию и поворот текста через CATransaction (без анимации мерцания)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.position = midPoint
        textLayer.transform = CATransform3DMakeRotation(angle - .pi / 2, 0, 0, 1)
        CATransaction.commit()

        // Weekday bubble на конце стрелки
        updateWeekdayBubble(for: city, angle: angle)
    }

    // MARK: - Weekday Bubble
    private func updateWeekdayBubble(for city: ClockCity, angle: CGFloat) {
        // Weekday bubbles будут добавлены в setupArrowLayers
    }

    // MARK: - Pan Gesture Handler
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

        switch gesture.state {
        case .began:
            isDragging = true
            previousDragAngle = atan2(location.y - center.y, location.x - center.x)
            touchHistory.removeAll()
            angularVelocity = 0

        case .changed:
            let currentAngle = atan2(location.y - center.y, location.x - center.x)
            var angleDelta = currentAngle - previousDragAngle

            // Normalize to [-π, π]
            angleDelta = atan2(sin(angleDelta), cos(angleDelta))

            // Поворачиваем контейнер
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            rotatingContainer.transform = CATransform3DRotate(rotatingContainer.transform, angleDelta, 0, 0, 1)
            CATransaction.commit()

            previousDragAngle = currentAngle

            // Сохраняем историю для velocity
            let currentTime = CACurrentMediaTime()
            touchHistory.append((time: currentTime, angle: currentAngle))
            if touchHistory.count > 6 {
                touchHistory.removeFirst()
            }

        case .ended, .cancelled:
            isDragging = false

            // Вычисляем velocity из истории
            if touchHistory.count >= 2 {
                let last = touchHistory.last!
                let first = touchHistory.first!
                let timeDelta = last.time - first.time

                if timeDelta > 0.01 {
                    var angleDelta = last.angle - first.angle
                    angleDelta = atan2(sin(angleDelta), cos(angleDelta))
                    angularVelocity = CGFloat(angleDelta / timeDelta)
                }
            }

            touchHistory.removeAll()

        default:
            break
        }
    }

    // MARK: - Physics Update (CADisplayLink)
    @objc private func updatePhysics() {
        let currentAngle = getCurrentRotationAngle()

        // Magnetic attraction (всегда активно)
        applyMagneticAttraction(currentAngle: currentAngle)

        // Haptic feedback при пересечении тиков
        checkTickHaptics(currentAngle: currentAngle)

        guard !isDragging else { return }

        // Применяем damping
        angularVelocity *= angularDamping

        // Если скорость мала - snap к ближайшему тику
        if abs(angularVelocity) < snapVelocityThreshold {
            snapToNearestTick(currentAngle: currentAngle)
            angularVelocity = 0
            return
        }

        // Применяем вращение
        let deltaTime: CGFloat = 1.0 / 60.0  // Assuming 60 FPS
        let angleChange = angularVelocity * deltaTime

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rotatingContainer.transform = CATransform3DRotate(rotatingContainer.transform, angleChange, 0, 0, 1)
        CATransaction.commit()
    }

    // MARK: - Get Current Rotation Angle
    private func getCurrentRotationAngle() -> CGFloat {
        if let presentation = rotatingContainer.presentation() {
            return atan2(presentation.transform.m12, presentation.transform.m11)
        }
        return atan2(rotatingContainer.transform.m12, rotatingContainer.transform.m11)
    }

    // MARK: - Magnetic Attraction
    private func applyMagneticAttraction(currentAngle: CGFloat) {
        guard isDragging else { return }

        // Притяжение к часовым тикам (сильнее всего)
        let nearestHourTick = round(currentAngle / hourTickStep) * hourTickStep
        if abs(currentAngle - nearestHourTick) < (1.5 * .pi / 180) {
            let delta = nearestHourTick - currentAngle
            let attraction = delta * 0.12
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            rotatingContainer.transform = CATransform3DRotate(rotatingContainer.transform, attraction, 0, 0, 1)
            CATransaction.commit()
            return
        }

        // Притяжение к получасовым тикам
        let nearestHalfTick = round(currentAngle / halfHourTickStep) * halfHourTickStep
        if abs(currentAngle - nearestHalfTick) < (1.2 * .pi / 180) {
            let delta = nearestHalfTick - currentAngle
            let attraction = delta * 0.10
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            rotatingContainer.transform = CATransform3DRotate(rotatingContainer.transform, attraction, 0, 0, 1)
            CATransaction.commit()
            return
        }

        // Притяжение к четвертьчасовым тикам (слабее всего)
        let nearestQuarterTick = round(currentAngle / quarterHourTickStep) * quarterHourTickStep
        if abs(currentAngle - nearestQuarterTick) < (1.0 * .pi / 180) {
            let delta = nearestQuarterTick - currentAngle
            let attraction = delta * 0.08
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            rotatingContainer.transform = CATransform3DRotate(rotatingContainer.transform, attraction, 0, 0, 1)
            CATransaction.commit()
        }
    }

    // MARK: - Snap to Nearest Tick
    private func snapToNearestTick(currentAngle: CGFloat) {
        let nearestTick = round(currentAngle / quarterHourTickStep) * quarterHourTickStep
        let delta = nearestTick - currentAngle

        if abs(delta) > 0.001 {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            let newTransform = CATransform3DMakeRotation(nearestTick, 0, 0, 1)
            rotatingContainer.transform = newTransform
            CATransaction.commit()

            #if os(iOS)
            ClockHaptics.shared.playImpact(strength: .heavy)
            #endif
        }
    }

    // MARK: - Tick Haptics
    private func checkTickHaptics(currentAngle: CGFloat) {
        #if os(iOS)
        // Часовые тики (приоритет)
        let hourIndex = Int(round(currentAngle / hourTickStep))
        if let last = lastHourTickIndex {
            if hourIndex != last {
                ClockHaptics.shared.playImpact(strength: .heavy)
                lastHourTickIndex = hourIndex
            }
        } else {
            lastHourTickIndex = hourIndex
        }

        // Получасовые тики
        let halfIndex = Int(round(currentAngle / halfHourTickStep))
        if let last = lastHalfTickIndex {
            if halfIndex != last {
                ClockHaptics.shared.playImpact(strength: .medium)
                lastHalfTickIndex = halfIndex
            }
        } else {
            lastHalfTickIndex = halfIndex
        }
        #endif
    }

    // MARK: - Remove Layers
    private func removeAllArrowLayers() {
        arrowLayers.values.forEach { $0.removeFromSuperlayer() }
        textLayers.values.forEach { $0.removeFromSuperlayer() }
        arrowLayers.removeAll()
        textLayers.removeAll()
    }

    // MARK: - Helper Methods
    private func calculateArrowAngle(for city: ClockCity) -> CGFloat {
        guard let timeZone = city.timeZone else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: timeZone, from: currentTime)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)

        let hour24 = hour + minute / 60.0
        let degrees = hour24 * 15.0 - 18.0 * 15.0  // 18:00 = 0°
        return -CGFloat(degrees) * .pi / 180.0
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }

    private func hourNumberAngle(hour: Int) -> CGFloat {
        return -CGFloat(hour - 18) * 15.0 * .pi / 180.0
    }

    private func dayAngle(day: Int) -> CGFloat {
        let degreesPerSector = 360.0 / 31.0
        let offset = Double(12 - 1) * degreesPerSector + degreesPerSector / 2
        return CGFloat((-Double(day - 1) * degreesPerSector + offset + 90) * .pi / 180.0)
    }
}
#endif

// MARK: - ClockCity PlatformColor Extension
extension ClockCity {
    var platformColor: PlatformColor {
        // Используем ClockPrimary цвет для всех стрелок
        #if os(iOS) || os(visionOS)
        return PlatformColor(named: "ClockPrimary") ?? .label
        #elseif os(macOS)
        return PlatformColor(named: "ClockPrimary") ?? .labelColor
        #endif
    }
}

