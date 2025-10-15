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
    
    // Вычисляемый угол для View (обратная совместимость)
    var rotationAngle: Double {
        Double(tickIndex) * (2.0 * .pi / 96.0)
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
        Task { @MainActor in
            await initializeAsync()
        }
    }
    
    private func initializeAsync() async {
        startTimeUpdates()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
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
        tickIndex = 0
        inertiaVelocity = 0
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
    var offsetTime: Date {
        let offset = TimeInterval(tickIndex * minutesPerTick * 60)
        return currentTime.addingTimeInterval(offset)
    }
    
    func arrowAngle(for city: WorldCity) -> Double {
        guard let timeZone = city.timeZone else { return 0 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let hour = calendar.component(.hour, from: offsetTime)
        let minute = calendar.component(.minute, from: offsetTime)
        
        return ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
    }
    
    func weekdayNumber(for city: WorldCity) -> Int {
        guard let timeZone = city.timeZone else { return 1 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        return calendar.component(.weekday, from: offsetTime)
    }
}
