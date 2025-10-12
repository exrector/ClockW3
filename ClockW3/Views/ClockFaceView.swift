import SwiftUI

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
                        currentTime: viewModel.currentTime
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

    static func system() -> ClockColorPalette {
        ClockColorPalette(
            background: Color("ClockBackground"),
            numbers: Color("ClockPrimary"),
            hourTicks: Color("ClockPrimary"),
            minorTicks: Color("ClockSecondary"),
            monthDayText: Color("ClockAccentText"),
            monthDayBackground: Color("ClockAccentBackground"),
            currentDayText: Color("ClockPrimary"),
            weekdayText: Color("ClockAccentText"),
            weekdayBackground: Color("ClockAccentBackground"),
            centerCircle: Color("ClockCenter"),
            arrow: Color("ClockPrimary")
        )
    }

}

// MARK: - City Label Rings View
struct CityLabelRingsView: View {
    let size: CGSize
    let cities: [WorldCity]
    let currentTime: Date

    private var baseRadius: CGFloat {
        min(size.width, size.height) / 2.0 * ClockConstants.clockSizeRatio
    }

    private var center: CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }

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
                .foregroundColor(Color("ClockSecondary"))

            letterContext.draw(text, at: .zero, anchor: .center)
        }
    }
}

// MARK: - Preview
#Preview {
    ClockFaceView()
}
