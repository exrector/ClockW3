import WidgetKit
import SwiftUI

// MARK: - Timeline Provider (per minute)
struct MediumElectroProvider: TimelineProvider {
    func placeholder(in context: Context) -> MediumElectroEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return MediumElectroEntry(date: Date(), colorSchemePreference: "system", use12HourFormat: use12Hour)
    }

    func getSnapshot(in context: Context, completion: @escaping (MediumElectroEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        completion(.init(date: Date(), colorSchemePreference: colorPref, use12HourFormat: use12Hour))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MediumElectroEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)

        var entries: [MediumElectroEntry] = []
        let now = Date()
        let cal = Calendar.current
        let currentSecond = cal.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = cal.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = MediumElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60))))
            return
        }

        // Immediate entry
        entries.append(MediumElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour))

        // Next 60 minutes
        for offset in 0..<60 {
            let entryDate = cal.date(byAdding: .minute, value: offset, to: nextMinuteStart)!
            entries.append(MediumElectroEntry(date: entryDate, colorSchemePreference: colorPref, use12HourFormat: use12Hour))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Entry
struct MediumElectroEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let use12HourFormat: Bool
}

// MARK: - Flip Digit Building Blocks
private struct FlipDigitView: View {
    let digit: Int
    let palette: ClockColorPalette

    var body: some View {
        VStack(spacing: 3) {
            FlipHalfView(digit: digit, isTop: true, palette: palette)
            FlipHalfView(digit: digit, isTop: false, palette: palette)
        }
    }
}

private struct FlipHalfView: View {
    let digit: Int
    let isTop: Bool
    let palette: ClockColorPalette

    private var cardBackground: LinearGradient {
        let base = palette.numbers.opacity(0.08)
        return LinearGradient(colors: [base.opacity(0.9), base.opacity(0.7)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let r = min(8, h * 0.18)
            let fontSize = h * 1.9 // big enough to show half of the numeral
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            ZStack {
                shape
                    .fill(cardBackground)
                    .overlay(
                        shape.stroke(palette.numbers.opacity(0.25), lineWidth: 1)
                    )

                // Digit text clipped by the half container, vertically offset
                Text(String(digit))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(palette.numbers)
                    .offset(y: (isTop ? -h * 0.52 : h * 0.52))
                    .shadow(color: palette.numbers.opacity(0.12), radius: 1, x: 0, y: isTop ? 0.5 : -0.5)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .lineLimit(1)
            }
            .clipShape(shape) // гарантируем, что показывается только половина цифры
            .overlay(
                VStack(spacing: 0) {
                    if isTop {
                        Spacer()
                        // линия «разреза» между верхней и нижней половинками
                        Rectangle()
                            .fill(palette.numbers.opacity(0.18))
                            .frame(height: 1)
                    } else {
                        Rectangle()
                            .fill(palette.numbers.opacity(0.25))
                            .frame(height: 1)
                        Spacer()
                    }
                }
            )
        }
        .aspectRatio(0.7, contentMode: .fit)
    }
}

private struct FlipColonView: View {
    let palette: ClockColorPalette

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(palette.numbers)
                .frame(width: 14, height: 14)
                .shadow(color: palette.numbers.opacity(0.15), radius: 1)
            Circle()
                .fill(palette.numbers)
                .frame(width: 14, height: 14)
                .shadow(color: palette.numbers.opacity(0.15), radius: 1)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Main View
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumElectroWidgetEntryView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    var entry: MediumElectroProvider.Entry

    private var effectiveColorScheme: ColorScheme {
        switch entry.colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return systemColorScheme
        }
    }

    private func hourMinute(from date: Date) -> (Int, Int) {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        if entry.use12HourFormat {
            let hour12 = h % 12 == 0 ? 12 : h % 12
            return (hour12, m)
        } else {
            return (h, m)
        }
    }

    var body: some View {
        let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)
        let (h, m) = hourMinute(from: entry.date)
        let hString = String(format: "%02d", h)
        let mString = String(format: "%02d", m)
        let hDigits = hString.compactMap { Int(String($0)) }
        let mDigits = mString.compactMap { Int(String($0)) }

        ZStack {
            // Full-bleed background handled by containerBackground
            HStack(alignment: .center, spacing: 8) {
                // Left: 4 rectangles (2 digits × 2 halves)
                VStack(spacing: 3) {
                    FlipHalfView(digit: hDigits[0], isTop: true, palette: palette)
                    FlipHalfView(digit: hDigits[0], isTop: false, palette: palette)
                }
                VStack(spacing: 3) {
                    FlipHalfView(digit: hDigits[1], isTop: true, palette: palette)
                    FlipHalfView(digit: hDigits[1], isTop: false, palette: palette)
                }

                // Center: colon
                FlipColonView(palette: palette)

                // Right: 4 rectangles (2 digits × 2 halves)
                VStack(spacing: 3) {
                    FlipHalfView(digit: mDigits[0], isTop: true, palette: palette)
                    FlipHalfView(digit: mDigits[0], isTop: false, palette: palette)
                }
                VStack(spacing: 3) {
                    FlipHalfView(digit: mDigits[1], isTop: true, palette: palette)
                    FlipHalfView(digit: mDigits[1], isTop: false, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .containerBackground(for: .widget) {
            palette.background
        }
    }
}

// MARK: - Widget Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumElectroWidget: Widget {
    let kind: String = "MOWMediumElectro"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: MediumElectroProvider()) { entry in
            MediumElectroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Electro")
        .description("Flip clock style")
        .supportedFamilies([.systemMedium])

        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    MediumElectroWidget()
} timeline: {
    MediumElectroEntry(date: .now, colorSchemePreference: "system", use12HourFormat: false)
}
