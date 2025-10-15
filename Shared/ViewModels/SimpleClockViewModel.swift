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
    // tickIndex = 0 → текущее время
    // tickIndex = 4 → +1 час (4 × 15 мин)
    // tickIndex = -4 → -1 час
    
    @Published var tickIndex: Int = 0
    @Published var isDragging = false
    
    // РЕЖИМ 1 vs РЕЖИМ 2
    @Published private(set) var isInTimerMode = true  // true = Режим 1 (точное время), false = Режим 2 (драг)
    private var frozenTime: Date?  // Зафиксированное время при входе в Режим 2
    
    // Вычисляемый угол для View
    // tickIndex → угол вращения циферблата (стрелки НЕПОДВИЖНЫ)
    var rotationAngle: Double {
        Double(tickIndex) * ClockConstants.degreesPerTick * .pi / 180.0
    }
    
    // Время для вычисления стрелок
    var timeForArrows: Date {
        if isInTimerMode {
            // РЕЖИМ 1: точное время (игнорируем tickIndex)
            return currentTime
        } else {
            // РЕЖИМ 2: frozenTime + tickIndex смещение
            let base = frozenTime ?? currentTime
            let offset = Double(tickIndex * minutesPerTick * 60)
            return base.addingTimeInterval(offset)
        }
    }
    
    private let totalTicks = 96  // 24 часа × 4 = 96 тиков по 15 мин
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
    
    // Инерция (тики в секунду!)
    private var inertiaVelocity: Double = 0
    private var inertiaStartTime: Double = 0
    private var inertiaStartIndex: Int = 0
    private let snapVelocityThreshold: Double = 0.5
    
    // Haptic
    private let hapticFeedback = HapticFeedback.shared
    private var lastHapticTickIndex: Int?
    
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
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePhysics()
            }
        }
    }
    
    // MARK: - Physics (ПРОСТАЯ!)
    private func updatePhysics() {
        guard !isDragging else { return }
        guard abs(inertiaVelocity) > snapVelocityThreshold else {
            inertiaVelocity = 0
            return
        }
        
        let now = CACurrentMediaTime()
        let elapsed = now - inertiaStartTime
        
        // Затухание
        let damping = 0.95
        let currentVelocity = inertiaVelocity * pow(damping, elapsed * 60.0)
        
        if abs(currentVelocity) > snapVelocityThreshold {
            // Обновляем индекс от времени
            let ticksChange = inertiaVelocity * elapsed * (1.0 - pow(damping, elapsed * 60.0)) / (1.0 - damping)
            tickIndex = inertiaStartIndex + Int(round(ticksChange))
            
            // Хаптика
            if tickIndex != lastHapticTickIndex {
                let type = HapticFeedback.tickType(for: tickIndex)
                hapticFeedback.playTickCrossing(tickType: type, tickIndex: tickIndex)
                lastHapticTickIndex = tickIndex
            }
        } else {
            inertiaVelocity = 0
        }
    }
    
    // MARK: - Drag Handling (ПРОСТАЯ!)
    func startDrag(at location: CGPoint, in geometry: GeometryProxy) {
        // ПЕРЕХОД В РЕЖИМ 2: свободное вращение
        if isInTimerMode {
            isInTimerMode = false
            frozenTime = currentTime  // Фиксируем текущее время
            tickIndex = 0  // Сбрасываем смещение
        }
        
        isDragging = true
        dragStartTickIndex = tickIndex
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        dragStartAngle = atan2(location.y - center.y, location.x - center.x)
        lastDragAngle = dragStartAngle
        lastDragTime = CACurrentMediaTime()
        
        inertiaVelocity = 0
        hapticFeedback.prepare()
        lastHapticTickIndex = tickIndex
    }
    
    func updateDrag(at location: CGPoint, in geometry: GeometryProxy) {
        guard isDragging else { return }

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let currentAngle = atan2(location.y - center.y, location.x - center.x)

        // Разница углов
        var angleDelta = currentAngle - dragStartAngle
        angleDelta = atan2(sin(angleDelta), cos(angleDelta))  // Apple нормализация

        // Конвертируем в индекс
        let rotation = angleDelta / (2.0 * .pi)
        let ticksDelta = Int(round(rotation * Double(totalTicks)))
        
        tickIndex = dragStartTickIndex + ticksDelta
        
        // Хаптика
        if tickIndex != lastHapticTickIndex {
            let type = HapticFeedback.tickType(for: tickIndex)
            hapticFeedback.playTickCrossing(tickType: type, tickIndex: tickIndex)
            lastHapticTickIndex = tickIndex
        }
        
        lastDragAngle = currentAngle
    }
    
    func endDrag() {
        isDragging = false
        
        // Вычисляем скорость (тиков в секунду)
        let now = CACurrentMediaTime()
        let dt = now - lastDragTime
        
        if dt > 0 && dt < 0.1 {  // Только если быстрый жест
            let angleDelta = lastDragAngle - dragStartAngle
            let normalizedDelta = atan2(sin(angleDelta), cos(angleDelta))
            let rotation = normalizedDelta / (2.0 * .pi)
            let ticksDelta = rotation * Double(totalTicks)
            inertiaVelocity = ticksDelta / dt
            
            if abs(inertiaVelocity) > snapVelocityThreshold {
                inertiaStartTime = now
                inertiaStartIndex = tickIndex
            } else {
                inertiaVelocity = 0
            }
        } else {
            inertiaVelocity = 0
        }
    }
    
    // MARK: - Tap Center Button
    func resetRotation() {
        // ВОЗВРАТ В РЕЖИМ 1: точное время
        tickIndex = 0
        inertiaVelocity = 0
        isInTimerMode = true
        frozenTime = nil
    }
    
    // Для совместимости с напоминаниями
    func confirmPreviewReminder() async {
        await ReminderManager.shared.confirmPreview()
    }
    
    // Physics control (заглушки для совместимости)
    func suspendPhysics() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }
    
    func resumePhysics() {
        guard physicsTimer == nil else { return }
        setupPhysics()
    }
    
    // MARK: - Computed Properties
    // Для совместимости с напоминаниями (используем timeForArrows)
    var offsetTime: Date {
        timeForArrows
    }
    
    func arrowAngle(for city: WorldCity) -> Double {
        guard let timeZone = city.timeZone else { return 0 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        // Используем timeForArrows - автоматически учитывает режим
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
}
