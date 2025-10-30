import SwiftUI

#if os(macOS)
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
    @State private var drumOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    
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
    
    var overrideColorScheme: ColorScheme? = nil
    var overrideTime: Date? = nil
    var overrideCityName: String? = nil
    
    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
    }
    
    private var baseTime: Date {
        overrideTime ?? viewModel.currentTime
    }
    
    // Час и минута, которые показываются В ЦЕНТРЕ барабана (на красной риске)
    private var centerHour: Int {
        let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
        let totalMinutes = -normalizedOffset * 24.0 * 60.0
        let minutes = Int(totalMinutes.rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return wrapped / 60
    }
    
    private var centerMinute: Int {
        let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
        let totalMinutes = -normalizedOffset * 24.0 * 60.0
        let minutes = Int(totalMinutes.rounded())
        let wrapped = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60)
        return wrapped % 60
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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Внешняя квадратная окантовка
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.clear, lineWidth: 0)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(colorScheme == .dark ? Color.black : Color.white)
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
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
        .onAppear {
            syncWithCurrentTime()
            syncCitiesToViewModel()
            sendPreviewIfNeeded()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            syncCitiesToViewModel()
        }
    }
    
    // Синхронизация с текущим временем при появлении
    private func syncWithCurrentTime() {
        let calendar = Calendar.current
        #if !WIDGET_EXTENSION
        if let th = ReminderManager.shared.temporaryHour,
           let tm = ReminderManager.shared.temporaryMinute {
            let total = th * 60 + tm
            drumOffset = -CGFloat(total) / (24.0 * 60.0)
            dragStartOffset = drumOffset
            return
        }
        #endif
        let currentHour = calendar.component(.hour, from: baseTime)
        let currentMinute = calendar.component(.minute, from: baseTime)
        let totalMinutes = currentHour * 60 + currentMinute
        drumOffset = -CGFloat(totalMinutes) / (24.0 * 60.0)
        dragStartOffset = drumOffset
    }
    
    // MARK: - Левая часть с блоками
    private var leftSide: some View {
        VStack(spacing: 12) {
            // Блок 1 - Локальный город с часами
            localCityBlock
                .frame(maxHeight: .infinity)

            // Блоки 2-5 - Остальные города (максимум 4, чтобы итого было 5)
            let otherCities = Array(viewModel.cities.dropFirst().prefix(4))
            ForEach(otherCities, id: \.id) { city in
                cityBlock(for: city)
                    .frame(maxHeight: .infinity)
            }

            // Заполняем пустыми блоками, если городов меньше 5
            ForEach(0..<max(0, 4 - otherCities.count), id: \.self) { _ in
                emptyBlock
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
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
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
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
            ForEach(-50...50, id: \.self) { index in
                let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
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
            ForEach(-50...50, id: \.self) { index in
                let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
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
            ForEach(-50...50, id: \.self) { index in
                let hour = ((index % 24) + 24) % 24
                let displayHour = {
                    if use12HourFormat {
                        let h = hour % 12
                        return h == 0 ? 12 : h
                    } else {
                        return hour == 0 ? 24 : hour
                    }
                }()
                
                // Вычисляем позицию этой метки
                let normalizedOffset = drumOffset.truncatingRemainder(dividingBy: 1.0)
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateDrum(value, in: geometry)
                }
                .onEnded { _ in
                    dragStartOffset = drumOffset
                }
        )

        #if os(macOS)
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
    
    
    #if os(macOS)
    private func handleScrollWheel(_ event: ScrollEvent, in geometry: GeometryProxy) {
        let totalHeight = geometry.size.height
        let itemHeight = totalHeight / 5.0
        let scrollDelta = event.scrollingDeltaY
        let hourChange = scrollDelta / itemHeight / 24.0
        drumOffset += hourChange
        dragStartOffset = drumOffset
        sendPreviewIfNeeded()
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
                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(isCenter ? 1.0 : 0.4))
                .frame(width: 12, height: 2)
            
            // Текст часа
            Text(String(format: "%02d", hour))
                .font(.system(size: isCenter ? 18 : 14, weight: isCenter ? .bold : .medium, design: .monospaced))
                .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(isCenter ? 1.0 : 0.6))
                .frame(width: 36, alignment: .center)
            
            // Короткая метка справа
            Rectangle()
                .fill((colorScheme == .dark ? Color.white : Color.black).opacity(isCenter ? 1.0 : 0.4))
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
            Text("·")
                .font(.system(size: 20, weight: .regular, design: .monospaced))
                .foregroundStyle(color)
            Text("L")
                .font(.system(size: 24, weight: .regular, design: .monospaced))
                .foregroundStyle(color)
                .rotationEffect(.degrees(90))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Блоки левой стороны
    
    private var localCityBlock: some View {
        ZStack {
            VStack(spacing: 8) {
                // Название локального города (неизменяемое, из главного вью)
                Text(overrideCityName ?? viewModel.cities.first?.name ?? "Local")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                
                // Часы (связаны с барабаном)
                HStack(spacing: 8) {
                    Text(formattedDisplayTime(displayTime))
                        .monospacedDigit()
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    if use12HourFormat {
                        Text(getAMPM(for: displayTime))
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            )
                    }
                }
            }
            
            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
        )
    }
    
    // Блок города с временем и жестами
    private func cityBlock(for city: WorldCity) -> some View {
        let cityTime = timeInCityTimeZone(displayTime, timezone: city.timeZone)
        let cityHour = Calendar.current.component(.hour, from: cityTime)
        let cityMinute = Calendar.current.component(.minute, from: cityTime)

        return ZStack {
            VStack(spacing: 8) {
                // Название города
                Text(city.name)
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)

                // Время города
                HStack(spacing: 8) {
                    Text(formattedTime(cityTime))
                        .monospacedDigit()
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    if use12HourFormat {
                        Text(getAMPM(for: cityTime))
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            )
                    }
                }
            }

            // Винты в углах
            cornerScrews
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                )
        )
        // Обычный тап для переключения барабана на время города
        .onTapGesture {
            switchDrumToCity(hour: cityHour, minute: cityMinute)
        }
        // Long press для активации напоминания
        .onLongPressGesture {
            activateReminderForCity(hour: cityHour, minute: cityMinute)
        }
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
                .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
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
        
        drumOffset = dragStartOffset + hourChange
        sendPreviewIfNeeded()
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
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = use12HourFormat ? "h:mm" : "HH:mm"
        return formatter.string(from: date)
    }

    private func getAMPM(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
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
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        formatter.timeZone = .current
        formatter.dateFormat = use12HourFormat ? "h:mm" : "HH:mm"
        return formatter.string(from: date)
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

        sendPreviewIfNeeded()
    }

    // Активирует напоминание при long press
    private func activateReminderForCity(hour: Int, minute: Int) {
        #if !WIDGET_EXTENSION
        // Создаём напоминание на основе часа и минуты города
        let reminder = ClockReminder(
            hour: hour,
            minute: minute,
            date: nil,  // Ежедневное напоминание
            isEnabled: true
        )
        Task {
            await ReminderManager.shared.setReminder(reminder)
        }
        #endif
    }
}

#if DEBUG
struct AlternativeClockView_Previews: PreviewProvider {
    static var previews: some View {
        AlternativeClockView()
    }
}
#endif
