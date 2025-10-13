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
    private var lastRotationDirection: Double = 0
    private let zeroSnapThreshold: Double = 10.0 * .pi / 180.0
    private let directionEpsilon: Double = 1e-4
    private let magnetHardSnapEpsilon: Double = 0.12 * .pi / 180.0
    
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
        let localIdentifier = TimeZone.current.identifier
        if cities[index].timeZoneIdentifier == localIdentifier {
            return
        }
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
        updateLastRotationDirection(with: angleDelta)
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
        if abs(dragVelocity) > directionEpsilon {
            updateLastRotationDirection(with: dragVelocity)
        }

        // Во время драга НЕ притягиваемся, чтобы не ломать естественное движение
    }
    
    func endDrag() {
        isDragging = false
        
        // Применяем инерцию и снэп к ближайшему тику
        let inferredVelocity = velocityFromSamples()
        dragVelocity = inferredVelocity
        dragSamples.removeAll()
        if abs(inferredVelocity) > directionEpsilon {
            updateLastRotationDirection(with: inferredVelocity)
        }
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
            updateLastRotationDirection(with: dragVelocity)
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
        let distance = abs(delta)
        guard distance < threshold else { return false }

        if distance <= magnetHardSnapEpsilon {
            setRotationNoAnimation(target)
            return true
        }

        let clamped = max(0.0, min(1.0, 1.0 - distance / threshold))
        let easing = pow(clamped, 1.6)
        let adaptiveLerp = min(1.0, lerp + (1.0 - lerp) * easing)
        rotationAngle += delta * adaptiveLerp
        return true
    }

    private func updateLastRotationDirection(with value: Double) {
        guard abs(value) > directionEpsilon else { return }
        lastRotationDirection = value > 0 ? 1 : -1
    }

    private func setRotationNoAnimation(_ value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            rotationAngle = value
        }
    }

    // MARK: - Reset Functions
    func resetRotation() {
        let currentVelocity = dragVelocity
        dragVelocity = 0
        dragSamples.removeAll()
        isDragging = false

        let normalizedOffset = ClockConstants.normalizeAngle(rotationAngle)
        if abs(normalizedOffset) <= zeroSnapThreshold {
            let targetAngle = rotationAngle - normalizedOffset
            let duration = 0.12
            isSnapping = true
            withAnimation(.easeOut(duration: duration)) {
                rotationAngle = targetAngle
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self else { return }
                self.setRotationNoAnimation(0)
                self.dragVelocity = 0
                self.isSnapping = false
            }
            return
        }

        var direction = lastRotationDirection
        if abs(direction) <= directionEpsilon {
            if abs(currentVelocity) > directionEpsilon {
                direction = currentVelocity > 0 ? 1 : -1
            } else if abs(normalizedOffset) > directionEpsilon {
                direction = normalizedOffset > 0 ? 1 : -1
            } else {
                direction = 1
            }
        }

        let twoPi = Double.pi * 2
        let baseAngle = rotationAngle - normalizedOffset
        var delta = baseAngle - rotationAngle
        if direction >= 0 {
            while delta <= 0 {
                delta += twoPi
            }
        } else {
            while delta >= 0 {
                delta -= twoPi
            }
        }

        if abs(delta) <= directionEpsilon {
            setRotationNoAnimation(baseAngle)
            dragVelocity = 0
            lastRotationDirection = direction
            isSnapping = false
            setRotationNoAnimation(0)
            return
        }

        direction = delta > 0 ? 1 : -1
        lastRotationDirection = direction

        let targetAngle = rotationAngle + delta
        let angularDistance = abs(delta)
        let duration = min(0.75, max(0.2, (angularDistance / twoPi) * 0.45 + 0.18))

        isSnapping = true
        withAnimation(.easeOut(duration: duration)) {
            rotationAngle = targetAngle
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.setRotationNoAnimation(0)
            self.dragVelocity = 0
            self.isSnapping = false
        }
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
