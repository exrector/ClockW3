import WidgetKit
import SwiftUI
import CoreText

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

// MARK: - Прямоугольная плитка с одной цифрой
private struct DigitTile: View {
    let digit: Int
    let tileColor: Color
    let digitColor: Color
    let bgColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r = min(6, min(w, h) * 0.08)
            let bandHeight = h * 0.68 // плитка чуть ниже
            let bandWidth = w * 0.94   // немного уже для визуального «дыхания»
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            ZStack {
                shape
                    .fill(tileColor)
                    .frame(width: bandWidth, height: bandHeight)
                    .overlay(
                        shape.stroke(digitColor.opacity(0.15), lineWidth: 1.0)
                            .frame(width: bandWidth, height: bandHeight)
                    )
                // Имитируем флип: тонкая горизонтальная полоса по центру плитки,
                // видимая везде, кроме поверх текста (текст нарисован выше и его перекрывает)
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 3.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    // Совмещаем шов на фоне со швом по цифре
                    .offset(y: digitSeamOffset(digit: digit, h: h))
                    .mask(
                        shape.fill(Color.white).frame(width: bandWidth, height: bandHeight)
                    )
                // Цифры как раньше — от высоты плитки (не трогаем)
                let baseline = glyphBaselineCenterOffset(digit: digit, fontName: ThickMonoDigit.fontName, fontSize: h * 1.35)
                ThickMonoDigit(digit: digit, size: h * 1.35, color: digitColor, baselineOffset: baseline)
                // Вторая линия поверх цифры с противоположным цветом (фон палитры),
                // маскированная формой цифры — видна только на глифе, создаёт инверсию по отношению к цифре
                Rectangle()
                    // На цифре тоже красный шов
                    .fill(Color.red)
                    .frame(height: 3.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    // Чуть подвинем «шов» для оптического выравнивания середины конкретной цифры
                    .offset(y: digitSeamOffset(digit: digit, h: h))
                    .mask(
                        // Немного расширяем контур маски по горизонтали и смягчаем край,
                        // чтобы исключить не прокрашенные субпиксельные контуры
                        ThickMonoDigit(digit: digit, size: h * 1.35, color: .white, baselineOffset: baseline)
                            .scaleEffect(x: 1.02, y: 1.0, anchor: .center)
                            .blur(radius: 0.2)
                    )
            }
            // Не клипуем по форме, чтобы цифры оставались большого размера
        }
        // Возвращаем прежнюю высоту плитки, чтобы цифры остались прежними по визуальному размеру
        .aspectRatio(0.48, contentMode: .fit)
    }

    // Оптическая подстройка вертикального центра шва для конкретных цифр Menlo-Bold
    // Значение в доле от высоты тайла (h). Положительное — вниз, отрицательное — вверх.
    private func digitSeamOffset(digit: Int, h: CGFloat) -> CGFloat {
        // Для Courier New Bold смещение не требуется — делим строго по центру
        return 0
    }
}

// Толстый моноширинный символ за счёт наложения нескольких слоёв Menlo‑Bold
private struct ThickMonoDigit: View {
    let digit: Int
    let size: CGFloat
    let color: Color
    let baselineOffset: CGFloat

    // Используем более нейтральный моноширинный шрифт с ровной геометрией
    // Доступен на iOS/macOS: Courier New Bold (PostScript: CourierNewPS-BoldMT)
    static let fontName = "CourierNewPS-BoldMT"
    // Толщина утолщения (смещение слоёв в поинтах)
    private let t: CGFloat = 1.0

    var body: some View {
        ZStack {
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: t, y: 0).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: -t, y: 0).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: 0, y: t).baselineOffset(baselineOffset)
            Text(String(digit)).font(.custom(Self.fontName, size: size)).foregroundColor(color).offset(x: 0, y: -t).baselineOffset(baselineOffset)
            // диагональные слои для ещё большей «жирности»
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

// Вычисляем вертикальное смещение baseline так, чтобы центр глифа совпал с геометрическим центром строки
private func glyphBaselineCenterOffset(digit: Int, fontName: String, fontSize: CGFloat) -> CGFloat {
    let ctFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
    // получаем глиф
    let str = String(digit) as NSString
    var glyph = CGGlyph()
    let success = withUnsafeMutablePointer(to: &glyph) { ptr -> Bool in
        var unis = [UniChar](repeating: 0, count: str.length)
        str.getCharacters(&unis, range: NSRange(location: 0, length: str.length))
        return CTFontGetGlyphsForCharacters(ctFont, &unis, ptr, str.length)
    }
    guard success else { return 0 }

    // bounding box глифа в координатах baseline
    var g = glyph
    let bbox = CTFontGetBoundingRectsForGlyphs(ctFont, .default, &g, nil, 1)
    let ascent = CTFontGetAscent(ctFont)
    let descent = CTFontGetDescent(ctFont)
    // центр строки
    let lineCenterY = (ascent - descent) / 2.0
    // центр глифа
    let glyphCenterY = bbox.midY
    // baselineOffset: положительное — вверх
    return lineCenterY - glyphCenterY
}

