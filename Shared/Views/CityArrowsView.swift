import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - City Arrows View (портированный Layer05)
struct CityArrowsView: View {
    let size: CGSize
    let cities: [WorldCity]
    let currentTime: Date
    let palette: ClockColorPalette
    let containerRotation: Double
    
    private var baseRadius: CGFloat {
        min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
    }
    
    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
    
    var body: some View {
        let snapshots = CityArrowsView.buildSnapshots(for: cities, currentTime: currentTime)

        return ZStack {
            // Глобус временно отключен
            // GlobeView(baseRadius: baseRadius)
            ForEach(snapshots) { snapshot in
                CityArrowView(
                    snapshot: snapshot,
                    baseRadius: baseRadius,
                    center: center,
                    containerRotation: containerRotation,
                    arrowColor: palette.arrow,
                    labelColor: palette.weekdayText,
                    labelBackgroundColor: palette.weekdayBackground,
                    weekdayNumberColor: palette.weekdayText,
                    weekdayBackgroundColor: palette.weekdayBackground
                )
            }
        }
    }
}

// MARK: - Angle Helpers & Snapshot
fileprivate func normalizePi(_ a: Double) -> Double {
    atan2(sin(a), cos(a))
}

extension CityArrowsView {
    struct CitySnapshot: Identifiable {
        let city: WorldCity
        let angle: Double
        let dayOfMonth: Int

        var id: UUID { city.id }
    }

    static func buildSnapshots(for cities: [WorldCity], currentTime: Date) -> [CitySnapshot] {
        guard !cities.isEmpty else { return [] }
        let referenceSeconds = currentTime.timeIntervalSince1970
        var calendar = Calendar(identifier: .gregorian)

        return cities.compactMap { city in
            guard let timeZone = city.timeZone else { return nil }
            let offset = TimeInterval(timeZone.secondsFromGMT(for: currentTime))
            let localSeconds = referenceSeconds + offset
            let hour24 = localSeconds / 3600.0
            let angle = ClockConstants.calculateArrowAngle(hour24: hour24)

            calendar.timeZone = timeZone
            let dayOfMonth = calendar.component(.day, from: currentTime)

            return CitySnapshot(city: city, angle: angle, dayOfMonth: dayOfMonth)
        }
    }
}

// MARK: - Single City Arrow View
struct CityArrowView: View {
    let snapshot: CityArrowsView.CitySnapshot
    let baseRadius: CGFloat
    let center: CGPoint
    let containerRotation: Double
    let arrowColor: Color
    let labelColor: Color
    let labelBackgroundColor: Color
    let weekdayNumberColor: Color
    let weekdayBackgroundColor: Color
    
    private var city: WorldCity { snapshot.city }
    private var arrowAngle: Double { snapshot.angle }
    private var dayOfMonth: Int { snapshot.dayOfMonth }
    
    private var arrowStartPosition: CGPoint {
        // Стрелка должна выходить строго из центра
        center
    }

    private var arrowEndPosition: CGPoint {
        AngleCalculations.pointOnCircle(
            center: center,
            radius: baseRadius * ClockConstants.arrowLineEndRadius,
            angle: arrowAngle
        )
    }
    
    private var weekdayPosition: CGPoint {
        AngleCalculations.pointOnCircle(
            center: center,
            radius: baseRadius * ClockConstants.weekdayNumberRadius,
            angle: arrowAngle
        )
    }
    
    var body: some View {
        ZStack {
            // Линия стрелки (без разрыва)
            ArrowLineView(
                center: arrowStartPosition,
                endPosition: arrowEndPosition,
                color: arrowColor,
                thickness: baseRadius * ClockConstants.arrowThicknessRatio
            )

            // День месяца на конце стрелки
            MonthDayBubbleView(
                position: weekdayPosition,
                dayOfMonth: dayOfMonth,
                angle: arrowAngle,
                containerRotation: containerRotation,
                bubbleRadius: baseRadius * ClockConstants.weekdayBubbleRadiusRatio,
                fontSize: baseRadius * 2 * ClockConstants.weekdayFontSizeRatio,
                textColor: weekdayNumberColor,
                backgroundColor: weekdayBackgroundColor
            )
        }
    }
    
    private var size: CGSize {
        CGSize(width: baseRadius * 2, height: baseRadius * 2)
    }
}

// MARK: - Arrow Line View
struct ArrowLineView: View {
    let center: CGPoint
    let endPosition: CGPoint
    let color: Color
    let thickness: CGFloat

