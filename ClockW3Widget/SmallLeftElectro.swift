import WidgetKit
import SwiftUI
import CoreText

// MARK: - Timeline Provider (per minute)
struct SmallLeftElectroProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallLeftElectroEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return SmallLeftElectroEntry(date: Date(), colorSchemePreference: "system", use12HourFormat: use12Hour)
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallLeftElectroEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        completion(.init(date: Date(), colorSchemePreference: colorPref, use12HourFormat: use12Hour))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmallLeftElectroEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)

        var entries: [SmallLeftElectroEntry] = []
        let now = Date()
        let cal = Calendar.current
        let currentSecond = cal.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = cal.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = SmallLeftElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60))))
            return
        }

        // Немедленная запись
        entries.append(SmallLeftElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour))

        // На час вперёд, обновление каждую минуту
        for offset in 0..<60 {
            let entryDate = cal.date(byAdding: .minute, value: offset, to: nextMinuteStart)!
            entries.append(SmallLeftElectroEntry(date: entryDate, colorSchemePreference: colorPref, use12HourFormat: use12Hour))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Entry
struct SmallLeftElectroEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let use12HourFormat: Bool
}

// MARK: - Helper: thick mono digit (Courier New Bold)
private struct LeftThickMonoDigit: View {
    let digit: Int
    let size: CGFloat
    let color: Color
    let baselineOffset: CGFloat

    // Строгий гротеск: Helvetica Neue Bold (с моноширинными цифрами)
    static let fontName = "HelveticaNeue-Bold"
    private let t: CGFloat = 1.0

    var body: some View {
        ZStack {
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: t, y: 0).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: -t, y: 0).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: 0, y: t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: 0, y: -t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: t, y: t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: -t, y: t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: t, y: -t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: -t, y: -t).baselineOffset(baselineOffset)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
        .monospacedDigit()
    }
}

private func leftGlyphBaselineCenterOffset(digit: Int, fontName: String, fontSize: CGFloat) -> CGFloat {
    let ctFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
    let str = String(digit) as NSString
    var glyph = CGGlyph()
    let success = withUnsafeMutablePointer(to: &glyph) { ptr -> Bool in
        var unis = [UniChar](repeating: 0, count: str.length)
        str.getCharacters(&unis, range: NSRange(location: 0, length: str.length))
        return CTFontGetGlyphsForCharacters(ctFont, &unis, ptr, str.length)
    }
    guard success else { return 0 }
    var g = glyph
    let bbox = CTFontGetBoundingRectsForGlyphs(ctFont, .default, &g, nil, 1)
    let ascent = CTFontGetAscent(ctFont)
    let descent = CTFontGetDescent(ctFont)
    let lineCenterY = (ascent - descent) / 2.0
    let glyphCenterY = bbox.midY
    return lineCenterY - glyphCenterY
}

// MARK: - Tile
private struct LeftDigitTile: View {
    let digit: Int
    let tileColor: Color
    let digitColor: Color
    var seamColor: Color = .red

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = min(6, min(w, h) * 0.1)
            let bandHeight = h * 0.72
            let bandWidth = w
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            ZStack {
                shape
                    .fill(tileColor)
                    .frame(width: bandWidth, height: bandHeight)
                    .overlay(
                        shape.stroke(digitColor.opacity(0.15), lineWidth: 1.0)
                            .frame(width: bandWidth, height: bandHeight)
                    )
                let baseline = leftGlyphBaselineCenterOffset(digit: digit, fontName: LeftThickMonoDigit.fontName, fontSize: h * 1.35)
                LeftThickMonoDigit(digit: digit, size: h * 1.35, color: digitColor, baselineOffset: baseline)
                Rectangle()
                    .fill(seamColor)
                    .frame(width: bandWidth, height: 3.6)
            }
        }
        .aspectRatio(0.48, contentMode: .fit)
    }
}

