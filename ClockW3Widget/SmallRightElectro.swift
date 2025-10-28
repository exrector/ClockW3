import WidgetKit
import SwiftUI
import CoreText

// MARK: - Timeline Provider (per minute)
struct SmallRightElectroProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmallRightElectroEntry {
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        return SmallRightElectroEntry(date: Date(), colorSchemePreference: "system", use12HourFormat: use12Hour)
    }

    func getSnapshot(in context: Context, completion: @escaping (SmallRightElectroEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)
        completion(.init(date: Date(), colorSchemePreference: colorPref, use12HourFormat: use12Hour))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmallRightElectroEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let use12Hour = SharedUserDefaults.shared.bool(forKey: SharedUserDefaults.use12HourFormatKey)

        var entries: [SmallRightElectroEntry] = []
        let now = Date()
        let cal = Calendar.current
        let currentSecond = cal.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond

        guard let nextMinuteStart = cal.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = SmallRightElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour)
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60))))
            return
        }

        entries.append(SmallRightElectroEntry(date: now, colorSchemePreference: colorPref, use12HourFormat: use12Hour))
        for offset in 0..<60 {
            let entryDate = cal.date(byAdding: .minute, value: offset, to: nextMinuteStart)!
            entries.append(SmallRightElectroEntry(date: entryDate, colorSchemePreference: colorPref, use12HourFormat: use12Hour))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Entry
struct SmallRightElectroEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
    let use12HourFormat: Bool
}

// MARK: - Helper: thick mono digit (Courier New Bold)
private struct RightThickMonoDigit: View {
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

private func rightGlyphBaselineCenterOffset(digit: Int, fontName: String, fontSize: CGFloat) -> CGFloat {
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
private struct RightDigitTile: View {
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
                let baseline = rightGlyphBaselineCenterOffset(digit: digit, fontName: RightThickMonoDigit.fontName, fontSize: h * 1.35)
                RightThickMonoDigit(digit: digit, size: h * 1.35, color: digitColor, baselineOffset: baseline)
                Rectangle()
                    .fill(seamColor)
                    .frame(width: bandWidth, height: 3.6)
            }
        }
        .aspectRatio(0.48, contentMode: .fit)
    }
}

// MARK: - Widget View (minutes only)
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallRightElectroWidgetEntryView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    #endif
    var entry: SmallRightElectroProvider.Entry

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
        let (_, m) = hourMinute(from: entry.date)
        let mString = String(format: "%02d", m)
        let mDigits = mString.compactMap { Int(String($0)) }

        ZStack {
            GeometryReader { geo in
                let hAvail = geo.size.height
                let wAvail = geo.size.width

                #if os(macOS)
                let isFullColor = widgetRenderingMode == .fullColor
                let tile = isFullColor
                    ? ((effectiveColorScheme == .light) ? Color.black : Color.white)
                    : Color.white.opacity(0.3)  // Неактивный режим: полупрозрачные плитки для vibrant эффекта
                let digitCol = isFullColor
                    ? ((effectiveColorScheme == .light) ? Color.white : Color.black)
                    : Color.black  // Неактивный режим: черные цифры на полупрозрачных плитках
                let seamCol = isFullColor ? Color.red : Color.black  // Неактивный режим: черный шов
                #else
                let isFullColor = true
                let tile = (effectiveColorScheme == .light) ? Color.black : Color.white
                let digitCol = (effectiveColorScheme == .light) ? Color.white : Color.black
                let seamCol = Color.red
                #endif

                let tileW = hAvail * 0.48
                ZStack {
                    HStack(alignment: .center, spacing: 3) {
                        RightDigitTile(digit: mDigits[0], tileColor: tile, digitColor: digitCol, seamColor: seamCol)
                            .frame(width: tileW)
                        RightDigitTile(digit: mDigits[1], tileColor: tile, digitColor: digitCol, seamColor: seamCol)
                            .frame(width: tileW)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    // AM/PM сверху по центру (если 12h)
                    if entry.use12HourFormat {
                        let hour24 = Calendar.current.component(.hour, from: entry.date)
                        let ampm = hour24 >= 12 ? "PM minutes" : "AM minutes"
                        Text(ampm)
                            .font(.system(size: hAvail * 0.096, weight: .heavy, design: .monospaced))
                            .foregroundColor(isFullColor ? tile : digitCol)
                            .position(x: wAvail / 2, y: hAvail * 0.06)
                    }

                    // Угловые декоративные символы (ч/б по теме)
                    let base = Int(entry.date.timeIntervalSince1970 / 60)
                    let rawSize = min(wAvail, hAvail) * 0.085
                    let size = max(10, rawSize)
                    let margin = size * 1.0
                    ZStack {
                        let highlight = (base * 7) % 4
                        let symbols: [String] = (0..<4).map { idx in idx == highlight ? "⊕" : "⊗" }
                        // Right side screws only (top-right and bottom-right)
                        Text(symbols[1]).font(.system(size: size, weight: .heavy)).foregroundColor(isFullColor ? tile : digitCol).position(x: wAvail - margin, y: margin)
                        Text(symbols[3]).font(.system(size: size, weight: .heavy)).foregroundColor(isFullColor ? tile : digitCol).position(x: wAvail - margin, y: hAvail - margin)
                    }
                }
            }
        }
        #if os(macOS)
        .widgetBackground(widgetRenderingMode == .fullColor
            ? ((effectiveColorScheme == .light) ? Color.white : Color.black)
            : ((effectiveColorScheme == .light) ? Color.white : Color.black))
        #else
        .widgetBackground((effectiveColorScheme == .light) ? Color.white : Color.black)
        #endif
    }
}

// MARK: - Configuration
@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct SmallRightElectroWidget: Widget {
    let kind: String = "MOWSmallRightElectro"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: SmallRightElectroProvider()) { entry in
            SmallRightElectroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("StandBy Right mode")
        .description("Minutes only flip tiles")
        .supportedFamilies([.systemSmall])

        // The enclosing type already requires these OS versions, so we can unconditionally apply the modifier.
        return configuration.contentMarginsDisabled()
    }
}
