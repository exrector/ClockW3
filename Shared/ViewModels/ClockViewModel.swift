import SwiftUI
import Foundation
import Combine

// MARK: - Clock View Model
@MainActor
class ClockViewModel: ObservableObject {
    private struct DragSample {
        let time: TimeInterval
        let angle: Double
    }
    
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var cities: [WorldCity] = WorldCity.defaultCities
    
    // Интерактивность
    @Published var rotationAngle: Double = 0
    @Published var isDragging = false
    @Published var isSnapping = false

    // MARK: - Private Properties
    private var timer: Timer?
    private var physicsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastDragAngle: Double = 0
    private var dragVelocity: Double = 0
    private var lastDragTime: Date = Date()
    private var dragSamples: [DragSample] = []
    private let maxDragSamples = 6
    private let snapVelocityThreshold: Double = 0.03
    
    // MARK: - Initialization
    init() {
        startTimeUpdates()
        setupDragPhysics()
    }
    
    deinit {
        timer?.invalidate()
        physicsTimer?.invalidate()
        timer = nil
        physicsTimer = nil
    }
    
    // MARK: - Time Management
    private func startTimeUpdates() {
        Task { @MainActor in
            refreshCurrentTime()
        }

        // Обновляем время каждую минуту
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshCurrentTime()
            }
        }
        timer?.tolerance = 0.2
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // MARK: - City Management
    func addCity(_ city: WorldCity) {
        cities.append(city)
    }
    
    func removeCity(at index: Int) {
        guard index < cities.count else { return }
        cities.remove(at: index)
    }
    
    
    // MARK: - Angle Calculations
    func arrowAngle(for city: WorldCity) -> Double {
        guard let timeZone = city.timeZone else { return 0 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        return ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
    }
    
    func weekdayNumber(for city: WorldCity) -> Int {
        guard let timeZone = city.timeZone else { return 1 }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        return calendar.component(.weekday, from: currentTime)
    }
    
    // MARK: - Drag Handling
    func startDrag(at location: CGPoint, in geometry: GeometryProxy) {
        isDragging = true
        isSnapping = false
        
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        lastDragAngle = atan2(location.y - center.y, location.x - center.x)
        lastDragTime = Date()
        dragVelocity = 0
        dragSamples.removeAll()
        dragSamples.append(DragSample(time: Date().timeIntervalSinceReferenceDate, angle: rotationAngle))
    }
    
    func updateDrag(at location: CGPoint, in geometry: GeometryProxy) {
        guard isDragging else { return }

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let currentAngle = atan2(location.y - center.y, location.x - center.x)

        var angleDelta = currentAngle - lastDragAngle
        angleDelta = ClockConstants.normalizeAngle(angleDelta)

        rotationAngle += angleDelta
        let nowReference = Date().timeIntervalSinceReferenceDate
        dragSamples.append(DragSample(time: nowReference, angle: rotationAngle))
        if dragSamples.count > maxDragSamples {
            dragSamples.removeFirst()
        }
        applyMagnetDuringDrag()

        // Вычисляем скорость для инерции
        let now = Date()
        let dt = now.timeIntervalSince(lastDragTime)
        if dt > 0 {
            dragVelocity = angleDelta / dt
        }

        lastDragAngle = currentAngle
        lastDragTime = now

        // Во время драга НЕ притягиваемся, чтобы не ломать естественное движение
    }
    
    func endDrag() {
        isDragging = false
        
        // Применяем инерцию и снэп к ближайшему тику
        let inferredVelocity = velocityFromSamples()
        dragVelocity = inferredVelocity
        dragSamples.removeAll()
        applyInertiaAndSnap()
    }
    
    // MARK: - Physics Simulation
    private func setupDragPhysics() {
        // Не создаём второй таймер, если уже есть
        guard physicsTimer == nil else { return }
        // Симуляция физики каждые 16ms (~60fps)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await MainActor.run {
                    self.updatePhysics()
                }
            }
        }
        physicsTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    private func updatePhysics() {
        guard !isDragging else { return }
        guard !isSnapping else { return }

        dragVelocity *= 0.985

        if abs(dragVelocity) > snapVelocityThreshold {
            rotationAngle += dragVelocity / 60.0
            applyMagnetWhileCoasting()
            return
        }

        dragVelocity = 0

        if !isSnapping {
            snapToNearestTick()
        }
    }
    
    private func applyInertiaAndSnap() {
        // Инерция и снэп обрабатываются в updatePhysics без резких анимаций
        // Здесь ничего не делаем — оставляем текущую dragVelocity
    }
    
    private func snapToNearestTick() {
        guard !isSnapping else { return }
        
        isSnapping = true
        let nearestTick = ClockConstants.nearestTickAngle(rotationAngle)
        
        withAnimation(.easeOut(duration: ClockConstants.snapDuration)) {
            rotationAngle = nearestTick
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + ClockConstants.snapDuration) { [weak self] in
            guard let self else { return }
            self.isSnapping = false
            self.dragVelocity = 0
        }
    }

    private func velocityFromSamples() -> Double {
        guard dragSamples.count >= 2,
              let first = dragSamples.first,
              let last = dragSamples.last else {
            return dragVelocity
        }
        let timeDelta = last.time - first.time
        guard timeDelta > 0.01 else { return dragVelocity }
        var angleDelta = last.angle - first.angle
        angleDelta = ClockConstants.normalizeAngle(angleDelta)
        return angleDelta / timeDelta
    }

    private func refreshCurrentTime() {
        currentTime = Date()
    }

    private func applyMagnetDuringDrag() {
        if applyMagnet(step: ClockConstants.hourTickStepRadians,
                       threshold: ClockConstants.hourMagneticThreshold,
                       lerp: 0.12) {
            return
        }
        if applyMagnet(step: ClockConstants.halfHourTickStepRadians,
                       threshold: ClockConstants.halfHourMagneticThreshold,
                       lerp: 0.10) {
            return
        }
        _ = applyMagnet(step: ClockConstants.quarterTickStepRadians,
                        threshold: ClockConstants.quarterHourMagneticThreshold,
                        lerp: 0.08)
    }

    private func applyMagnetWhileCoasting() {
        if applyMagnet(step: ClockConstants.hourTickStepRadians,
                       threshold: ClockConstants.hourMagneticThreshold,
                       lerp: 0.06) {
            return
        }
        if applyMagnet(step: ClockConstants.halfHourTickStepRadians,
                       threshold: ClockConstants.halfHourMagneticThreshold,
                       lerp: 0.05) {
            return
        }
        _ = applyMagnet(step: ClockConstants.quarterTickStepRadians,
                        threshold: ClockConstants.quarterHourMagneticThreshold,
                        lerp: 0.04)
    }

    @discardableResult
    private func applyMagnet(step: Double, threshold: Double, lerp: Double) -> Bool {
        guard step > 0 else { return false }
        let target = round(rotationAngle / step) * step
        var delta = target - rotationAngle
        delta = ClockConstants.normalizeAngle(delta)
        if abs(delta) < threshold {
            rotationAngle += delta * lerp
            return true
        }
        return false
    }

    // MARK: - Reset Functions
    func resetRotation() {
        // TODO: Implement reset rotation logic
    }
    
    func resetToCurrentTime() {
        // Поворачиваем к текущему времени местного часового пояса
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        let targetAngle = ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
        
        withAnimation(.easeOut(duration: 0.5)) {
            rotationAngle = -targetAngle  // Инвертируем, так как поворачиваем контейнер
        }
    }
    
    // MARK: - Physics control (for lifecycle/extensions)
    func suspendPhysics() {
        physicsTimer?.invalidate()
        physicsTimer = nil
    }
    
    func resumePhysics() {
        setupDragPhysics()
    }
}

