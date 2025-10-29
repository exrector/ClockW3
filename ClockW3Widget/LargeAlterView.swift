import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct LargeAlterEntry: TimelineEntry {
    let date: Date
    let colorSchemePreference: String
}

// MARK: - Timeline Provider
struct LargeAlterProvider: TimelineProvider {
    func placeholder(in context: Context) -> LargeAlterEntry {
        return LargeAlterEntry(
            date: Date(),
            colorSchemePreference: "system"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LargeAlterEntry) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        let entry = LargeAlterEntry(
            date: Date(),
            colorSchemePreference: colorPref
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LargeAlterEntry>) -> Void) {
        let colorPref = SharedUserDefaults.shared.string(forKey: SharedUserDefaults.colorSchemeKey) ?? "system"
        
        var entries: [LargeAlterEntry] = []
        let now = Date()
        
        let calendar = Calendar.current
        let currentSecond = calendar.component(.second, from: now)
        let secondsToNextMinute = 60 - currentSecond
        
        guard let nextMinuteStart = calendar.date(bySetting: .second, value: 0, of: now.addingTimeInterval(Double(secondsToNextMinute))) else {
            let entry = LargeAlterEntry(
                date: now,
                colorSchemePreference: colorPref
            )
            let timeline = Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60)))
            completion(timeline)
            return
        }
        
        // Немедленный entry
        entries.append(
            LargeAlterEntry(
                date: now,
                colorSchemePreference: colorPref
            )
        )
        
        // Timeline на 60 минут
        for minuteOffset in 0..<60 {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: nextMinuteStart)!
            let entry = LargeAlterEntry(
                date: entryDate,
                colorSchemePreference: colorPref
            )
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Widget View
struct LargeAlterWidgetView: View {
    var entry: LargeAlterProvider.Entry
    @Environment(\.widgetFamily) var family
    
    private var overrideColorScheme: ColorScheme? {
        switch entry.colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            AlternativeClockWidgetContent(
                currentTime: entry.date,
                overrideColorScheme: overrideColorScheme
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .widgetBackground(overrideColorScheme == .dark ? Color.black : Color.white)
    }
}

// MARK: - Упрощенная версия AlternativeClockView для виджета
struct AlternativeClockWidgetContent: View {
    let currentTime: Date
    let overrideColorScheme: ColorScheme?
    
    @Environment(\.colorScheme) private var environmentColorScheme
    
    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
    }
    
    private var centerHour: Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: currentTime)
    }
    
    private var centerMinute: Int {
        let calendar = Calendar.current
        return calendar.component(.minute, from: currentTime)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Левая часть - 75%
                leftSide
                    .frame(width: geometry.size.width * 0.75)
                
                // Правая часть - 25%
                rightSide
                    .frame(width: geometry.size.width * 0.25)
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
    
    // MARK: - Левая часть с блоками
    private var leftSide: some View {
        VStack(spacing: 8) {
            // Блок 1 - Локальный город с часами
            localCityBlock
                .frame(maxHeight: .infinity)
            
            // Блоки 2-5 - Пустые
            ForEach(0..<4, id: \.self) { _ in
                emptyBlock
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(8)
    }
    
    private var localCityBlock: some View {
        ZStack {
            VStack(spacing: 4) {
                Text(TimeZone.current.localizedName(for: .standard, locale: .current) ?? "Local")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                
                Text(currentTime, style: .time)
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
            }
            
            cornerScrews
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
        )
    }
    
    private var emptyBlock: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
            
            cornerScrews
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
        )
    }
    
    // MARK: - Правая часть с барабаном
    private var rightSide: some View {
        ZStack {
            VStack(spacing: 2) {
                // Показываем несколько часов вокруг текущего
                ForEach(-2...2, id: \.self) { offset in
                    let hour = (centerHour + offset + 24) % 24
                    let displayHour = hour == 0 ? 24 : hour
                    let isCenter = offset == 0
                    
                    Text(String(format: "%02d", displayHour))
                        .font(.system(size: isCenter ? 16 : 12, weight: isCenter ? .bold : .regular, design: .monospaced))
                        .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(isCenter ? 1.0 : 0.5))
                }
            }
            
            // Центральная риска
            HStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 20, height: 2)
                Spacer()
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 20, height: 2)
            }
            .padding(.horizontal, 4)
            
            cornerScrews
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
        )
        .padding(8)
    }
    
    // Винты в углах
    private var cornerScrews: some View {
        GeometryReader { geometry in
            let screwSize: CGFloat = 8
            let inset: CGFloat = 10
            
            ZStack {
                Text("⊗")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: inset)
                
                Text("⊕")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: geometry.size.width - inset, y: inset)
                
                Text("⊕")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: geometry.size.height - inset)
                
                Text("⊗")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: geometry.size.width - inset, y: geometry.size.height - inset)
            }
        }
    }
}

// MARK: - Widget Configuration
struct LargeAlterWidget: Widget {
    let kind: String = "LargeAlterWidget"
    
    var body: some WidgetConfiguration {
        let configuration = StaticConfiguration(kind: kind, provider: LargeAlterProvider()) { entry in
            LargeAlterWidgetView(entry: entry)
        }
        .configurationDisplayName("Alternative Clock")
        .description("Alternative clock view with drum selector")
        .supportedFamilies([.systemLarge])
        
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *) {
            return configuration.contentMarginsDisabled()
        } else {
            return configuration
        }
    }
}
