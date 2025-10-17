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
            let size = geo.size
            ZStack {
                palette.background
                RibbonContent(size: size, cities: cities, date: date, palette: palette)
            }
        }
    }
}

private struct RibbonContent: View {
    let size: CGSize
    let cities: [WorldCity]
    let date: Date
    let palette: ClockColorPalette

    var body: some View {
        let ordered = orderCitiesByUTC(cities: cities, at: date)
        let layout = layoutItems(size: size, items: ordered)
        return ZStack(alignment: .topLeading) {
            // Continuous three-row ribbon (single filled path) - starts at top-left and extends to bottom-right
            if !layout.ribbonPath.isEmpty {
                layout.ribbonPath.fill(palette.weekdayBackground)
            }
            // No labels - only the ribbon is displayed
        }
    }

    // MARK: - Model
    private struct OrderedItem { let city: WorldCity; let code: String; let time: String; let utcMinutes: Int }

    private func orderCitiesByUTC(cities: [WorldCity], at date: Date) -> [OrderedItem] {
        cities.compactMap { city in
            let tz = city.timeZone ?? .current
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let hour = cal.component(.hour, from: date)
            let minute = cal.component(.minute, from: date)
            let localMinutes = hour*60 + minute

            // Convert to UTC minutes: subtract secondsFromGMT
            let secondsFromGMT = tz.secondsFromGMT(for: date)
            let utcMinutes = (localMinutes - secondsFromGMT/60).mod(24*60)
            let timeStr = String(format: "%02d:%02d", hour, minute)
            return OrderedItem(city: city, code: city.iataCode, time: timeStr, utcMinutes: utcMinutes)
        }
        .sorted { a, b in a.utcMinutes < b.utcMinutes }
    }

    // MARK: - Layout
    private struct LayoutResult {
        let itemsToRender: [OrderedItem]
        let rowsY: [CGFloat]
        let barHeight: CGFloat
        let fontSize: CGFloat
        let ribbonPath: Path
        let labelPositions: [CGPoint]
    }

    private func layoutItems(size: CGSize, items: [OrderedItem]) -> LayoutResult {
        // Use the specified ribbon thickness (18-24pt)
        let minBarHeight: CGFloat = 18
        let maxBarHeight: CGFloat = 24
        let barHeight = max(minBarHeight, min(maxBarHeight, size.height * 0.15))
        
        let availableHeight = max(size.height - barHeight * 3, 0)
        let preferredGap = max(barHeight * 0.8, 12)
        let rowGap = min(preferredGap, availableHeight / 2)
        let totalContentHeight = barHeight * 3 + rowGap * 2
        let verticalPadding = max((size.height - totalContentHeight) / 2, 0)
        let rowStride = barHeight + rowGap
        let rowsY = [
            verticalPadding + barHeight / 2,
            verticalPadding + barHeight / 2 + rowStride,
            verticalPadding + barHeight / 2 + 2 * rowStride
        ]
        
        // Adaptive font and continuous ribbon packing into 3 rows
        let maxFont: CGFloat = 16
        let minFont: CGFloat = 11
        var fontSize: CGFloat = maxFont
        
        func segmentWidth(_ item: OrderedItem, font: CGFloat) -> CGFloat {
            // label width estimate without padding (for capsule-free labels)
            let em = font
            let codeW = CGFloat(max(3, item.code.count)) * em * 0.6
            let timeW: CGFloat = 5.0 * em * 0.6
            return codeW + 6 + timeW  // Removed padding for capsule-free design
        }
        
        // Start with a smaller base gap
        let baseGap: CGFloat = 12
        func totalWidth(_ items: [OrderedItem], font: CGFloat, gap: CGFloat) -> CGFloat {
            if items.isEmpty { return 0 }
            let contentWidth = items.reduce(0) { $0 + segmentWidth($1, font: font) }
            let gapsWidth = CGFloat(max(0, items.count-1)) * gap
            return contentWidth + gapsWidth
        }
        
        if items.isEmpty {
            let ribbonPath = coilRibbonPath(size: size, rowsY: rowsY, barHeight: barHeight)
            return LayoutResult(
                itemsToRender: [],
                rowsY: rowsY,
                barHeight: barHeight,
                fontSize: fontSize,
                ribbonPath: ribbonPath,
                labelPositions: []
            )
        }

        // Adaptive layout: reduce gap first, then font, then truncate
        var gap = baseGap
        let rowCap = size.width  // Use full width for calculations
        
        // Fit font and gap to 3-row capacity
        while fontSize > minFont {
            let need = totalWidth(items, font: fontSize, gap: gap)
            if need <= rowCap * 3 { break }
            if gap > 6 {  // Reduce gap to minimum of 6pt
                gap -= 2
            } else {
                fontSize -= 0.5
            }
        }
        
        // If still too long, cut tail
        var usable = items
        while totalWidth(usable, font: fontSize, gap: gap) > rowCap * 3, !usable.isEmpty {
            usable.removeLast()
        }
        
        // Build snake positions along folded rows
        var labelPositions: [CGPoint] = []
        var xCursor: CGFloat = 0  // Start from left edge
        var row = 0
        var remainingInRow = rowCap
        
        for (idx, it) in usable.enumerated() {
            let w = segmentWidth(it, font: fontSize)
            let segmentTotal = w + (idx == usable.count-1 ? 0 : gap)
            
            if segmentTotal > remainingInRow && row < 2 {
                // fold to next row
                row += 1
                xCursor = 0  // Start from left edge of next row
                remainingInRow = rowCap
            }
            
            let centerX: CGFloat
            if row % 2 == 0 {
                centerX = xCursor + w/2
            } else {
                // right-to-left row: measure from right edge
                centerX = size.width - (xCursor + w/2)
            }
            
            labelPositions.append(CGPoint(x: centerX, y: rowsY[row]))
            xCursor += segmentTotal
            remainingInRow -= segmentTotal
        }
        
        let ribbonPath = coilRibbonPath(size: size, rowsY: rowsY, barHeight: barHeight)
        return LayoutResult(itemsToRender: usable, rowsY: rowsY, barHeight: barHeight, fontSize: fontSize, ribbonPath: ribbonPath, labelPositions: labelPositions)
    }
    
