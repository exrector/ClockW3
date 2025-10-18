import SwiftUI

struct MediumLineRibbonView: View {
    let date: Date
    let colorScheme: ColorScheme

    private var cities: [WorldCity] {
        let idsString = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.selectedCitiesKey) ?? ""
        var ids = idsString.split(separator: ",").map(String.init)
        if ids.isEmpty { ids = WorldCity.initialSelectionIdentifiers() }
        return WorldCity.cities(from: ids)
    }

    var body: some View {
        GeometryReader { geo in
            let palette = ClockColorPalette.system(colorScheme: colorScheme)
            let rows = buildRows(for: date)
            let rowCount = max(rows.count, 1)
            let size = geo.size
            let rowHeight = size.height / CGFloat(rowCount)

            ZStack {
                palette.background

                if rows.isEmpty {
                    EmptyStateView(rowHeight: rowHeight, palette: palette)
                        .frame(width: size.width, height: size.height)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            CityTimelineRow(
                                row: row,
                                rowHeight: rowHeight,
                                isDark: index.isMultiple(of: 2)
                            )
                            .frame(height: rowHeight)
                        }
                    }
                    .frame(width: size.width, height: size.height, alignment: .top)
                }
            }
        }
    }

    private func buildRows(for date: Date) -> [RowData] {
        let locale = Locale(identifier: "en_US_POSIX")
        return cities.prefix(12).compactMap { city in
            guard let tz = city.timeZone ?? TimeZone(identifier: city.timeZoneIdentifier) else { return nil }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = tz

            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let localMinutes = hour * 60 + minute
            let secondsFromGMT = tz.secondsFromGMT(for: date)
            let utcMinutes = (localMinutes - secondsFromGMT / 60).mod(24 * 60)

            let time24 = String(format: "%02d:%02d", hour, minute)

            let time12 = DateFormatter.cached(format: "hh:mm a", locale: locale, tz: tz)
                .string(from: date)
                .uppercased()

            let symbol = dayPhaseSymbol(for: hour)

            return RowData(
                city: city,
                name: city.name,
                iata: city.iataCode,
                utcMinutes: utcMinutes,
                symbol: symbol,
                time24: time24,
                time12: time12
            )
        }
        .sorted { $0.utcMinutes < $1.utcMinutes }
    }

    private func dayPhaseSymbol(for hour: Int) -> String {
        if hour >= 6 && hour < 18 {
            return "sun.max.fill"
        } else {
            return "moon.fill"
        }
    }
}

private struct RowData {
    let city: WorldCity
    let name: String
    let iata: String
    let utcMinutes: Int
    let symbol: String
    let time24: String
    let time12: String
}

private struct CityTimelineRow: View {
    let row: RowData
    let rowHeight: CGFloat
    let isDark: Bool

    private var isLocalCity: Bool {
        row.city.timeZoneIdentifier == TimeZone.current.identifier
    }

    private var backgroundColor: Color {
        switch row.symbol {
        case "sun.max.fill": return .white
        default: return .black
        }
    }

    private var primaryColor: Color {
        if isLocalCity {
            return .red
        }
        return backgroundColor == .black ? .white : .black
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let baseSize: CGFloat = 14.0
            let labelFont = Font.system(size: baseSize, weight: .semibold, design: .rounded)
            let timeFont = Font.system(size: baseSize, weight: .semibold, design: .monospaced).monospacedDigit()

            HStack(alignment: .center, spacing: 8) {
                Text(row.name)
                    .font(labelFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(row.iata)
                    .font(labelFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)

                Text(row.time24)
                    .font(timeFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)

                Text(row.time12.uppercased())
                    .font(timeFont)
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)

                Image(systemName: row.symbol)
                    .font(labelFont)
                    .foregroundStyle(primaryColor)
            }
            .padding(.horizontal, 20)
            .frame(width: width, height: rowHeight)
            .background(backgroundColor)
        }
        .frame(height: rowHeight)
    }
}

private struct EmptyStateView: View {
    let rowHeight: CGFloat
    let palette: ClockColorPalette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: max(rowHeight, 24), weight: .regular))
                .foregroundStyle(palette.numbers.opacity(0.6))
            Text("No cities selected")
                .font(.system(size: max(rowHeight * 0.5, 14), weight: .semibold))
                .foregroundStyle(palette.numbers.opacity(0.7))
            Text("Add cities in the main app to populate this widget.")
                .font(.system(size: max(rowHeight * 0.45, 12)))
                .foregroundStyle(palette.numbers.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Int {
    func mod(_ m: Int) -> Int {
        let r = self % m
        return r >= 0 ? r : r + m
    }
}

private extension DateFormatter {
    struct CacheKey: Hashable {
        let format: String
        let localeIdentifier: String
        let timeZoneIdentifier: String
    }
    private static var cache: [CacheKey: DateFormatter] = [:]
    static func cached(format: String, locale: Locale, tz: TimeZone) -> DateFormatter {
        let key = CacheKey(format: format, localeIdentifier: locale.identifier, timeZoneIdentifier: tz.identifier)
        if let formatter = cache[key] {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = tz
        formatter.dateFormat = format
        cache[key] = formatter
        return formatter
    }
}

#if DEBUG
struct MediumLineRibbonView_Previews: PreviewProvider {
    static var previews: some View {
        MediumLineRibbonView(date: Date(), colorScheme: .light)
            .frame(width: 584, height: 284)
    }
}
#endif
