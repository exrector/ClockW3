import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

        #if os(macOS)
        // На macOS используем прозрачный фон для циферблата, чтобы показывался Material фон виджета
        let clockBackground: Color = .clear
        #else
        let clockBackground = colorOrFallback("ClockBackground", fallback: fallback.background)
        #endif

        return ClockColorPalette(
            background: clockBackground,
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

    #if os(macOS)
    /// Monochrome style tuned for macOS Desktop widgets:
    /// - Transparent widget background (container provides Material)
    /// - White content for maximum visibility on gray Material background
    static func forMacWidget(colorScheme: ColorScheme) -> ClockColorPalette {
        // Используем явно белый цвет для элементов на сером Material-фоне
        let primary: Color = .white
        let secondary: Color = .white.opacity(0.6)
        return ClockColorPalette(
            background: .clear,
            numbers: primary,
            hourTicks: primary,
            minorTicks: secondary,
            monthDayText: primary,
            monthDayBackground: .clear,
            currentDayText: primary,
            weekdayText: primary,
            weekdayBackground: .clear,
            centerCircle: primary.opacity(0.85),
            arrow: primary,
            secondaryColor: secondary
        )
    }
    #endif

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
                background: Color(white: 0.15),  // Темно-серый вместо черного
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
