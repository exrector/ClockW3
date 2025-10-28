import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Неподвижная версия циферблата для виджета — использует только данные из timeline entry.
struct WidgetClockFaceView: View {
    let date: Date
    let colorScheme: ColorScheme
    var palette: ClockColorPalette? = nil
    #if os(macOS)
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    #endif

    private var effectivePalette: ClockColorPalette {
        // Если палитра передана извне - используем её
        if let palette = palette {
            return palette
        }
        // Иначе - используем стандартную для платформы
        #if os(macOS)
        return ClockColorPalette.forMacWidget(colorScheme: colorScheme)
        #else
        return ClockColorPalette.system(colorScheme: colorScheme)
        #endif
    }

    // Лёгкий тон для светлой темы на desktop-виджетах macOS (не fullColor),
    // чтобы избежать «чисто белого» фона циферблата.
    private var macInactiveOverlayColor: Color? {
        #if os(macOS)
        if widgetRenderingMode != .fullColor {
            return colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.06)
        }
        #endif
        return nil
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
                ZStack {
                    // Подложка под циферблат только для desktop-режима macOS,
                    // чтобы фон не был чисто белым/чёрным.
                    if let overlay = macInactiveOverlayColor {
                        Circle()
                            .fill(overlay)
                            .frame(width: baseRadius * 2, height: baseRadius * 2)
                    }

                    StaticBackgroundView(
                        size: size,
                        colors: effectivePalette,
                        currentTime: date,
                        use12HourFormat: use12HourFormat
                    )

                    CityLabelRingsView(
                        size: size,
                        cities: cities,
                        currentTime: date,
                        palette: effectivePalette
                    )

                    CityArrowsView(
                        size: size,
                        cities: cities,
                        currentTime: date,
                        minutesOffset: 0,
                        palette: effectivePalette,
                        containerRotation: 0
                    )

                    ZStack {
                        Circle()
                            .fill(effectivePalette.centerCircle)

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

                // Декоративные винты в углах - поверх всего
                #if os(macOS)
                if widgetRenderingMode == .fullColor {
                    CornerScrewDecorationView(size: size, colorScheme: colorScheme)
                        .allowsHitTesting(false)
                } else {
                    // Неактивный режим - простые unicode символы
                    let base = Int(date.timeIntervalSince1970 / 60)
                    let screwSize = max(10, min(size.width, size.height) * 0.085)
                    let margin = screwSize * 1.0
                    let highlight = (base * 7) % 4
                    let symbols: [String] = (0..<4).map { idx in idx == highlight ? "⊕" : "⊗" }
                    ZStack {
                        Text(symbols[0]).font(.system(size: screwSize, weight: .heavy)).foregroundColor(.black).position(x: margin, y: margin)
                        Text(symbols[1]).font(.system(size: screwSize, weight: .heavy)).foregroundColor(.black).position(x: size.width - margin, y: margin)
                        Text(symbols[2]).font(.system(size: screwSize, weight: .heavy)).foregroundColor(.black).position(x: margin, y: size.height - margin)
                        Text(symbols[3]).font(.system(size: screwSize, weight: .heavy)).foregroundColor(.black).position(x: size.width - margin, y: size.height - margin)
                    }
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                }
                #else
                CornerScrewDecorationView(size: size, colorScheme: colorScheme)
                    .allowsHitTesting(false)
                #endif
            }
        }
        .allowsHitTesting(false)
    }
}
