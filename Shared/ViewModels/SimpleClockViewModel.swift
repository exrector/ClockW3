import SwiftUI
import Foundation
import Combine
import QuartzCore

// MARK: - Simple Clock View Model (Tick-Based Architecture)
/// Радикально упрощенная архитектура на индексах вместо углов
/// Никаких накоплений ошибок, магнитов, сложных нормализаций
@MainActor
class SimpleClockViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var cities: [WorldCity] = WorldCity.defaultCities
    
    // ============================================
    // АРХИТЕКТУРА: ИНДЕКСЫ ВМЕСТО УГЛОВ
    // ============================================
    @Published var tickIndex: Int = 0
    @Published var isDragging = false
    @Published private(set) var isCoasting = false
    
    // РЕЖИМ 1 vs РЕЖИМ 2
    @Published private(set) var isInTimerMode = true  // true = Режим 1, false = Режим 2
    private var frozenTime: Date?  // Зафиксированное (округлённое) время при входе в Режим 2
    
    // Вычисляемый угол для View (контейнер)
    var rotationAngle: Double {
        let step = ClockConstants.degreesPerTick * .pi / 180.0
        return -Double(tickIndex) * step
    }
    
    // Время для вычисления стрелок
    var timeForArrows: Date {
        if isInTimerMode {
            return currentTime
        } else {
            return frozenTime ?? currentTime
        }
    }
    
    private let totalTicks = 96
    private let minutesPerTick = 15
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var physicsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Drag
    private var dragStartTickIndex: Int = 0
    private var dragStartAngle: Double = 0
    private var lastDragAngle: Double = 0
    private var lastDragTime: Double = 0
    private var prevDragAngle: Double = 0
    private var prevDragTime: Double = 0
    private var cumulativeDragAngle: Double = 0
    // Последнее реальное событие drag (для авто-перехода в инерцию, если поток оборвался)
    private var lastDragEventTime: Double = 0
    // Маркер первого шага драга для стабилизации старта
    private var isFreshDrag: Bool = false
    
    // Инерция (тики в секунду)
    private var inertiaVelocity: Double = 0
    private var inertiaStartTime: Double = 0
    private var inertiaStartIndex: Int = 0
    private let snapVelocityThreshold: Double = 2.0
    
    // Haptic
    private let hapticFeedback = HapticFeedback.shared
    private var lastHapticTickIndex: Int?
    // Кэш для экономного обновления превью (обновлять только при смене тика)
    private var lastPreviewTickIndexSent: Int?
    
    // MARK: - Initialization
    init() {
        startTimeUpdates()
        setupPhysics()
        hapticFeedback.prepare()
    }
    
    deinit {
        timer?.invalidate()
        physicsTimer?.invalidate()
    }
    
    // MARK: - Time Updates
    private func startTimeUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = Date()
            }
        }
    }
    
    private func setupPhysics() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePhysics()
            }
        }
        physicsTimer = timer
        // В .common, чтобы не замирал во время скролла
        RunLoop.main.add(timer, forMode: .common)
    }
    
    // MARK: - Physics (ПРОСТАЯ!)
    private func updatePhysics() {
        // Пока палец на экране (идёт drag) — физика не вмешивается и инерция не запускается
        if isDragging {
            return
        }
        
        #if os(macOS)
        // На macOS полностью отключаем коастинг/инерцию — мгновенная фиксация
        inertiaVelocity = 0
        if isCoasting { isCoasting = false }
        return
        #else
        guard abs(inertiaVelocity) > snapVelocityThreshold else {
            inertiaVelocity = 0
            if isCoasting { isCoasting = false }
            return
        }
        
        let now = CACurrentMediaTime()
        let elapsed = now - inertiaStartTime
        
        // Затухание
        let damping = 0.92
        let decayFactor = pow(damping, elapsed)
        let currentVelocity = inertiaVelocity * decayFactor
        
        if abs(currentVelocity) > snapVelocityThreshold {
            // S = V0 * (1 - e^(-k*t)) / k, k = -ln(damping)
            let k = -log(damping)
            let displacement = inertiaVelocity * (1.0 - decayFactor) / k
            
            let newIndex = inertiaStartIndex + Int(round(displacement))
            
            if newIndex != tickIndex {
                tickIndex = newIndex
                
                if tickIndex != lastHapticTickIndex {
                    let type = HapticFeedback.tickType(for: tickIndex)
                    hapticFeedback.playTickCrossing(tickType: type, tickIndex: tickIndex)
                    lastHapticTickIndex = tickIndex
                }
                // Обновляем превью только при смене тика
                if lastPreviewTickIndexSent != tickIndex {
                    updatePreviewReminder()
                    lastPreviewTickIndexSent = tickIndex
                }
            }
        } else {
            inertiaVelocity = 0
            if isCoasting { isCoasting = false }
        }
        #endif
    }
    
    // MARK: - Drag Handling (ПРОСТАЯ!)
    func startDrag(at location: CGPoint, in geometry: GeometryProxy) {
        // Переход в Режим 2: фиксируем время, ОКРУГЛЁННОЕ к ближайшей четверти часа
        if isInTimerMode {
            isInTimerMode = false
            frozenTime = roundToNearestQuarterHour(currentTime)
            tickIndex = 0
        }
        
        isDragging = true
        dragStartTickIndex = tickIndex
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        dragStartAngle = atan2(location.y - center.y, location.x - center.x)
        lastDragAngle = dragStartAngle
        lastDragTime = CACurrentMediaTime()
        prevDragAngle = lastDragAngle
        prevDragTime = lastDragTime
        lastDragEventTime = lastDragTime
        
        cumulativeDragAngle = 0
        
        inertiaVelocity = 0
        isCoasting = false
        hapticFeedback.prepare()
        lastHapticTickIndex = tickIndex
        isFreshDrag = true
        
        // Начинаем показывать превью времени сразу при входе в режим 2
        updatePreviewReminder()
        lastPreviewTickIndexSent = tickIndex
    }
    
    func updateDrag(at location: CGPoint, in geometry: GeometryProxy) {
        guard isDragging else { return }

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let currentAngle = atan2(location.y - center.y, location.x - center.x)

        var smallDelta = atan2(sin(currentAngle - lastDragAngle), cos(currentAngle - lastDragAngle))
        // Однократно стабилизируем первый шаг: кламп и лёгкое сглаживание
        if isFreshDrag {
            #if os(macOS)
            // На macOS старт делаем чуть жёстче, чтобы избежать "перестрела"
            let clamp: Double = 0.18 // ~10.3°
            #else
            let clamp: Double = 0.22 // ~12.6°
            #endif
            if smallDelta > clamp { smallDelta = clamp }
            if smallDelta < -clamp { smallDelta = -clamp }
            #if os(macOS)
            smallDelta *= 0.6
            #else
            smallDelta *= 0.7
            #endif
            isFreshDrag = false
        }
        cumulativeDragAngle += smallDelta

        let rotationTurns = cumulativeDragAngle / (2.0 * .pi)
        let ticksDelta = Int(round(-rotationTurns * Double(totalTicks)))
        
        tickIndex = dragStartTickIndex + ticksDelta

        let now = CACurrentMediaTime()
        prevDragAngle = lastDragAngle
        prevDragTime = lastDragTime
        lastDragAngle = currentAngle
        lastDragTime = now
        lastDragEventTime = now
        
        if tickIndex != lastHapticTickIndex {
            let type = HapticFeedback.tickType(for: tickIndex)
            hapticFeedback.playTickCrossing(tickType: type, tickIndex: tickIndex)
            lastHapticTickIndex = tickIndex
        }
        
        // Обновляем превью во время драга только при смене тика
        if lastPreviewTickIndexSent != tickIndex {
            updatePreviewReminder()
            lastPreviewTickIndexSent = tickIndex
        }
    }
    
    func endDrag() {
        isDragging = false
        
        #if os(macOS)
        // На macOS — без инерции. Фиксируемся на текущем тике сразу.
        inertiaVelocity = 0
        isCoasting = false
        #else
        let now = CACurrentMediaTime()
        let dt = now - prevDragTime
        
        if dt > 0 {
            let angleDelta = lastDragAngle - prevDragAngle
            let normalizedDelta = atan2(sin(angleDelta), cos(angleDelta))
            let rotation = normalizedDelta / (2.0 * .pi)
            let ticksDelta = -rotation * Double(totalTicks)
            inertiaVelocity = ticksDelta / dt
            
            if abs(inertiaVelocity) > snapVelocityThreshold {
                inertiaStartTime = now
                inertiaStartIndex = tickIndex
                isCoasting = true
            } else {
                inertiaVelocity = 0
                isCoasting = false
            }
        } else {
            inertiaVelocity = 0
        }
        #endif
        
        // Финализируем превью после завершения драга (если тик сменился)
        if lastPreviewTickIndexSent != tickIndex {
            updatePreviewReminder()
            lastPreviewTickIndexSent = tickIndex
        }
    }
    
    // MARK: - Tap Center Button
    func resetRotation() {
        tickIndex = 0
        inertiaVelocity = 0
        isInTimerMode = true
        frozenTime = nil
        // Выходим из режима 2 — очищаем превью
        ReminderManager.shared.clearPreviewReminder()
    }
    
    // Для совместимости с напоминаниями
    func confirmPreviewReminder() async {
        await ReminderManager.shared.confirmPreview()
    }
    
    // Physics control
    func suspendPhysics() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }
    
    func resumePhysics() {
        guard physicsTimer == nil else { return }
        setupPhysics()
    }
    
    // MARK: - Computed Properties
    var offsetTime: Date {
        timeForArrows
    }
    
    func arrowAngle(for city: WorldCity) -> Double {
        guard let timeZone = city.timeZone else { return 0 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let hour = calendar.component(.hour, from: timeForArrows)
        let minute = calendar.component(.minute, from: timeForArrows)
        
        return ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
    }
    
    func weekdayNumber(for city: WorldCity) -> Int {
        guard let timeZone = city.timeZone else { return 1 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        return calendar.component(.weekday, from: timeForArrows)
    }
    
    // MARK: - Helpers
    private func roundToNearestQuarterHour(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        let rounded = Int((Double(minute) / 15.0).rounded()) * 15
        
        // Перенос часа вперёд, если было 53..59 → 60
        var carryHour = 0
        var finalMinute = rounded
        if rounded == 60 {
            finalMinute = 0
            carryHour = 1
        }
        
        comps.minute = finalMinute
        comps.second = 0
        
        var roundedDate = calendar.date(from: comps) ?? date
        if carryHour == 1 {
            roundedDate = calendar.date(byAdding: .hour, value: 1, to: roundedDate) ?? roundedDate
        }
        return roundedDate
    }
    
    // MARK: - Preview Binding (Режим 2 → превью напоминания)
    
    // Выбранное время в режиме 2: frozenTime сдвигаем в ТОМ ЖЕ направлении, что визуальное вращение.
    // Контейнер крутится так: rotationAngle = -tickIndex * step, поэтому для времени нужен обратный знак.
    private var selectedTimeForPreview: Date? {
        guard !isInTimerMode, let base = frozenTime else { return nil }
        return Calendar.current.date(byAdding: .minute, value: -tickIndex * minutesPerTick, to: base)
    }
    
    // Обновляем ReminderManager.previewReminder для отображения в Settings/Preview
    private func updatePreviewReminder() {
        // Показываем превью только если нет сохранённого напоминания
        if ReminderManager.shared.currentReminder != nil {
            ReminderManager.shared.clearPreviewReminder()
            return
        }
        
        // В режиме 1 превью очищаем
        guard let date = selectedTimeForPreview else {
            ReminderManager.shared.clearPreviewReminder()
            return
        }
        
        var calendar = Calendar.current
        calendar.timeZone = .current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Формируем one-time превью с ближайшей датой
        let nextDate = ClockReminder.nextTriggerDate(hour: hour, minute: minute, from: currentTime)
        let reminder = ClockReminder(hour: hour, minute: minute, date: nextDate, isEnabled: true)
        ReminderManager.shared.setPreviewReminder(reminder)
    }
    
    // Автозавершение драга, если поток событий пропал (например, начался скролл)
    private func performAutoEndDrag() {
        isDragging = false
        let now = CACurrentMediaTime()
        let dt = now - prevDragTime
        if dt > 0 {
            let angleDelta = lastDragAngle - prevDragAngle
            let normalizedDelta = atan2(sin(angleDelta), cos(angleDelta))
            let rotation = normalizedDelta / (2.0 * .pi)
            let ticksDelta = -rotation * Double(totalTicks)
            inertiaVelocity = ticksDelta / dt
            if abs(inertiaVelocity) > snapVelocityThreshold {
                inertiaStartTime = now
                inertiaStartIndex = tickIndex
                isCoasting = true
            } else {
                inertiaVelocity = 0
                isCoasting = false
            }
        } else {
            inertiaVelocity = 0
        }
        // Обновить превью при необходимости
        if lastPreviewTickIndexSent != tickIndex {
            updatePreviewReminder()
            lastPreviewTickIndexSent = tickIndex
        }
    }
}
