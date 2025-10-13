import SwiftUI
import Foundation
import Combine
import QuartzCore

// MARK: - Clock View Model
@MainActor
class ClockViewModel: ObservableObject {
    private struct DragSample {
        let time: TimeInterval
        let angle: Double
    }
    
    private struct RotationAnimation {
        let startAngle: Double
        let targetAngle: Double
        let duration: TimeInterval
        let startTime: CFTimeInterval
        let direction: Double
        let endHaptic: HapticFeedback.Strength?
        let completion: (() -> Void)?
    }
    
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var cities: [WorldCity] = WorldCity.defaultCities
    
    // Интерактивность
    @Published var rotationAngle: Double = 0 {
        didSet {
            if suppressTickHaptics {
                return
            }
            handleTickHaptics()
        }
    }
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
    private var lastHapticTick: Int?
    private var suppressTickHaptics = false
    private var rotationAnimation: RotationAnimation?
    
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
        handleTickHaptics(trigger: false)
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

        handleTickHaptics()

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
        handleTickHaptics(trigger: false)
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

        if let animation = rotationAnimation {
            let now = CACurrentMediaTime()
            let elapsed = now - animation.startTime
            let progress = animation.duration > 0 ? min(1.0, elapsed / animation.duration) : 1.0
            let eased = easeOutCubic(progress)
            let interpolated: Double

            if progress >= 1.0 {
                interpolated = animation.targetAngle
            } else {
                interpolated = animation.startAngle + (animation.targetAngle - animation.startAngle) * eased
            }

            if abs(interpolated - rotationAngle) > 1e-9 {
                rotationAngle = interpolated
            }

            if progress >= 1.0 {
                rotationAnimation = nil
                isSnapping = false
                dragVelocity = 0
                updateLastRotationDirection(with: animation.direction)
                if let endHaptic = animation.endHaptic {
                    HapticFeedback.impact(endHaptic)
                }
                animation.completion?()
            }
            return
        }

        guard !isSnapping else { return }

        dragVelocity *= 0.985

        if abs(dragVelocity) > snapVelocityThreshold {
            updateLastRotationDirection(with: dragVelocity)
            rotationAngle += dragVelocity / 60.0
            applyMagnetWhileCoasting()
            handleTickHaptics()
            return
        }

        dragVelocity = 0

        if !isSnapping {
            snapToNearestTick()
            handleTickHaptics(trigger: false)
        }
    }
    
    private func applyInertiaAndSnap() {
        // Инерция и снэп обрабатываются в updatePhysics без резких анимаций
        // Здесь ничего не делаем — оставляем текущую dragVelocity
    }
    
    private func startRotationAnimation(
        to targetAngle: Double,
        duration: TimeInterval,
        startHaptic: HapticFeedback.Strength? = nil,
        endHaptic: HapticFeedback.Strength? = nil,
        completion: (() -> Void)? = nil
    ) {
        let delta = targetAngle - rotationAngle
        dragVelocity = 0
        dragSamples.removeAll()
        if abs(delta) <= directionEpsilon {
            completion?()
            return
        }

        let clampedDuration = max(0.01, duration)
        rotationAnimation = RotationAnimation(
            startAngle: rotationAngle,
            targetAngle: targetAngle,
            duration: clampedDuration,
            startTime: CACurrentMediaTime(),
            direction: delta > 0 ? 1 : -1,
            endHaptic: endHaptic,
            completion: completion
        )
        isSnapping = true
        if let startHaptic = startHaptic {
            HapticFeedback.impact(startHaptic)
        }
    }
    
    private func snapToNearestTick() {
        guard !isSnapping else { return }
        
        let nearestTick = ClockConstants.nearestTickAngle(rotationAngle)
        var delta = nearestTick - rotationAngle
        delta = ClockConstants.normalizeAngle(delta)
        if abs(delta) < 1e-4 {
            setRotationNoAnimation(nearestTick)
            dragVelocity = 0
            if abs(delta) > directionEpsilon {
                lastRotationDirection = delta > 0 ? 1 : -1
            }
            return
        }

        lastRotationDirection = delta > 0 ? 1 : -1

        startRotationAnimation(
            to: nearestTick,
            duration: ClockConstants.snapDuration,
            startHaptic: .medium,
            endHaptic: nil
        ) { [weak self] in
            self?.handleTickHaptics(trigger: false)
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
            HapticFeedback.impact(.light)
            return true
        }

        let clamped = max(0.0, min(1.0, 1.0 - distance / threshold))
        let easing = pow(clamped, 1.6)
        let adaptiveLerp = min(1.0, lerp + (1.0 - lerp) * easing)
        rotationAngle += delta * adaptiveLerp
        handleTickHaptics()
        return true
    }

    private func updateLastRotationDirection(with value: Double) {
        guard abs(value) > directionEpsilon else { return }
        lastRotationDirection = value > 0 ? 1 : -1
    }

    private func easeOutCubic(_ t: Double) -> Double {
        let clamped = max(0.0, min(1.0, t))
        let inv = 1.0 - clamped
        return 1.0 - inv * inv * inv
    }

    private func setRotationNoAnimation(_ value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        suppressTickHaptics = true
        withTransaction(transaction) {
            rotationAngle = value
        }
        suppressTickHaptics = false
        handleTickHaptics(trigger: false)
    }

    private func handleTickHaptics(trigger: Bool = true) {
        let step = ClockConstants.quarterTickStepRadians
        guard step > 0 else { return }
        let currentTick = Int(round(rotationAngle / step))
        if let last = lastHapticTick, currentTick == last {
            return
        }
        if !trigger {
            lastHapticTick = currentTick
            return
        }
        guard let last = lastHapticTick else {
            lastHapticTick = currentTick
            return
        }
        lastHapticTick = currentTick
        if currentTick == last { return }

        let hourRatio = ClockConstants.hourTickStepRadians / step
        let hourInterval = max(1, Int(round(hourRatio)))
        let normalized = ((currentTick % hourInterval) + hourInterval) % hourInterval
        if normalized == 0 {
            HapticFeedback.impact(.medium)
        } else {
            HapticFeedback.impact(.light)
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
            let duration = 0.16
            let delta = targetAngle - rotationAngle
            if abs(delta) > directionEpsilon {
                lastRotationDirection = delta > 0 ? 1 : -1
            }
            startRotationAnimation(
                to: targetAngle,
                duration: duration,
                startHaptic: .medium,
                endHaptic: .heavy
            ) { [weak self] in
                guard let self else { return }
                self.setRotationNoAnimation(0)
                self.dragVelocity = 0
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
            HapticFeedback.impact(.heavy)
            return
        }

        direction = delta > 0 ? 1 : -1
        lastRotationDirection = direction

        let targetAngle = rotationAngle + delta
        let angularDistance = abs(delta)
        let duration = min(0.75, max(0.2, (angularDistance / twoPi) * 0.45 + 0.18))

        startRotationAnimation(
            to: targetAngle,
            duration: duration,
            startHaptic: .medium,
            endHaptic: .heavy
        ) { [weak self] in
            guard let self else { return }
            self.setRotationNoAnimation(0)
            self.dragVelocity = 0
        }
    }
    
    func resetToCurrentTime() {
        // Поворачиваем к текущему времени местного часового пояса
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        isDragging = false
        
        let targetAngle = ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
        let destination = -targetAngle
        let delta = destination - rotationAngle
        if abs(delta) > directionEpsilon {
            lastRotationDirection = delta > 0 ? 1 : -1
        }

        startRotationAnimation(
            to: destination,
            duration: 0.5,
            startHaptic: .light,
            endHaptic: .medium
        )
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
