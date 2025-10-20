import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Clock Face View (основной компонент циферблата)
struct ClockFaceView: View {
    @StateObject private var viewModel = SimpleClockViewModel()  // НОВАЯ ПРОСТАЯ ВЕРСИЯ!
    @State private var isDragBlocked = false
    @Environment(\.colorScheme) private var environmentColorScheme

    private enum ActiveGestureMode { case rotate, scroll }
    @State private var activeMode: ActiveGestureMode? = nil

    // Выбор городов (используем общий UserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.selectedCitiesKey,
        store: SharedUserDefaults.shared
    ) private var selectedCityIdentifiers: String = ""
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false
    @AppStorage(
        SharedUserDefaults.use12HourFormatKey,
        store: SharedUserDefaults.shared
    ) private var use12HourFormat: Bool = false
    var interactivityEnabled: Bool = true
    var overrideTime: Date? = nil  // Для виджетов - передаем время из timeline entry
    var overrideColorScheme: ColorScheme? = nil  // Для виджетов - передаем цветовую схему

    // Используем переданную схему или системную
    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
    }

    var body: some View {
        GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)
            let size = CGSize(width: minSide, height: minSide)
            let baseRadius = minSide / 2.0 * ClockConstants.clockSizeRatio
            let centerPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let currentTime = overrideTime ?? viewModel.currentTime

            let palette = ClockColorPalette.system(colorScheme: colorScheme)

            ZStack {
                // Фон приложения
                palette.background
                    .ignoresSafeArea()

                // Основной циферблат
                ZStack {
                    // Статический фон (Layer01) - НЕ ВРАЩАЕТСЯ
                    StaticBackgroundView(
                        size: size,
                        colors: palette,
                        currentTime: currentTime,
                        use12HourFormat: use12HourFormat
                    )

                    // Декоративные винты в углах
                    CornerScrewDecorationView(size: size, colorScheme: colorScheme)
                        .allowsHitTesting(false)

                    // Вращающиеся кольца с подписями городов
                    CityLabelRingsView(
                        size: size,
                        cities: viewModel.cities,
                        currentTime: viewModel.timeForArrows,
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
                        currentTime: viewModel.timeForArrows,
                        palette: palette,
                        containerRotation: viewModel.rotationAngle
                    )
                    .rotationEffect(.radians(viewModel.rotationAngle))
                    .animation(
                        viewModel.isDragging ? .none : .easeOut(duration: 0.3),
                        value: viewModel.rotationAngle
                    )
                    
                    if interactivityEnabled {
                        ZStack {
                            Circle()
                                .fill(Color.clear)
                                .frame(
                                    width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                                    height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                                )

                            // Центральный пузырь с AM/PM текстом
                            ZStack {
                                Circle()
                                    .fill(palette.centerCircle)
                                    .shadow(color: palette.centerCircle.opacity(0.4), radius: baseRadius * 0.02)

                                if use12HourFormat {
                                    let ampmText = getAMPM(for: currentTime)
                                    Text(ampmText)
                                        .font(.system(size: baseRadius * 0.05, weight: .semibold, design: .default))
                                        .foregroundColor(colorScheme == .light ? .white : .black)
                                }
                            }
                            .frame(
                                width: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio),
                                height: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio)
                            )
                        }
                        .contentShape(Circle())
                        .frame(
                            width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                            height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.7)
                                .onEnded { _ in
                                    Task {
                                        await viewModel.confirmPreviewReminder()
                                    }
                                }
                        )
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded { _ in
                                    #if os(iOS)
                                    HapticFeedback.shared.playImpact(intensity: .medium)
                                    #endif
                                    viewModel.resetRotation()
                                }
                        )
                        .accessibilityLabel("Reset rotation or hold to confirm reminder")
                    } else {
                        ZStack {
                            Circle()
                                .fill(palette.centerCircle)

                            if use12HourFormat {
                                let ampmText = getAMPM(for: currentTime)
                                Text(ampmText)
                                    .font(.system(size: baseRadius * 0.05, weight: .semibold, design: .default))
                                    .foregroundColor(colorScheme == .light ? .white : .black)
                            }
                        }
                        .frame(
                            width: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio),
                            height: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio)
                        )
                        .frame(
                            width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                            height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                        )
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
            // Высокий приоритет, но с фильтрацией направления, чтобы не мешать скроллу
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !interactivityEnabled { return }
                        if isDragBlocked { return }

                        // Первый контакт: если вне мёртвой зоны — сразу вращаем
                        if activeMode == nil {
                            let startPoint = value.startLocation
                            if isInDeadZone(point: startPoint, center: centerPoint, baseRadius: baseRadius) {
                                isDragBlocked = true
                                return
                            }
                            activeMode = .rotate
                            if !viewModel.isDragging {
                                viewModel.startDrag(at: value.startLocation, in: geometry)
                            }
                        }

                        // Обрабатываем только если выбрано вращение
                        if activeMode == .rotate {
                            viewModel.updateDrag(at: value.location, in: geometry)
                        }
                    }
                    .onEnded { _ in
                        if activeMode == .rotate, !isDragBlocked {
                            viewModel.endDrag()
                        }
                        activeMode = nil
                        isDragBlocked = false
                    }
            )
        }
        .onAppear {
            syncCitiesToViewModel()
            if interactivityEnabled {
                viewModel.resumePhysics()
            } else {
                viewModel.suspendPhysics()
            }
        }
        .onDisappear {
            // Останавливаем физику, когда экран уходит (особенно важно для виджетов/превью)
            viewModel.suspendPhysics()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            syncCitiesToViewModel()
        }
    }

    private func syncCitiesToViewModel() {
        var identifiers = selectedCityIdentifiers
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty {
            let seeded = WorldCity.initialSelectionIdentifiers()
            identifiers = seeded
            selectedCityIdentifiers = seeded.joined(separator: ",")
            hasSeededDefaults = true
        } else {
            let ensured = WorldCity.ensureLocalIdentifier(in: identifiers)
            if ensured != identifiers {
                identifiers = ensured
                selectedCityIdentifiers = ensured.joined(separator: ",")
            }
            if !identifiers.isEmpty {
                hasSeededDefaults = true
            }
        }

        let cities = WorldCity.cities(from: identifiers)
        viewModel.cities = cities
    }
    
    private func isInDeadZone(point: CGPoint, center: CGPoint, baseRadius: CGFloat) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return hypot(dx, dy) <= baseRadius * ClockConstants.deadZoneRadiusRatio
    }

    private func getAMPM(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? "AM" : "PM"
    }
}