    private func coilRibbonPath(size: CGSize, rowsY: [CGFloat], barHeight: CGFloat) -> Path {
        var path = Path()
        guard rowsY.count == 3, size.width > 0, barHeight > 0 else { return path }
        
        let half = barHeight / 2
        let topY = rowsY[0]
        let middleY = rowsY[1]
        let bottomY = rowsY[2]
        
        let startX = half
        let endX = max(startX, size.width - half)
        if endX <= startX + .ulpOfOne {
            path.move(to: CGPoint(x: startX, y: topY))
            path.addLine(to: CGPoint(x: startX, y: bottomY))
            return path.strokedPath(
                StrokeStyle(lineWidth: barHeight, lineCap: .round, lineJoin: .round)
            )
        }
        
        let topGap = max(middleY - topY, barHeight)
        let bottomGap = max(bottomY - middleY, barHeight)
        
        var rightRadius = max(topGap / 2, half)
        var leftRadius = max(bottomGap / 2, half)
        
        let maxRadius = max(endX - startX, 0)
        rightRadius = min(rightRadius, maxRadius)
        leftRadius = min(leftRadius, maxRadius)
        
        path.move(to: CGPoint(x: startX, y: topY))
        path.addLine(to: CGPoint(x: endX - rightRadius, y: topY))
        path.addRelativeArc(
            center: CGPoint(x: endX - rightRadius, y: (topY + middleY) / 2),
            radius: rightRadius,
            startAngle: Angle.degrees(-90),
            delta: Angle.degrees(180)
        )
        path.addLine(to: CGPoint(x: startX + leftRadius, y: middleY))
        path.addRelativeArc(
            center: CGPoint(x: startX + leftRadius, y: (middleY + bottomY) / 2),
            radius: leftRadius,
            startAngle: Angle.degrees(-90),
            delta: Angle.degrees(-180)
        )
        path.addLine(to: CGPoint(x: endX, y: bottomY))
        
        return path.strokedPath(
            StrokeStyle(lineWidth: barHeight, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct LabelView: View {
    let code: String
    let time: String
    let fontSize: CGFloat
    let palette: ClockColorPalette

    var body: some View {
        HStack(spacing: 4) {  // Reduced spacing for more compact layout
            Text(code)
                .font(.system(size: fontSize, weight: .semibold, design: .default))  // IATA code in semibold
                .foregroundColor(palette.numbers)
            Text(time)
                .font(.system(size: fontSize, weight: .regular, design: .monospaced))  // Time in monospaced font
                .foregroundColor(palette.arrow)
        }
        // No background or capsule - labels directly on the ribbon
    }
}

private extension Int {
    func mod(_ m: Int) -> Int { let r = self % m; return r >= 0 ? r : r + m }
}

#Preview {
    MediumLineRibbonView(date: Date(), colorScheme: .light)
        .frame(width: 584, height: 284)
}
