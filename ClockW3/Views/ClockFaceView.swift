import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Clock Face View (основной компонент циферблата)
struct ClockFaceView: View {
    @StateObject private var viewModel = ClockViewModel()

    // Выбор городов
    @AppStorage("selectedCityIdentifiers") private var selectedCityIdentifiers: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            let size = CGSize(
                width: min(geometry.size.width, geometry.size.height),
                height: min(geometry.size.width, geometry.size.height)
            )
            
            let palette = ClockColorPalette.system()

            ZStack {
                // Фон приложения
                palette.background
                    .ignoresSafeArea()
                
                // Основной циферблат
                ZStack {
                    // Статический фон (Layer01)
                    StaticBackgroundView(
                        size: size,
                        colors: palette,
                        currentTime: viewModel.currentTime
                    )

                    // Вращающиеся кольца с подписями городов
                    CityLabelRingsView(
                        size: size,
                        cities: viewModel.cities,
                        currentTime: viewModel.currentTime,
                        palette: palette
                    )
                    .rotationEffect(.radians(viewModel.rotationAngle))
                    .animation(
                        viewModel.isDragging ? .none : .easeOut(duration: 0.3),
                        value: viewModel.rotationAngle
                    )

                    // Вращающийся контейнер со стрелками (Layer05)
                    CityArrowsView(
                        size: size,
                        cities: viewModel.cities,
                        currentTime: viewModel.currentTime,
                        palette: palette,
                        containerRotation: viewModel.rotationAngle
                    )
                    .rotationEffect(.radians(viewModel.rotationAngle))
                    .animation(
                        viewModel.isDragging ? .none : .easeOut(duration: 0.3),
                        value: viewModel.rotationAngle
                    )
                    
                    // Центральный круг (Layer06)
                    CenterCircleView(
                        radius: min(size.width, size.height) * 0.02,
                        color: palette.centerCircle
                    )
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewModel.updateDrag(at: value.location, in: geometry)
                        }
                        .onEnded { _ in
                            viewModel.endDrag()
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if !viewModel.isDragging {
                                viewModel.startDrag(at: value.startLocation, in: geometry)
                            }
                        }
                )
            }
        }
        .onAppear {
            syncCitiesToViewModel()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            syncCitiesToViewModel()
        }
    }

    private func syncCitiesToViewModel() {
        let ids = selectedCityIdentifiers.split(separator: ",").map { String($0) }
        if ids.isEmpty {
            viewModel.cities = WorldCity.defaultCities
        } else {
            let cities = WorldCity.cities(from: ids)
            viewModel.cities = cities.isEmpty ? WorldCity.defaultCities : cities
        }
    }
}

// MARK: - Center Circle View
struct CenterCircleView: View {
    let radius: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: radius * 2, height: radius * 2)
            .shadow(color: color.opacity(0.5), radius: radius * 0.5)
    }
}

// MARK: - Palette Model
struct ClockColorPalette {
    let background: Color
    let numbers: Color
    let hourTicks: Color
    let minorTicks: Color
    let monthDayText: Color
    let monthDayBackground: Color
    let currentDayText: Color
    let weekdayText: Color
    let weekdayBackground: Color
    let centerCircle: Color
    let arrow: Color
    let secondaryColor: Color  // Для сегментов и IATA кодов

    static func system() -> ClockColorPalette {
        // Проверяем доступность Color Assets, если нет - используем fallback
        let backgroundFallback: Color = .black
        let primaryFallback: Color = .white
        let secondaryFallback: Color = .gray
        let accentTextFallback: Color = .white
        let accentBackgroundFallback: Color = .gray.opacity(0.3)
        let centerFallback: Color = .red

        return ClockColorPalette(
            background: colorOrFallback("ClockBackground", fallback: backgroundFallback),
            numbers: colorOrFallback("ClockPrimary", fallback: primaryFallback),
            hourTicks: colorOrFallback("ClockPrimary", fallback: primaryFallback),
            minorTicks: colorOrFallback("ClockSecondary", fallback: secondaryFallback),
            monthDayText: colorOrFallback("ClockAccentText", fallback: accentTextFallback),
            monthDayBackground: colorOrFallback("ClockAccentBackground", fallback: accentBackgroundFallback),
            currentDayText: colorOrFallback("ClockPrimary", fallback: primaryFallback),
            weekdayText: colorOrFallback("ClockAccentText", fallback: accentTextFallback),
            weekdayBackground: colorOrFallback("ClockAccentBackground", fallback: accentBackgroundFallback),
            centerCircle: colorOrFallback("ClockCenter", fallback: centerFallback),
            arrow: colorOrFallback("ClockPrimary", fallback: primaryFallback),
            secondaryColor: colorOrFallback("ClockSecondary", fallback: secondaryFallback)
        )
    }

    private static func colorOrFallback(_ name: String, fallback: Color) -> Color {
        // В виджетах Color Assets могут быть недоступны, используем fallback
        #if canImport(UIKit)
        if UIColor(named: name) != nil {
            return Color(name)
        }
        #elseif canImport(AppKit)
        if NSColor(named: name) != nil {
            return Color(name)
        }
        #endif
        return fallback
    }

}

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

            // Разделяем города на две группы (четные и нечетные индексы)
            var outerRingCities: [WorldCity] = []
            var middleRingCities: [WorldCity] = []

            for (index, city) in cities.enumerated() {
                if index % 2 == 0 {
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
        guard !cities.isEmpty else { return }

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
            let totalWidth = CGFloat(letterCount) * letterSpacing  // Учитываем все буквы включая первую и последнюю
            let angularWidth = totalWidth / radius

            // Добавляем небольшой отступ чтобы не залезать на текст
            let padding = letterSpacing / radius * 0.1   // Примерно одна буква с каждой стороны
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
                .foregroundColor(palette.secondaryColor)

            letterContext.draw(text, at: .zero, anchor: .center)
        }
    }
}

// MARK: - Preview
#Preview {
    ClockFaceView()
}
