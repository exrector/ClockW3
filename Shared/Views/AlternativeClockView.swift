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
    
    var overrideColorScheme: ColorScheme? = nil
    
    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
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
        var components = calendar.dateComponents([.year, .month, .day], from: viewModel.currentTime)
        components.hour = centerHour
        components.minute = centerMinute
        components.second = 0
        return calendar.date(from: components) ?? viewModel.currentTime
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Левая часть - 66%
                leftSide
                    .frame(width: geometry.size.width * 0.66)
                
                // Правая часть - 33%
                rightSide
                    .frame(width: geometry.size.width * 0.34)
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
        }
        .onAppear {
            syncWithCurrentTime()
        }
    }
    
    // Синхронизация с текущим временем при появлении
    private func syncWithCurrentTime() {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: viewModel.currentTime)
        let currentMinute = calendar.component(.minute, from: viewModel.currentTime)
        
        // Устанавливаем начальное положение барабана с учетом минут
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
            
            // Блок 2 - Пустой
            emptyBlock
                .frame(maxHeight: .infinity)
            
            // Блок 3 - Пустой
            emptyBlock
                .frame(maxHeight: .infinity)
            
            // Блок 4 - Пустой
            emptyBlock
                .frame(maxHeight: .infinity)
            
            // Блок 5 - Пустой
            emptyBlock
                .frame(maxHeight: .infinity)
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
            // Генерируем достаточно меток для бесконечной прокрутки
            ForEach(-50...50, id: \.self) { index in
                let hour = ((index % 24) + 24) % 24
                let displayHour = hour == 0 ? 24 : hour
                
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
    // Обработка скролла трекпада/мыши
    private func handleScrollWheel(_ event: ScrollEvent, in geometry: GeometryProxy) {
        let totalHeight = geometry.size.height
        let itemHeight = totalHeight / 5.0
        
        // Используем deltaY для вертикального скролла
        let scrollDelta = event.scrollingDeltaY
        let hourChange = scrollDelta / itemHeight / 24.0
        
        drumOffset += hourChange
        dragStartOffset = drumOffset
    }
    #endif
    
    // Минутная метка (короткая)
    private func minuteMark() -> some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 8, height: 1)
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
    
    // Центральная риска (фиксированная, центрирована по барабану)
    private var centerIndicator: some View {
        HStack(spacing: 0) {
            // Левая линия
            Rectangle()
                .fill(Color.red)
                .frame(width: 24, height: 3)
                .padding(.trailing, 4)
            
            // Пространство для цифр (совпадает с шириной текста часа в барабане)
            Color.clear
                .frame(width: 36)
            
            // Правая линия
            Rectangle()
                .fill(Color.red)
                .frame(width: 24, height: 3)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Блоки левой стороны
    
    private var localCityBlock: some View {
        ZStack {
            VStack(spacing: 8) {
                // Название локального города
                Text(TimeZone.current.localizedName(for: .standard, locale: .current) ?? "Local")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                
                // Часы (отображаем время из барабана)
                Text(displayTime, style: .time)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
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
    
    // Винты в углах блока
    private var cornerScrews: some View {
        GeometryReader { geometry in
            let screwSize: CGFloat = 12
            let inset: CGFloat = 16 // Увеличил отступ
            
            ZStack {
                // Верхний левый
                Text("⊗")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: inset)
                
                // Верхний правый
                Text("⊕")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: geometry.size.width - inset, y: inset)
                
                // Нижний левый
                Text("⊕")
                    .font(.system(size: screwSize))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .position(x: inset, y: geometry.size.height - inset)
                
                // Нижний правый
                Text("⊗")
                    .font(.system(size: screwSize))
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
    }
}

#if DEBUG
struct AlternativeClockView_Previews: PreviewProvider {
    static var previews: some View {
        AlternativeClockView()
    }
}
#endif