// MARK: - Corner Decorations
struct CornerScrewDecorationView: View {
    let size: CGSize
    let colorScheme: ColorScheme

    private struct CornerDescriptor {
        let rotation: Angle
        let position: CGPoint
    }

    private static let baseAngles: [Double] = [-10, 10, -170, 170]
    private let randomOffsets: [Double]

    init(size: CGSize, colorScheme: ColorScheme) {
        self.size = size
        self.colorScheme = colorScheme

        if let stored = CornerScrewDecorationView.cachedOffsets {
            self.randomOffsets = stored
        } else {
            let offsets = (0..<4).map { _ in Double.random(in: -18...18) }
            CornerScrewDecorationView.cachedOffsets = offsets
            self.randomOffsets = offsets
        }
    }

    private static var cachedOffsets: [Double]? = nil

    private var minDimension: CGFloat {
        min(size.width, size.height)
    }

    private var nutSize: CGFloat {
        let isCircular = abs(size.width - size.height) < 10
        if isCircular {
            // Размер для циферблата
            return minDimension * 0.095 * 0.7
        } else {
            // Размер для панели настроек - в 2 раза больше
            return minDimension * 0.095 * 1.4
        }
    }

    private var cornerDescriptors: [CornerDescriptor] {
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Определяем, круглая ли это область (циферблат) или прямоугольная (панель настроек)
        let isCircular = abs(size.width - size.height) < 10

        if isCircular {
            // Для циферблата - используем старую логику (квадратное размещение)
            let diameter = minDimension * ClockConstants.clockSizeRatio
            let baseRadius = diameter / 2
            let desiredDistance = baseRadius * 1.2
            let maxDistance = max(0, (minDimension / 2 - nutSize / 2) * CGFloat(sqrt(2.0)))
            let radialDistance = min(desiredDistance, maxDistance)
            let diagonal = radialDistance / CGFloat(sqrt(2.0))

            return (0..<4).map { index in
                let baseAngle = CornerScrewDecorationView.baseAngles[index]
                let randomOffset = randomOffsets[index]
                let rotation = Angle.degrees(baseAngle + randomOffset)

                let dx = (index % 2 == 0) ? -diagonal : diagonal
                let dy = (index < 2) ? -diagonal : diagonal

                return CornerDescriptor(
                    rotation: rotation,
                    position: CGPoint(x: centerX + dx, y: centerY + dy)
                )
            }
        } else {
            // Для прямоугольной панели - фиксированные отступы от краёв плитки
            let verticalInset: CGFloat = 8 // 8pt от верха/низа плитки
            let horizontalInset: CGFloat = 16 // 16pt от левого/правого края плитки
            let horizontalOffset = size.width / 2 - horizontalInset
            let verticalOffset = size.height / 2 - verticalInset

            return (0..<4).map { index in
                let baseAngle = CornerScrewDecorationView.baseAngles[index]
                let randomOffset = randomOffsets[index]
                let rotation = Angle.degrees(baseAngle + randomOffset)

                let dx = (index % 2 == 0) ? -horizontalOffset : horizontalOffset
                let dy = (index < 2) ? -verticalOffset : verticalOffset

                return CornerDescriptor(
                    rotation: rotation,
                    position: CGPoint(x: centerX + dx, y: centerY + dy)
                )
            }
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(cornerDescriptors.enumerated()), id: \.offset) { descriptor in
                cornerScrew(rotation: descriptor.element.rotation)
                    .position(descriptor.element.position)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func cornerScrew(rotation: Angle) -> some View {
        let isLight = colorScheme == .light
        let faceFill: Color = isLight ? .black : .white
        let slotColor: Color = isLight ? .white : .black

        let slotLength = nutSize * 0.56
        let slotThickness = nutSize * 0.16
        let slotCorner = slotThickness * 0.45

        let slotHorizontal = RoundedRectangle(cornerRadius: slotCorner)
            .fill(slotColor)
            .frame(width: slotLength, height: slotThickness)

        let slotVertical = RoundedRectangle(cornerRadius: slotCorner)
            .fill(slotColor)
            .frame(width: slotThickness, height: slotLength)
        return ZStack {
            Circle()
                .fill(faceFill)
            slotHorizontal
            slotVertical
        }
        .frame(width: nutSize, height: nutSize)
        .rotationEffect(rotation)
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

    static func system(colorScheme: ColorScheme) -> ClockColorPalette {
        let fallback = fallbackPalette(for: colorScheme)

        return ClockColorPalette(
            background: colorOrFallback("ClockBackground", fallback: fallback.background),
            numbers: colorOrFallback("ClockPrimary", fallback: fallback.primary),
            hourTicks: colorOrFallback("ClockPrimary", fallback: fallback.primary),
            minorTicks: colorOrFallback("ClockSecondary", fallback: fallback.secondary),
            monthDayText: colorOrFallback("ClockAccentText", fallback: fallback.monthDayText),
            monthDayBackground: colorOrFallback("ClockAccentBackground", fallback: fallback.monthDayBackground),
            currentDayText: colorOrFallback("ClockPrimary", fallback: fallback.primary),
            weekdayText: colorOrFallback("ClockAccentText", fallback: fallback.weekdayText),
            weekdayBackground: colorOrFallback("ClockAccentBackground", fallback: fallback.weekdayBackground),
            centerCircle: colorOrFallback("ClockCenter", fallback: fallback.center),
            arrow: colorOrFallback("ClockPrimary", fallback: fallback.arrow),
            secondaryColor: colorOrFallback("ClockSecondary", fallback: fallback.secondary)
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

    private static func fallbackPalette(for colorScheme: ColorScheme) -> FallbackPalette {
        switch colorScheme {
        case .light:
            return FallbackPalette(
                background: .white,
                primary: .black,
                secondary: .black,
                monthDayText: .white,
                monthDayBackground: .black,
                weekdayText: .white,
                weekdayBackground: .black,
                center: .black,
                arrow: .red
            )
        default:
            return FallbackPalette(
                background: .black,
                primary: .white,
                secondary: .white,
                monthDayText: .black,
                monthDayBackground: .white,
                weekdayText: .black,
                weekdayBackground: .white,
                center: .white,
                arrow: .red
            )
        }
    }

    private struct FallbackPalette {
        let background: Color
        let primary: Color
        let secondary: Color
        let monthDayText: Color
        let monthDayBackground: Color
        let weekdayText: Color
        let weekdayBackground: Color
        let center: Color
        let arrow: Color
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

private extension View {
    @ViewBuilder
    func conditionalGesture<G: Gesture>(_ gesture: G, enabled: Bool) -> some View {
        if enabled {
            self.gesture(gesture)
        } else {
            self
        }
    }
}

#if DEBUG
struct ClockFaceView_Previews: PreviewProvider {
    static var previews: some View {
        ClockFaceView()
    }
}
#endif
