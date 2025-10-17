import SwiftUI

struct MediumZigZagView: View {
    let date: Date
    let colorScheme: ColorScheme
    // Pull cities from shared defaults selection
    private var cities: [WorldCity] {
        let idsString = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.selectedCitiesKey) ?? ""
        var ids = idsString.split(separator: ",").map(String.init)
        if ids.isEmpty { ids = WorldCity.initialSelectionIdentifiers() }
        return WorldCity.cities(from: ids)
    }

    var body: some View {
        GeometryReader { geo in
            let palette = ClockColorPalette.system(colorScheme: colorScheme)
            let size = geo.size
            ZStack {
                palette.background
                ZigZagCitiesTimelineView(size: size, cities: cities, date: date, palette: palette)
            }
        }
    }
}

private struct ZigZagCitiesTimelineView: View {
    let size: CGSize
    let cities: [WorldCity]
    let date: Date
    let palette: ClockColorPalette

    private var lineHeight: CGFloat { max(16, size.height * 0.18) }
    private var topY: CGFloat { size.height * 0.25 }
    private var bottomY: CGFloat { size.height * 0.75 }

    var body: some View {
        let items = buildItems()
        return ZStack(alignment: .leading) {
            // Base horizontal guide
            Path { p in
                p.move(to: CGPoint(x: 0, y: size.height/2))
                p.addLine(to: CGPoint(x: size.width, y: size.height/2))
            }
            .stroke(palette.secondaryColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4,4]))

            // Zig-zag polyline
            Path { path in
                guard !items.isEmpty else { return }
                let first = CGPoint(x: items[0].x, y: items[0].y)
                path.move(to: first)
                for i in 1..<items.count {
                    path.addLine(to: CGPoint(x: items[i].x, y: items[i].y))
                }
            }
            .stroke(palette.arrow, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            // Labels and times
            ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                VStack(spacing: 4) {
                    Text(it.code)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(palette.numbers)
                    Text(it.time)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(palette.arrow)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(palette.weekdayBackground.opacity(0.85))
                )
                .overlay(
                    Capsule().stroke(palette.secondaryColor.opacity(0.35), lineWidth: 1)
                )
                .position(x: it.x, y: it.y + (it.isTop ? -lineHeight*0.4 : lineHeight*0.4))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private struct Item { let x: CGFloat; let y: CGFloat; let isTop: Bool; let code: String; let time: String }

    private func buildItems() -> [Item] {
        guard !cities.isEmpty else { return [] }
        let count = min(cities.count, 8) // medium width: cap to avoid overcrowding
        let stepX = size.width / CGFloat(max(count,1))
        var items: [Item] = []
        for i in 0..<count {
            let city = cities[i]
            let tz = city.timeZone ?? .current
            var cal = Calendar.current
            cal.timeZone = tz
            let hour = cal.component(.hour, from: date)
            let minute = cal.component(.minute, from: date)
            let timeStr = String(format: "%02d:%02d", hour, minute)
            let code = city.iataCode
            let x = stepX * (CGFloat(i) + 0.5)
            let isTop = i % 2 == 0
            let y = isTop ? topY : bottomY
            items.append(Item(x: x, y: y, isTop: isTop, code: code, time: timeStr))
        }
        return items
    }
}

#Preview {
    MediumZigZagView(date: Date(), colorScheme: .light)
        .frame(width: 584, height: 284)
}