// MARK: - Widget View (hours only)
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLeftElectroWidgetEntryView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    #endif
    var entry: SmallLeftElectroProvider.Entry

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
        let (h, _) = hourMinute(from: entry.date)
        let hString = String(format: "%02d", h)
        let hDigits = hString.compactMap { Int(String($0)) }

        // Общая палитра для согласованного фона
        let palette = ClockColorPalette.system(colorScheme: effectiveColorScheme)

        ZStack {
            GeometryReader { geo in
                let hAvail = geo.size.height
                let wAvail = geo.size.width

                #if os(macOS)
                let isFullColor = widgetRenderingMode == .fullColor
                // В fullColor используем контрастные плитки и цифры
                let tile = isFullColor
                    ? ((effectiveColorScheme == .light) ? Color.black : Color.white)
                    : Color.white.opacity(0.28) // В non-fullColor — светлые полупрозрачные плитки на Material
                let digitCol = isFullColor
                    ? ((effectiveColorScheme == .light) ? Color.white : Color.black)
                    : Color.white // В non-fullColor — белые цифры для лучшей читаемости
                let seamCol = isFullColor ? Color.red : Color.white.opacity(0.85)
                #else
                // На iOS/iPadOS всегда fullColor
                let isFullColor = true
                let tile = (effectiveColorScheme == .light) ? Color.black : Color.white
                let digitCol = (effectiveColorScheme == .light) ? Color.white : Color.black
                let seamCol = Color.red
                #endif

                let tileW = hAvail * 0.48
                ZStack {
                    HStack(alignment: .center, spacing: 3) {
                        LeftDigitTile(digit: hDigits[0], tileColor: tile, digitColor: digitCol, seamColor: seamCol)
                            .frame(width: tileW)
                        LeftDigitTile(digit: hDigits[1], tileColor: tile, digitColor: digitCol, seamColor: seamCol)
                            .frame(width: tileW)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    // AM/PM сверху по центру (если 12h)
                    if entry.use12HourFormat {
                        let hour24 = Calendar.current.component(.hour, from: entry.date)
                        let ampm = hour24 >= 12 ? "PM hours" : "AM hours"
                        Text(ampm)
                            .font(.system(size: hAvail * 0.096, weight: .heavy, design: .monospaced))
                            .foregroundColor(isFullColor ? tile : digitCol)
                            .position(x: wAvail / 2, y: hAvail * 0.06)
                    }

                    // Угловые декоративные символы (светлые/тёмные в зависимости от режима)
                    let base = Int(entry.date.timeIntervalSince1970 / 60)
                    let rawSize = min(wAvail, hAvail) * 0.085
                    let size = max(10, rawSize)
                    let margin = size * 1.0
                    ZStack {
                        let highlight = (base * 7) % 4
                        let symbols: [String] = (0..<4).map { idx in idx == highlight ? "⊕" : "⊗" }
                        // Left side screws only (top-left and bottom-left)
                        Text(symbols[0]).font(.system(size: size, weight: .heavy)).foregroundColor(isFullColor ? tile : digitCol).position(x: margin, y: margin)
                        Text(symbols[2]).font(.system(size: size, weight: .heavy)).foregroundColor(isFullColor ? tile : digitCol).position(x: margin, y: hAvail - margin)
                    }
                }
            }
        }
        #if os(macOS)
        .widgetBackground(widgetRenderingMode == .fullColor ? palette.background : palette.background)
        #else
        .widgetBackground(palette.background)
        #endif
    }
}

// MARK: - Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallLeftElectroWidget: Widget {
    let kind: String = "MOWSmallLeftElectro"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: SmallLeftElectroProvider()) { entry in
            SmallLeftElectroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("StandBy Left mode")
        .description("Hours only flip tiles")
        .supportedFamilies([.systemSmall])

        // The enclosing type already requires these OS versions, so we can unconditionally apply the modifier.
        return configuration.contentMarginsDisabled()
    }
}
