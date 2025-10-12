import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit

// MARK: - UIViewRepresentable для iOS/visionOS
struct ClockViewRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> CoreGraphicsClockView {
        let clockView = CoreGraphicsClockView()
        return clockView
    }

    func updateUIView(_ uiView: CoreGraphicsClockView, context: Context) {
        // Обновление если нужно
    }
}

#elseif os(macOS)
import AppKit

// MARK: - NSViewRepresentable для macOS
struct ClockViewRepresentable: NSViewRepresentable {

    func makeNSView(context: Context) -> CoreGraphicsClockViewMac {
        let clockView = CoreGraphicsClockViewMac()
        return clockView
    }

    func updateNSView(_ nsView: CoreGraphicsClockViewMac, context: Context) {
        // Обновление если нужно
    }
}

// MARK: - macOS версия (NSView обёртка над UIView логикой)
class CoreGraphicsClockViewMac: NSView {

    private var cities: [ClockCity] = []
    private var currentTime: Date = Date()

    private var arrowLayers: [UUID: CAShapeLayer] = [:]
    private var textLayers: [UUID: CATextLayer] = [:]

    private var baseRadius: CGFloat {
        min(bounds.width, bounds.height) / 2.0 * 0.85
    }

    private var centerPoint: CGPoint {
        CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        cities = [
            ClockCity(name: "Local", timeZone: .current),
            ClockCity(name: "Beijing", timeZone: TimeZone(identifier: "Asia/Shanghai")!),
            ClockCity(name: "NYC", timeZone: TimeZone(identifier: "America/New_York")!),
            ClockCity(name: "London", timeZone: TimeZone(identifier: "Europe/London")!),
            ClockCity(name: "Tokyo", timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        ]

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTime()
        }
    }

    override func layout() {
        super.layout()
        removeAllArrowLayers()
        setupArrowLayers()
        updateTime()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        drawClockBackground(in: ctx)
        drawTicks(in: ctx)
        drawHourNumbers(in: ctx)
        drawMonthDays(in: ctx)
        drawGlobe(in: ctx)
    }

    // Копируем все методы отрисовки из UIView версии
    private func drawClockBackground(in ctx: CGContext) {
        ctx.setFillColor(NSColor.black.cgColor)

        let circlePath = NSBezierPath(
            ovalIn: CGRect(
                x: centerPoint.x - baseRadius,
                y: centerPoint.y - baseRadius,
                width: baseRadius * 2,
                height: baseRadius * 2
            )
        )

        ctx.addPath(circlePath.cgPath)
        ctx.fillPath()
    }

    private func drawTicks(in ctx: CGContext) {
        for i in 0..<96 {
            let isHourTick = (i % 4 == 0)
            let isHalfHourTick = (i % 2 == 0) && !isHourTick

            let innerRadius: CGFloat
            let thickness: CGFloat
            let color: NSColor

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

    private func drawHourNumbers(in ctx: CGContext) {
        let fontSize = bounds.width * 0.05
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
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

    private func drawMonthDays(in ctx: CGContext) {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: currentTime)
        let fontSize = bounds.width * 0.04
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        for day in 1...31 {
            let angle = dayAngle(day: day)
            let position = pointOnCircle(center: centerPoint, radius: baseRadius * 0.93, angle: angle)

            let isCurrentDay = (day == currentDay)

            if isCurrentDay {
                ctx.setFillColor(NSColor.white.cgColor)
                let bubbleRadius = baseRadius * 0.06
                ctx.fillEllipse(in: CGRect(
                    x: position.x - bubbleRadius,
                    y: position.y - bubbleRadius,
                    width: bubbleRadius * 2,
                    height: bubbleRadius * 2
                ))
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isCurrentDay ? NSColor.black : NSColor.lightGray
            ]

            let text = String(format: "%02d", day)
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()

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

    private func drawGlobe(in ctx: CGContext) {
        let globeRadius = baseRadius * 0.62

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [
            NSColor.systemBlue.withAlphaComponent(0.3).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.1).cgColor,
            NSColor.clear.cgColor
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

    private func setupArrowLayers() {
        guard let layer = self.layer else { return }

        for city in cities {
            let arrowLayer = CAShapeLayer()
            arrowLayer.lineWidth = baseRadius * 0.01
            arrowLayer.strokeColor = NSColor.systemBlue.cgColor
            arrowLayer.lineCap = .round
            arrowLayer.fillColor = NSColor.clear.cgColor
            layer.addSublayer(arrowLayer)
            arrowLayers[city.id] = arrowLayer

            let textLayer = CATextLayer()
            textLayer.string = city.name
            textLayer.fontSize = baseRadius * 0.08
            textLayer.font = NSFont.systemFont(ofSize: baseRadius * 0.08, weight: .semibold)
            textLayer.foregroundColor = NSColor.systemBlue.cgColor
            textLayer.backgroundColor = NSColor.black.cgColor
            textLayer.cornerRadius = baseRadius * 0.02
            textLayer.alignmentMode = .center
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

            let textSize = (city.name as NSString).size(withAttributes: [
                .font: NSFont.systemFont(ofSize: baseRadius * 0.08, weight: .semibold)
            ])
            textLayer.bounds = CGRect(
                x: 0, y: 0,
                width: textSize.width + baseRadius * 0.1,
                height: textSize.height + baseRadius * 0.04
            )

            layer.addSublayer(textLayer)
            textLayers[city.id] = textLayer
        }
    }

    func updateTime() {
        currentTime = Date()

        for city in cities {
            let angle = calculateArrowAngle(for: city)
            updateArrow(for: city, angle: angle)
        }

        needsDisplay = true
    }

    private func updateArrow(for city: ClockCity, angle: CGFloat) {
        guard let arrowLayer = arrowLayers[city.id],
              let textLayer = textLayers[city.id] else { return }

        let endRadius = baseRadius * 0.7
        let endPoint = pointOnCircle(center: centerPoint, radius: endRadius, angle: angle)

        let path = NSBezierPath()
        path.move(to: centerPoint)
        path.line(to: endPoint)
        arrowLayer.path = path.cgPath

        let midPoint = CGPoint(
            x: (centerPoint.x + endPoint.x) / 2,
            y: (centerPoint.y + endPoint.y) / 2
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textLayer.position = midPoint
        textLayer.transform = CATransform3DMakeRotation(angle - .pi / 2, 0, 0, 1)
        CATransaction.commit()
    }

    private func removeAllArrowLayers() {
        arrowLayers.values.forEach { $0.removeFromSuperlayer() }
        textLayers.values.forEach { $0.removeFromSuperlayer() }
        arrowLayers.removeAll()
        textLayers.removeAll()
    }

    private func calculateArrowAngle(for city: ClockCity) -> CGFloat {
        guard let timeZone = city.timeZone else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let hour = Double(calendar.component(.hour, from: currentTime))
        let minute = Double(calendar.component(.minute, from: currentTime))

        let hour24 = hour + minute / 60.0
        let degrees = hour24 * 15.0 - 18.0 * 15.0
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

// Расширение для NSBezierPath -> CGPath
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

#endif
