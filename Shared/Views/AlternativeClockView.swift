import SwiftUI

#if WIDGET_EXTENSION
import WidgetKit
#endif

#if os(iOS)
import UIKit
#endif

#if os(macOS) && !WIDGET_EXTENSION
import AppKit

// Структура для передачи данных скролла
struct ScrollEvent {
    let scrollingDeltaY: CGFloat
}

// View modifier для обработки скролла на macOS
struct ScrollWheelModifier: ViewModifier {
    let action: (ScrollEvent) -> Void

    func body(content: Content) -> some View {
        content.overlay(
            ScrollWheelView(action: action)
                .allowsHitTesting(true)
        )
    }
}

struct ScrollWheelView: NSViewRepresentable {
    let action: (ScrollEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollableNSView()
        view.scrollAction = action
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let scrollView = nsView as? ScrollableNSView {
            scrollView.scrollAction = action
        }
    }
}

class ScrollableNSView: NSView {
    var scrollAction: ((ScrollEvent) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Включаем отслеживание событий скролла
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func scrollWheel(with event: NSEvent) {
        // Передаём событие скролла
        scrollAction?(ScrollEvent(scrollingDeltaY: event.scrollingDeltaY))
        // Не вызываем super, чтобы не было двойного скролла
    }

    // Принимаем весь view для обработки событий
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

extension View {
    func onScrollWheel(perform action: @escaping (ScrollEvent) -> Void) -> some View {
        self.modifier(ScrollWheelModifier(action: action))
    }
}
#endif

/// Альтернативное вью для циферблата
struct AlternativeClockView: View {
    @StateObject private var viewModel = SimpleClockViewModel()
    @Environment(\.colorScheme) private var environmentColorScheme
    #if os(macOS)
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    #endif
    @State private var drumOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var previousDragHeight: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var scrollResetTimer: Timer?
    // Режим отображения: true — живое локальное время; false — зафиксированное выбранное время
    @State private var isLiveMode: Bool = true

    // MARK: - Star Trek Quotes
    private let starTrekQuotes = [
        "Engage!",
        "Make it so.",
        "Fascinating.",
        "Shields up!",
        "Warp speed.",
        "Tea. Earl Grey. Hot.",
        "Trust yourself.",
        "Resistance is futile.",
        "Highly illogical.",
        "Seize the time.",
        "Let's see what's out there.",
        "Live long and prosper."
    ]
    @State private var currentQuotes: [String] = []
    @State private var formatRefreshKey: Int = 0

    // MARK: - Settings integration
    @AppStorage(
        SharedUserDefaults.use12HourFormatKey,
        store: SharedUserDefaults.shared
    ) private var use12HourFormat: Bool = false
    @AppStorage(
        SharedUserDefaults.selectedCitiesKey,
        store: SharedUserDefaults.shared
    ) private var selectedCityIdentifiers: String = ""
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false
    // Reminder preview throttling
    @State private var lastPreviewHour: Int? = nil
    @State private var lastPreviewMinute: Int? = nil

    // Haptic feedback tracking
    @State private var lastCrossedQuarterIndex: Int? = nil
    @State private var lastCrossedMinute: Int? = nil
    @State private var lastHapticTime: TimeInterval = 0
    @State private var dragVelocity: CGFloat = 0

    var overrideColorScheme: ColorScheme? = nil
    var overrideTime: Date? = nil
    var overrideCityName: String? = nil
    var override12HourFormat: Bool? = nil

    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
    }

    private var effectiveUse12HourFormat: Bool {
        override12HourFormat ?? use12HourFormat
    }

    private var isInactiveMode: Bool {
        #if os(macOS) && WIDGET_EXTENSION
        return widgetRenderingMode == .accented || widgetRenderingMode == .vibrant
        #else
        return false
        #endif
    }

    private var backgroundColor: Color {
        if isInactiveMode {
            return Color.clear
        }
        return colorScheme == .dark ? Color.black : Color.white
    }

    private var foregroundColor: Color {
        if isInactiveMode {
            // В неактивном режиме используем системные цвета виджета
            return colorScheme == .dark ? Color.white : Color.black
        }
        return colorScheme == .dark ? Color.white : Color.black
    }
    
    private var baseTime: Date {
        overrideTime ?? viewModel.currentTime
    }

    // Час и минута, которые показываются В ЦЕНТРЕ барабана (на красной риске)
    private var centerHour: Int {
        let normalizedOffset = normalizedDrumOffset
        let totalMinutes = -normalizedOffset * 24.0 * 60.0
        let minutes = Int(totalMinutes.rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return wrapped / 60
    }
    
    private var centerMinute: Int {
        let normalizedOffset = normalizedDrumOffset
        let totalMinutes = -normalizedOffset * 24.0 * 60.0
        let minutes = Int(totalMinutes.rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return wrapped % 60
    }

    // В виджете нет интерактивного драга, поэтому используем текущее время из baseTime
    // вместо состояния барабана. В основном приложении — обычный drumOffset.
    private var normalizedDrumOffset: CGFloat {
        #if WIDGET_EXTENSION
        let cal = Calendar.current
        let hour = cal.component(.hour, from: baseTime)
        let minute = cal.component(.minute, from: baseTime)
        let total = hour * 60 + minute
        return (-CGFloat(total) / (24.0 * 60.0)).truncatingRemainder(dividingBy: 1.0)
        #else
        return drumOffset.truncatingRemainder(dividingBy: 1.0)
        #endif
    }
    
    // Вычисляемое время на основе центрального часа барабана
    private var displayTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseTime)
        components.hour = centerHour
        components.minute = centerMinute
        components.second = 0
        return calendar.date(from: components) ?? baseTime
    }

    // Локальное время (всегда текущее, не зависит от барабана)
    private var localDisplayTime: Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: baseTime)
        let minute = calendar.component(.minute, from: baseTime)
        var components = calendar.dateComponents([.year, .month, .day], from: baseTime)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components) ?? baseTime
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Внешняя квадратная окантовка
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.clear, lineWidth: 0)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(backgroundColor)
                    )
                    .aspectRatio(1, contentMode: .fit)
                
                let inset: CGFloat = 4.0
                Group {
                    let squareSide = max(1, min(geometry.size.width, geometry.size.height))
                    let availableSide = max(1, squareSide - inset * 2)
                    let leftW = availableSide * 0.66
                    let rightW = availableSide * 0.34
                    HStack(spacing: 0) {
                        leftSide
                            .frame(width: leftW, height: availableSide)
                            .id(formatRefreshKey)
                        rightSide
                            .frame(width: rightW, height: availableSide)
                    }
                    .frame(width: availableSide, height: availableSide)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .padding(EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(backgroundColor)
        }
        .onAppear {
            isLiveMode = true
            syncWithCurrentTime()
            syncCitiesToViewModel()
            sendPreviewIfNeeded()
            generateRandomQuotes()
        }
        .onDisappear {
            scrollResetTimer?.invalidate()
            scrollResetTimer = nil
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            syncCitiesToViewModel()
            generateRandomQuotes()
        }
        .onChange(of: use12HourFormat) { _, _ in
            // Пересчитываем блоки при изменении формата времени
            formatRefreshKey += 1
        }
        .onChange(of: baseTime) { _, _ in
            // Синхронизируемся с живым временем только если включён live‑режим и нет драга
            if isLiveMode && !isDragging {
                syncWithCurrentTime()
            }
        }
    }
    
    // Синхронизация с текущим временем при появлении
    private func syncWithCurrentTime() {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: baseTime)
        let currentMinute = calendar.component(.minute, from: baseTime)
        let totalMinutes = currentHour * 60 + currentMinute
        drumOffset = -CGFloat(totalMinutes) / (24.0 * 60.0)
        dragStartOffset = drumOffset
    }
    
    // MARK: - Левая часть с блоками
    private var leftSide: some View {
        GeometryReader { geometry in
            let padding: CGFloat = 12
            let spacing: CGFloat = 8
            let totalHeight = geometry.size.height
            let blockHeight = max(0, (totalHeight - padding * 2 - spacing * 4) / 5)

            VStack(spacing: spacing) {
                // Блок 1 - Локальный город с часами
                localCityBlock(blockHeight: blockHeight)
                    .frame(height: blockHeight)

                // Блоки 2-5 - Остальные города (максимум 4, чтобы итого было 5)
                let otherCities = Array(viewModel.cities.dropFirst().prefix(4))
                ForEach(otherCities, id: \.id) { city in
                    cityBlock(for: city, blockHeight: blockHeight)
                        .frame(height: blockHeight)
                }

                // Заполняем пустыми блоками с цитатами, если городов меньше 5
                let emptyCount = max(0, 4 - otherCities.count)
                ForEach(0..<emptyCount, id: \.self) { index in
                    let quote = index < currentQuotes.count ? currentQuotes[index] : "Engage!"
                    emptyBlockWithQuote(quote, blockHeight: blockHeight)
                        .frame(height: blockHeight)
                }
            }
            .padding(padding)
        }
    }

    
    // MARK: - Правая часть с барабаном
    private var rightSide: some View {
        VStack(spacing: 0) {
            ZStack {
                GeometryReader { geometry in
                    ZStack {
                        // Барабан с часами
                        timeDrum(in: geometry)
                        
                        // Центральная риска (фиксированная)
                        centerIndicator
                        // Стрелки сверху/снизу (одинаковые размеры)
                        VStack {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.red)
                                .frame(width: 20, height: 20)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.red)
                                .frame(width: 20, height: 20)
                        }

                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                }
                .padding(12)
                
                // Винты в углах барабана
                cornerScrews
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(foregroundColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
        )
        .padding(12)
    }
    
    // Барабан с прокруткой
    private func timeDrum(in geometry: GeometryProxy) -> some View {
        let totalHeight = geometry.size.height
        let centerY = totalHeight / 2.0  // Центр области барабана
        let itemHeight = totalHeight / 5.0 // Показываем ~5 элементов одновременно
        
        return ZStack {
            // Минутные насечки каждые 10 минут с подписями
            ForEach({ () -> [Int] in
                #if WIDGET_EXTENSION
                let normalizedOffset = normalizedDrumOffset
                let base = Int(floor(-normalizedOffset * 24.0))
                return Array((base-2)...(base+2))
                #else
                return Array((-50)...50)
                #endif
            }(), id: \.self) { index in
                let normalizedOffset = normalizedDrumOffset
                let stepHeight = itemHeight / 6.0
                let basePosition = (CGFloat(index) + normalizedOffset * 24.0) * itemHeight
                
                ForEach(1..<6, id: \.self) { m in
                    let minute = m * 10
                    let mPosition = basePosition + CGFloat(m) * stepHeight
                    if abs(mPosition) < totalHeight {
                        minuteMark(minute: minute)
                            .position(x: geometry.size.width / 2.0, y: centerY + mPosition)
                    }
                }
            }
            
            // Дополнительные мелкие насечки (каждые 5 минут без цифр)
            ForEach({ () -> [Int] in
                #if WIDGET_EXTENSION
                let normalizedOffset = normalizedDrumOffset
                let base = Int(floor(-normalizedOffset * 24.0))
                return Array((base-2)...(base+2))
                #else
                return Array((-50)...50)
                #endif
            }(), id: \.self) { index in
                let normalizedOffset = normalizedDrumOffset
                let stepHeight = itemHeight / 12.0  // 12 шагов по 5 минут
                let basePosition = (CGFloat(index) + normalizedOffset * 24.0) * itemHeight
                
                ForEach(1..<12, id: \.self) { m in
                    let minute = m * 5
                    // Пропускаем кратные 10 (они уже есть)
                    if minute % 10 != 0 {
                        let mPosition = basePosition + CGFloat(m) * stepHeight
                        if abs(mPosition) < totalHeight {
                            smallMinuteMark()
                                .position(x: geometry.size.width / 2.0, y: centerY + mPosition)
                        }
                    }
                }
            }
            
            // Генерируем достаточно меток для бесконечной прокрутки (часы)
            ForEach({ () -> [Int] in
                #if WIDGET_EXTENSION
                let normalizedOffset = normalizedDrumOffset
                let base = Int(floor(-normalizedOffset * 24.0))
                return Array((base-3)...(base+3))
                #else
                return Array((-50)...50)
                #endif
            }(), id: \.self) { index in
                let hour = ((index % 24) + 24) % 24
                let displayHour = {
                    if effectiveUse12HourFormat {
                        let h = hour % 12
                        return h == 0 ? 12 : h
                    } else {
                        return hour == 0 ? 24 : hour
                    }
                }()
                
                // Вычисляем позицию этой метки
                let normalizedOffset = normalizedDrumOffset
                let position = (CGFloat(index) + normalizedOffset * 24.0) * itemHeight
                
                // Показываем только видимые метки
                if abs(position) < totalHeight {
                    let distanceFromCenter = abs(position)
                    let isCenter = distanceFromCenter < itemHeight * 0.3
                    
                    hourMark(hour: displayHour, isCenter: isCenter)
                        .position(x: geometry.size.width / 2.0, y: centerY + position)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        #if !WIDGET_EXTENSION
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    // Пользователь начал управлять барабаном — выходим из live‑режима
                    if isLiveMode { isLiveMode = false }
                    let dragHeight = value.translation.height
                    dragVelocity = dragHeight - previousDragHeight
                    previousDragHeight = dragHeight
                    updateDrum(value, in: geometry)
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartOffset = drumOffset
                    previousDragHeight = 0
                    // Snap to nearest quarter hour
                    snapDrumToNearestQuarter(in: geometry)
                    dragVelocity = 0
                    lastCrossedQuarterIndex = nil  // Reset on drag end
                    lastCrossedMinute = nil  // Reset minute mark tracking
                }
        )
        #endif

        #if os(macOS) && !WIDGET_EXTENSION
        .onScrollWheel { event in
            handleScrollWheel(event, in: geometry)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(_):
                NSCursor.pointingHand.push()
            case .ended:
                NSCursor.pop()
            }
        }
        #endif
    }
    
    
    #if os(macOS) && !WIDGET_EXTENSION
    private func handleScrollWheel(_ event: ScrollEvent, in geometry: GeometryProxy) {
        isDragging = true
        if isLiveMode { isLiveMode = false }

        // Сбрасываем существующий таймер
        scrollResetTimer?.invalidate()

        let totalHeight = geometry.size.height
        let itemHeight = totalHeight / 5.0
        let scrollDelta = event.scrollingDeltaY
        let hourChange = scrollDelta / itemHeight / 24.0
        drumOffset += hourChange
        dragStartOffset = drumOffset
        playHapticFeedbackIfNeeded(for: drumOffset)
        sendPreviewIfNeeded()

        // Сбросим isDragging после 0.5 секунды отсутствия скролла
        scrollResetTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            isDragging = false
            scrollResetTimer = nil
        }
    }
    #endif

    
    // Минутная метка с подписями 10/20/30/40/50
    private func minuteMark(minute: Int) -> some View {
        let centralWidth: CGFloat = 36
        let strokeColor = (colorScheme == .dark ? Color.white : Color.black).opacity(0.4)
        let textColor = (colorScheme == .dark ? Color.white : Color.black).opacity(0.6)
        let font = Font.system(size: 10, weight: .regular, design: .rounded)
        return HStack {
            Spacer()
            ZStack {
                // Риска (кроме 30, для 30 показываем только цифру)
                if minute != 30 {
                    Rectangle()
                        .fill(strokeColor)
                        .frame(width: 8, height: 1)
                }
                // Подписи
                switch minute {
                case 10, 20:
                    HStack {
                        Text("\(minute)")
                            .font(font)
                            .foregroundStyle(textColor)
                        Spacer(minLength: 0)
                    }
                case 40, 50:
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(minute)")
                            .font(font)
                            .foregroundStyle(textColor)
                    }
                case 30:
                    Text("30")
                        .font(font)
                        .foregroundStyle(textColor)
                default:
                    EmptyView()
                }
            }
            .frame(width: centralWidth, alignment: .center)
            Spacer()
        }
    }
    
    // Мелкая минутная метка без цифр (каждые 5 минут)
    private func smallMinuteMark() -> some View {
        let strokeColor = (colorScheme == .dark ? Color.white : Color.black).opacity(0.25)
        return HStack {
            Spacer()
            Rectangle()
                .fill(strokeColor)
                .frame(width: 4, height: 1)
            Spacer()
        }
    }
    
    // Метка часа на барабане
    private func hourMark(hour: Int, isCenter: Bool) -> some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Короткая метка слева
            Rectangle()
                .fill(foregroundColor.opacity(isCenter ? 1.0 : 0.4))
                .frame(width: 12, height: 2)
            
            // Текст часа
            Text(String(format: "%02d", hour))
                .font(.system(size: isCenter ? 18 : 14, weight: isCenter ? .bold : .medium, design: .monospaced))
                .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(isCenter ? 1.0 : 0.6))
                .frame(width: 36, alignment: .center)
            
            // Короткая метка справа
            Rectangle()
                .fill(foregroundColor.opacity(isCenter ? 1.0 : 0.4))
                .frame(width: 12, height: 2)
            
            Spacer()
        }
    }
    
    // Центральная «цель»: L · L
    private var centerIndicator: some View {
        let color = Color.red
        return HStack(spacing: 14) {
            Text("L")
                .font(.system(size: 24, weight: .regular, design: .monospaced))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: 1, y: -1, anchor: .center)
                .offset(y: 3)
            Text("·")
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .foregroundStyle(color)
            Text("L")
                .font(.system(size: 24, weight: .regular, design: .monospaced))
                .foregroundStyle(color)
                .rotationEffect(.degrees(90))
                .offset(y: 3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        #if !WIDGET_EXTENSION
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.7)
                .onEnded { _ in
                    activateReminderForCity(hour: centerHour, minute: centerMinute)
                }
        )
        #endif
    }
    
    // MARK: - Блоки левой стороны

    private func localCityBlock(blockHeight: CGFloat) -> some View {
        let nameSize = blockHeight * 0.18
        let timeSize = blockHeight * 0.35

        return ZStack {
            VStack(spacing: 2) {
                // Название локального города (неизменяемое, из главного вью)
                Text(overrideCityName ?? viewModel.cities.first?.name ?? "Local")
                    .font(.system(size: nameSize, weight: .semibold, design: .default))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Часы (всегда локальное время, не зависит от барабана)
                HStack(spacing: 2) {
                    Text(formattedDisplayTime(localDisplayTime))
                        .monospacedDigit()
                        .font(.system(size: timeSize, weight: .light, design: .rounded))
                        .foregroundStyle(foregroundColor)
                    if effectiveUse12HourFormat {
                        Text(getAMPM(for: localDisplayTime))
                            .monospacedDigit()
                            .font(.system(size: timeSize, weight: .light, design: .rounded))
                            .foregroundStyle(foregroundColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.red, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
        )
        #if !WIDGET_EXTENSION
        .onTapGesture {
            resetDrumToLocalTime()
        }
        #endif
    }
    
    // Блок города с временем
    private func cityBlock(for city: WorldCity, blockHeight: CGFloat) -> some View {
        let cityTime = timeInCityTimeZone(displayTime, timezone: city.timeZone)
        let nameSize = blockHeight * 0.18
        let timeSize = blockHeight * 0.35

        return ZStack {
            VStack(spacing: 2) {
                // Название города
                Text(city.name)
                    .font(.system(size: nameSize, weight: .semibold, design: .default))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Время города
                HStack(spacing: 2) {
                    Text(formattedDisplayTime(cityTime))
                        .monospacedDigit()
                        .font(.system(size: timeSize, weight: .light, design: .rounded))
                        .foregroundStyle(foregroundColor)
                    if effectiveUse12HourFormat {
                        Text(getAMPM(for: cityTime))
                            .monospacedDigit()
                            .font(.system(size: timeSize, weight: .light, design: .rounded))
                            .foregroundStyle(foregroundColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(foregroundColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
        )
    }

    private var emptyBlock: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(foregroundColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
        )
    }

    // Пустой блок со Star Trek цитатой
    private func emptyBlockWithQuote(_ quote: String, blockHeight: CGFloat) -> some View {
        let quoteSize = blockHeight * 0.16

        return ZStack {
            VStack {
                Text(quote)
                    .font(.system(size: quoteSize, weight: .medium, design: .rounded))
                    .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(foregroundColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(backgroundColor)
                )
        )
    }
    
    // Винты в углах блока (Unicode, жирнее)
    private var cornerScrews: some View {
        GeometryReader { geometry in
            let screwSize: CGFloat = 14
            let inset: CGFloat = 16
            
            ZStack {
                // Верхний левый
                Text("⊗")
                    .font(.system(size: screwSize, weight: .heavy))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: inset)
                
                // Верхний правый
                Text("⊕")
                    .font(.system(size: screwSize, weight: .heavy))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: geometry.size.width - inset, y: inset)
                
                // Нижний левый
                Text("⊕")
                    .font(.system(size: screwSize, weight: .heavy))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: geometry.size.height - inset)
                
                // Нижний правый
                Text("⊗")
                    .font(.system(size: screwSize, weight: .heavy))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: geometry.size.width - inset, y: geometry.size.height - inset)
            }
        }
    }
    
    // MARK: - Обновление барабана из драга

    private func updateDrum(_ drag: DragGesture.Value, in geometry: GeometryProxy) {
        let dragDistance = drag.translation.height
        let totalHeight = geometry.size.height
        let itemHeight = totalHeight / 5.0

        // Простое изменение - один час занимает itemHeight пикселей
        let hourChange = dragDistance / itemHeight / 24.0

        let newOffset = dragStartOffset + hourChange
        drumOffset = newOffset

        // Haptic feedback for quarter-hour crossing
        playHapticFeedbackIfNeeded(for: newOffset)

        sendPreviewIfNeeded()
    }

    private func playHapticFeedbackIfNeeded(for offset: CGFloat) {
        #if os(iOS)
        let now = CACurrentMediaTime()
        // Minimum time between haptics (40ms)
        let minInterval: TimeInterval = 0.04

        guard now - lastHapticTime >= minInterval else { return }

        let normalizedOffset = offset.truncatingRemainder(dividingBy: 1.0)

        // Check minute marks (10, 20, 30, 40, 50)
        let totalMinutes = -normalizedOffset * 24.0 * 60.0
        let minutes = Int(totalMinutes.rounded())
        let wrappedMinutes = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        let currentMinute = wrappedMinutes % 60

        // Check for minute marks (10, 20, 30, 40, 50)
        let minuteMarks = [10, 20, 30, 40, 50]
        if minuteMarks.contains(currentMinute) {
            if let lastMinute = lastCrossedMinute, lastMinute == currentMinute {
                // Already played haptic for this minute mark
            } else {
                lastCrossedMinute = currentMinute
                lastHapticTime = now
                HapticFeedback.shared.playTickCrossing(tickType: .minute, tickIndex: currentMinute)
                return
            }
        }

        // Also handle quarter-hour marks
        let quarterIndex = Int(round(normalizedOffset * 96.0)) % 96

        // Check if we've crossed a new quarter-hour boundary
        if let lastIndex = lastCrossedQuarterIndex {
            if quarterIndex == lastIndex {
                return  // Same quarter-hour, no haptic
            }
        }

        lastCrossedQuarterIndex = quarterIndex
        lastHapticTime = now

        // Play haptic feedback based on the mark type
        let tickType = HapticFeedback.tickType(for: quarterIndex)
        HapticFeedback.shared.playTickCrossing(tickType: tickType, tickIndex: quarterIndex)
        #endif
    }

    private func snapDrumToNearestQuarter(in geometry: GeometryProxy) {
        // Snap to nearest quarter hour (15 minutes)
        let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
        let quarterIndex = round(normalizedOffset * 96.0)
        let snappedOffset = (quarterIndex / 96.0).truncatingRemainder(dividingBy: 1.0)

        // Animate snap
        withAnimation(.easeOut(duration: 0.2)) {
            drumOffset = snappedOffset
        }

        // Play final snap haptic
        #if os(iOS)
        HapticFeedback.shared.playImpact(intensity: .light)
        #endif
    }
}

// MARK: - Settings + Reminder integration helpers
extension AlternativeClockView {
    private func syncCitiesToViewModel() {
        var identifiers = selectedCityIdentifiers
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty {
            let seeded = WorldCity.initialSelectionIdentifiers()
            identifiers = seeded
            selectedCityIdentifiers = seeded.joined(separator: ",")
            hasSeededDefaults = true
        } else {
            let ensured = WorldCity.ensureLocalIdentifier(in: identifiers)
            if ensured != identifiers {
                identifiers = ensured
                selectedCityIdentifiers = ensured.joined(separator: ",")
            }
            if !identifiers.isEmpty {
                hasSeededDefaults = true
            }
        }

        let cities = WorldCity.cities(from: identifiers)
        viewModel.cities = cities
    }

    private func formattedDisplayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = effectiveUse12HourFormat ? "h:mm" : "HH:mm"
        return formatter.string(from: date)
    }

    private func getAMPM(for date: Date, timezone: TimeZone? = nil) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timezone ?? .current
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? "AM" : "PM"
    }

    private func sendPreviewIfNeeded() {
        let h = centerHour
        let m = centerMinute
        guard lastPreviewHour != h || lastPreviewMinute != m else { return }
        lastPreviewHour = h
        lastPreviewMinute = m
        #if !WIDGET_EXTENSION
        ReminderManager.shared.updateTemporaryTime(hour: h, minute: m)
        #endif
    }

    // Вычисляет время в часовом поясе города
    private func timeInCityTimeZone(_ date: Date, timezone: TimeZone?) -> Date {
        guard let timezone = timezone else { return date }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

        var resultCalendar = Calendar.current
        resultCalendar.timeZone = TimeZone.current

        return resultCalendar.date(from: components) ?? date
    }

    // Форматирует время для отображения
    private func formattedTime(_ date: Date, timezone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.timeZone = timezone ?? .current
        formatter.dateFormat = effectiveUse12HourFormat ? "h:mm" : "HH:mm"
        return formatter.string(from: date)
    }

    // Сбрасывает барабан на текущее локальное время
    private func resetDrumToLocalTime() {
        let localHour = Calendar.current.component(.hour, from: localDisplayTime)
        let localMinute = Calendar.current.component(.minute, from: localDisplayTime)
        let totalMinutes = localHour * 60 + localMinute
        let targetOffset = -CGFloat(totalMinutes) / (24.0 * 60.0)

        // Анимация с пружинящим эффектом
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            drumOffset = targetOffset
            dragStartOffset = targetOffset
        }

        // Возвращаемся в live‑режим — барабан снова тикает вместе с плиткой
        isLiveMode = true
        sendPreviewIfNeeded()
    }

    // Переключает барабан на время города при тапе с анимацией
    private func switchDrumToCity(hour: Int, minute: Int) {
        let totalMinutes = hour * 60 + minute
        let targetOffset = -CGFloat(totalMinutes) / (24.0 * 60.0)

        // Анимация с пружинящим эффектом (более натурально)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            drumOffset = targetOffset
            dragStartOffset = targetOffset
        }

        // Переходим в режим фиксированного выбранного времени
        if isLiveMode { isLiveMode = false }
        sendPreviewIfNeeded()
    }

    // Активирует напоминание при long press используя тот же алгоритм как в главном циферблате
    private func activateReminderForCity(hour: Int, minute: Int) {
        #if !WIDGET_EXTENSION
        Task {
            let manager = ReminderManager.shared

            // Обновляем временное время
            manager.updateTemporaryTime(hour: hour, minute: minute)

            // Используем тот же алгоритм что и в главном приложении
            await viewModel.confirmPreviewReminder()
        }
        #endif
    }

    // Генерирует рандомные уникальные цитаты для пустых блоков
    private func generateRandomQuotes() {
        let otherCities = Array(viewModel.cities.dropFirst().prefix(4))
        let emptyCount = max(0, 4 - otherCities.count)

        // Перетасовываем цитаты и берём столько, сколько нужно пустых блоков
        let shuffled = starTrekQuotes.shuffled()
        currentQuotes = Array(shuffled.prefix(emptyCount))
    }
}

#if DEBUG
struct AlternativeClockView_Previews: PreviewProvider {
    static var previews: some View {
        AlternativeClockView()
    }
}
#endif