    var body: some View {
        Path { path in
            path.move(to: center)
            path.addLine(to: endPosition)
        }
        .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

// MARK: - Arrow Line With Break View
struct ArrowLineWithBreakView: View {
    let startPosition: CGPoint
    let endPosition: CGPoint
    let cityName: String
    let fontSize: CGFloat
    let color: Color
    let thickness: CGFloat

    private var midPosition: CGPoint {
        CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: (startPosition.y + endPosition.y) / 2
        )
    }

    private var breakSize: CGFloat {
        let count = max(cityName.count, 1)
        let verticalHeight = CGFloat(count) * fontSize * 0.9 + CGFloat(max(count - 1, 0)) * fontSize * 0.1
        return max(fontSize * 3.5, verticalHeight + fontSize * 0.8)
    }

    private var firstSegmentEnd: CGPoint {
        let dx = endPosition.x - startPosition.x
        let dy = endPosition.y - startPosition.y
        let distance = hypot(dx, dy)
        let ratio = (distance / 2 - breakSize / 2) / distance

        return CGPoint(
            x: startPosition.x + dx * ratio,
            y: startPosition.y + dy * ratio
        )
    }

    private var secondSegmentStart: CGPoint {
        let dx = endPosition.x - startPosition.x
        let dy = endPosition.y - startPosition.y
        let distance = hypot(dx, dy)
        let ratio = (distance / 2 + breakSize / 2) / distance

        return CGPoint(
            x: startPosition.x + dx * ratio,
            y: startPosition.y + dy * ratio
        )
    }

    var body: some View {
        Path { path in
            // Первый сегмент (от начала до разрыва)
            path.move(to: startPosition)
            path.addLine(to: firstSegmentEnd)

            // Второй сегмент (от разрыва до конца)
            path.move(to: secondSegmentStart)
            path.addLine(to: endPosition)
        }
        .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

// MARK: - City Label View
struct CityLabelView: View {
    let cityName: String
    let startPosition: CGPoint
    let endPosition: CGPoint
    let angle: Double
    let containerRotation: Double
    let fontSize: CGFloat
    let textColor: Color
    let backgroundColor: Color

    private var midPosition: CGPoint {
        CGPoint(
            x: (startPosition.x + endPosition.x) / 2,
            y: (startPosition.y + endPosition.y) / 2
        )
    }

    var body: some View {
        let glyphs = cityName.map { String($0) }
        let labelAngle = angle + Double.pi / 2

        return VStack(spacing: -fontSize * 0.15) {
            ForEach(glyphs.indices, id: \.self) { index in
                Text(glyphs[index])
                    .font(.system(size: fontSize * 0.7, weight: .light, design: .default))
                    .foregroundColor(textColor)
            }
        }
        .rotationEffect(.radians(labelAngle))
        .position(midPosition)
    }
}

// MARK: - Month Day Bubble View
struct MonthDayBubbleView: View {
    let position: CGPoint
    let dayOfMonth: Int
    let angle: Double
    let containerRotation: Double
    let bubbleRadius: CGFloat
    let fontSize: CGFloat
    let textColor: Color
    let backgroundColor: Color

    @State private var displayedAngle: Double = 0
    @State private var hasAppeared = false

    var body: some View {
        let targetAngle = angle + Double.pi / 2

        return ZStack {
            // Фон пузыря
            Circle()
                .fill(backgroundColor)
                .frame(width: bubbleRadius * 2, height: bubbleRadius * 2)

            // Цифра дня месяца
            Text(String(format: "%02d", dayOfMonth))
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(textColor)
                .rotationEffect(.radians(displayedAngle))
        }
        .position(position)
        .onAppear {
            displayedAngle = targetAngle
            hasAppeared = true
        }
        .onChange(of: targetAngle) { newValue in
            let continuous = displayedAngle + normalizePi(newValue - displayedAngle)
            if hasAppeared {
                withAnimation(.easeInOut(duration: 0.28)) {
                    displayedAngle = continuous
                }
            } else {
                displayedAngle = continuous
                hasAppeared = true
            }
        }
    }

    private func normalizePi(_ a: Double) -> Double {
        return atan2(sin(a), cos(a))
    }
}

// MARK: - Globe View
struct GlobeView: View {
    let baseRadius: CGFloat
    
    var body: some View {
        ZStack {
            // Попытка загрузить изображение глобуса
            if let globeImage = loadGlobeImage() {
                globeImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: baseRadius * ClockConstants.globeRadius * 2,
                        height: baseRadius * ClockConstants.globeRadius * 2
                    )
                    .clipShape(Circle())
                    .opacity(0.6)
            } else {
                // Надежный fallback: символ глобуса + мягкий фон
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.25), Color.green.opacity(0.15), Color.clear]),
                                center: .center,
                                startRadius: 0,
                                endRadius: baseRadius * ClockConstants.globeRadius
                            )
                        )
                    Image(systemName: "globe.americas.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.blue.opacity(0.55))
                        .padding(baseRadius * 0.10)
                }
                .frame(
                    width: baseRadius * ClockConstants.globeRadius * 2,
                    height: baseRadius * ClockConstants.globeRadius * 2
                )
            }
        }
    }

    private func loadGlobeImage() -> Image? {
        #if canImport(UIKit)
        if let uiImage = UIImage(named: "Globe") {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(named: "Globe") {
            return Image(nsImage: nsImage)
        }
        #endif
        return nil
    }
}

// MARK: - Simple Continents View (Fallback)
struct SimpleContinentsView: View {
    let radius: CGFloat

    var body: some View {
        // Пустая заглушка - континенты больше не рисуются
        EmptyView()
    }
}

// MARK: - Preview
#Preview {
    CityArrowsView(
        size: CGSize(width: 400, height: 400),
        cities: WorldCity.defaultCities,
        currentTime: Date(),
        palette: ClockColorPalette.system(),
        containerRotation: 0
    )
}
