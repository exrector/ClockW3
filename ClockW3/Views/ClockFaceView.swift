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

// MARK: - Preview
#Preview {
    ClockFaceView()
}
