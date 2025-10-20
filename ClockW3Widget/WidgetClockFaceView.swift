import SwiftUI

/// Неподвижная версия циферблата для виджета — использует только данные из timeline entry.
struct WidgetClockFaceView: View {
    let date: Date
    let colorScheme: ColorScheme

    private var palette: ClockColorPalette {
        ClockColorPalette.system(colorScheme: colorScheme)
    }

    private var use12HourFormat: Bool {
        SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
    }

    private var cities: [WorldCity] {
        let stored = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.selectedCitiesKey) ?? ""
        var identifiers = stored
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty {
            identifiers = WorldCity.initialSelectionIdentifiers()
        } else {
            identifiers = WorldCity.ensureLocalIdentifier(in: identifiers)
        }

        return WorldCity.cities(from: identifiers)
    }

    private func getAMPM(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? "AM" : "PM"
    }

    var body: some View {
        GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)
            let size = CGSize(width: minSide, height: minSide)
            let baseRadius = minSide / 2.0 * ClockConstants.clockSizeRatio

            ZStack {
                palette.background
                    .ignoresSafeArea()

                ZStack {
                    StaticBackgroundView(
                        size: size,
                        colors: palette,
                        currentTime: date,
                        use12HourFormat: use12HourFormat
                    )

                    // Декоративные винты в углах
                    CornerScrewDecorationView(size: size, colorScheme: colorScheme)
                        .allowsHitTesting(false)

                    CityLabelRingsView(
                        size: size,
                        cities: cities,
                        currentTime: date,
                        palette: palette
                    )

                    CityArrowsView(
                        size: size,
                        cities: cities,
                        currentTime: date,
                        minutesOffset: 0,
                        palette: palette,
                        containerRotation: 0
                    )

                    ZStack {
                        Circle()
                            .fill(palette.centerCircle)

                        if use12HourFormat {
                            let ampmText = getAMPM(for: date)
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
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .allowsHitTesting(false)
    }
}