// MARK: - Flip Digit Building Blocks
private struct FlipDigitView: View {
    let digit: Int
    let palette: ClockColorPalette

    var body: some View {
        VStack(spacing: 1) { // очень маленький зазор между верхом и низом
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
            let fontSize = h * 1.9
            let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
            ZStack {
                shape
                    .fill(cardBackground)
                    .overlay(
                        shape.stroke(palette.numbers.opacity(0.25), lineWidth: 1)
                    )

                // Digit text; для верхней половины отрезаем нижние 40%, для нижней — верхние 40%
                Text(String(digit))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(palette.numbers)
                    .mask(
                        VStack(spacing: 0) {
                            if isTop {
                                // Верхняя половина: оставить верхние 60%
                                Rectangle().frame(height: h * 0.6)
                                Spacer(minLength: 0)
                            } else {
                                // Нижняя половина: оставить нижние 60%
                                Spacer(minLength: 0)
                                Rectangle().frame(height: h * 0.6)
                            }
                        }
                    )
                    .shadow(color: palette.numbers.opacity(0.12), radius: 1, x: 0, y: isTop ? 0.5 : -0.5)
                    .minimumScaleFactor(0.5)
                    .allowsTightening(true)
                    .lineLimit(1)
            }
            .clipShape(shape) // гарантируем, что показывается только половина цифры
            // без линии стыка — визуальный промежуток задаётся spacing между половинками
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
            GeometryReader { geo in
                let hAvail = geo.size.height
                let bg = (effectiveColorScheme == .light) ? Color.white : Color.black
                let tile = (effectiveColorScheme == .light) ? Color.black : Color.white
                let digitCol = (effectiveColorScheme == .light) ? Color.white : Color.black

                HStack(alignment: .center, spacing: 3) {
                    DigitTile(digit: hDigits[0], tileColor: tile, digitColor: digitCol, bgColor: bg)
                    DigitTile(digit: hDigits[1], tileColor: tile, digitColor: digitCol, bgColor: bg)

                    MinimalColonView(height: hAvail, color: tile)

                    DigitTile(digit: mDigits[0], tileColor: tile, digitColor: digitCol, bgColor: bg)
                    DigitTile(digit: mDigits[1], tileColor: tile, digitColor: digitCol, bgColor: bg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 0)
                .padding(.vertical, 0)

                // Рандомные символы ⊗ / ⊕ по углам виджета (детерминированно по минуте)
                let wAvail = geo.size.width
                let base = Int(entry.date.timeIntervalSince1970 / 60)
                let margin = min(wAvail, hAvail) * 0.06
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        let jx = CGFloat(((base + i * 31) % 10)) / 10.0 * margin * 0.6
                        let jy = CGFloat(((base + i * 17) % 10)) / 10.0 * margin * 0.6
                        let sym = ((base + i) % 2 == 0) ? "⊗" : "⊕"
                        let size = min(wAvail, hAvail) * 0.085
                        let pos: CGPoint = {
                            switch i {
                            case 0: return CGPoint(x: margin + jx, y: margin + jy) // TL
                            case 1: return CGPoint(x: wAvail - margin - jx, y: margin + jy) // TR
                            case 2: return CGPoint(x: margin + jx, y: hAvail - margin - jy) // BL
                            default: return CGPoint(x: wAvail - margin - jx, y: hAvail - margin - jy) // BR
                            }
                        }()
                        Text(sym)
                            .font(.system(size: size, weight: .heavy))
                            .foregroundColor(tile)
                            .position(pos)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            (effectiveColorScheme == .light) ? Color.white : Color.black
        }
    }
}

// MARK: - Widget Configuration
// Узкий двоеточие: две точки в предельно узком контейнере
private struct MinimalColonView: View {
    let height: CGFloat
    let color: Color

    var body: some View {
        let dot = max(2, height * 0.18)
        let spacing = max(1, height * 0.05)
        let width = max(2, height * 0.08)
        return VStack(spacing: spacing) {
            Circle().fill(color).frame(width: dot, height: dot)
            Circle().fill(color).frame(width: dot, height: dot)
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
struct MediumElectroWidget: Widget {
    let kind: String = "MOWMediumElectro"

    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: MediumElectroProvider()) { entry in
            MediumElectroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MOW Electro")
        .description("Large 00:00 digits in tiles")
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
