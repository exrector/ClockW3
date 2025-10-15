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
        let completion: (() -> Void)?
    }
    
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var cities: [WorldCity] = WorldCity.defaultCities
    
    // Интерактивность
    @Published var rotationAngle: Double = 0
    @Published var isDragging = false
    @Published var isSnapping = false
    
    private var hasUserInteracted = false  // Флаг взаимодействия

    // MARK: - Private Properties
    private var timer: Timer?
    private var physicsTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastDragAngle: Double = 0
    private var dragVelocity: Double = 0
    private var lastDragTime: Date = Date()
    private var dragSamples: [DragSample] = []
    private let maxDragSamples = 6
    private let snapVelocityThreshold: Double = 0.05  // Увеличено с 0.03 для более ранней остановки
    private var lastRotationDirection: Double = 0
    private let zeroSnapThreshold: Double = 10.0 * .pi / 180.0
    private let directionEpsilon: Double = 1e-4
    private let magnetHardSnapEpsilon: Double = 0.12 * .pi / 180.0
    private var rotationAnimation: RotationAnimation?
    private var magnetReferenceAngle: Double = 0
    private var magnetsEnabled: Bool = true

    // Haptic feedback
    private let hapticFeedback = HapticFeedback.shared
    private var lastHapticTickIndex: Int?

    
    // MARK: - Initialization
    init() {
        // Отложенная инициализация для быстрого запуска
        Task { @MainActor in
            await initializeAsync()
        }
    }
    
    private func initializeAsync() async {
        do {
            startTimeUpdates()
            updateMagnetReferenceAngle()
            
            // Отложенная инициализация физики и хаптики
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 сек
            setupDragPhysics()
            hapticFeedback.prepare()
        } catch {
            print("Initialization error: \(error)")
        }
    }
    
    deinit {
        timer?.invalidate()
        physicsTimer?.invalidate()
        timer = nil
        physicsTimer = nil
        dragSamples.removeAll()
    }
    
    // MARK: - Time Management
    private func startTimeUpdates() {
        timer?.invalidate()
        
        Task { @MainActor in
            refreshCurrentTime()
        }

        // Обновляем время каждую минуту
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.refreshCurrentTime()
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
        magnetsEnabled = true  // Включаем магниты обратно
        hasUserInteracted = true  // Пользователь начал взаимодействие

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        lastDragAngle = atan2(location.y - center.y, location.x - center.x)
        lastDragTime = Date()
        dragVelocity = 0
        dragSamples.removeAll()
        dragSamples.append(DragSample(time: Date().timeIntervalSinceReferenceDate, angle: rotationAngle))

        // Инициализируем хаптику при начале драга
        hapticFeedback.prepare()
        lastHapticTickIndex = HapticFeedback.tickIndex(for: rotationAngle)
    }
    
    func updateDrag(at location: CGPoint, in geometry: GeometryProxy) {
        guard isDragging else { return }

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let currentAngle = atan2(location.y - center.y, location.x - center.x)

        var angleDelta = currentAngle - lastDragAngle
        angleDelta = ClockConstants.normalizeAngle(angleDelta)

        // Применяем сглаживание для более плавного драга
        let smoothingFactor: Double = 0.7
        angleDelta *= smoothingFactor

        rotationAngle += angleDelta

        // Обновляем preview напоминания
        updatePreviewReminder()

        updateLastRotationDirection(with: angleDelta)
        let nowReference = Date().timeIntervalSinceReferenceDate
        dragSamples.append(DragSample(time: nowReference, angle: rotationAngle))
        if dragSamples.count > maxDragSamples {
            dragSamples.removeFirst()
        }
        applyMagnetDuringDrag()

        // Проверяем пересечение рисок и воспроизводим хаптик
        checkAndPlayTickHaptic(for: rotationAngle)

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

        // Обновляем preview после окончания драга
        updatePreviewReminder()

        // НЕ сбрасываем lastHapticTickIndex здесь, чтобы хаптика работала при инерции
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

                // Проверяем пересечение рисок во время анимации
                checkAndPlayTickHaptic(for: rotationAngle)

                // Обновляем preview во время анимации
                updatePreviewReminder()
            }

            if progress >= 1.0 {
                rotationAnimation = nil
                isSnapping = false
                dragVelocity = 0
                updateLastRotationDirection(with: animation.direction)
                animation.completion?()
            }
            return
        }

        guard !isSnapping else { return }

        dragVelocity *= 0.985

        if abs(dragVelocity) > snapVelocityThreshold {
            updateLastRotationDirection(with: dragVelocity)
            rotationAngle += dragVelocity / 60.0

            // Магниты во время инерции ОТКЛЮЧЕНЫ - они вызывают микро-откат
            // if hasUserInteracted {
            //     applyMagnetWhileCoasting()
            // }

            // Проверяем пересечение рисок при инерционном вращении
            checkAndPlayTickHaptic(for: rotationAngle)

            // Обновляем preview при инерции
            updatePreviewReminder()

            return
        }

        dragVelocity = 0

        if !isSnapping && hasUserInteracted {
            snapToNearestTick()
        }
    }
    
    private func applyInertiaAndSnap() {
        // Инерция и снэп обрабатываются в updatePhysics без резких анимаций
        // Здесь ничего не делаем — оставляем текущую dragVelocity
    }
    
    private func startRotationAnimation(
        to targetAngle: Double,
        duration: TimeInterval,
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
            completion: completion
        )
        isSnapping = true
    }
    
    private func snapToNearestTick() {
        guard magnetsEnabled else { return }
        guard !isSnapping else { return }
        guard hasUserInteracted else { return }  // Только если пользователь взаимодействовал
        
        // НЕ снэпим если пользователь не вращал (rotationAngle близок к 0)
        if abs(rotationAngle) < ClockConstants.quarterTickStepRadians / 2 {
            return
        }

        let nearestTick = quantizedRotation(angle: rotationAngle, step: ClockConstants.quarterTickStepRadians)
        var delta = nearestTick - rotationAngle
        
        // Нормализуем delta к кратчайшему пути
        while delta > .pi {
            delta -= 2 * .pi
        }
        while delta < -.pi {
            delta += 2 * .pi
        }
        
        #if DEBUG
        print("📍 SNAP: current=\(rotationAngle), target=\(nearestTick), delta=\(delta), direction=\(delta > 0 ? "→" : "←")")
        #endif
        
        if abs(delta) < 1e-4 {
            setRotationNoAnimation(nearestTick)
            dragVelocity = 0
            hasUserInteracted = false  // Сбрасываем сразу
            if abs(delta) > directionEpsilon {
                lastRotationDirection = delta > 0 ? 1 : -1
            }
            resetHapticState()
            return
        }

        lastRotationDirection = delta > 0 ? 1 : -1
        
        // Останавливаем инерцию перед snap
        dragVelocity = 0
        
        // Нормализуем угол для предотвращения накопления ошибки
        let normalizedTick = nearestTick.truncatingRemainder(dividingBy: 2 * .pi)
        setRotationNoAnimation(normalizedTick)
        hasUserInteracted = false
        resetHapticState()
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
        updateMagnetReferenceAngle()
    }

    private func applyMagnetDuringDrag() {
        guard magnetsEnabled else { return }
        if applyMagnet(step: ClockConstants.hourTickStepRadians,
                       threshold: ClockConstants.hourMagneticThreshold,
                       lerp: 0.18) {  // Увеличено с 0.12 до 0.18
            return
        }
        if applyMagnet(step: ClockConstants.halfHourTickStepRadians,
                       threshold: ClockConstants.halfHourMagneticThreshold,
                       lerp: 0.14) {  // Увеличено с 0.10 до 0.14
            return
        }
        _ = applyMagnet(step: ClockConstants.quarterTickStepRadians,
                        threshold: ClockConstants.quarterHourMagneticThreshold,
                        lerp: 0.08)
    }

    private func applyMagnetWhileCoasting() {
        guard magnetsEnabled else { return }
        guard hasUserInteracted else { return }  // Не применяем если пользователь не крутил
        if applyMagnet(step: ClockConstants.hourTickStepRadians,
                       threshold: ClockConstants.hourMagneticThreshold,
                       lerp: 0.10) {  // Увеличено с 0.06 до 0.10
            return
        }
        if applyMagnet(step: ClockConstants.halfHourTickStepRadians,
                       threshold: ClockConstants.halfHourMagneticThreshold,
                       lerp: 0.08) {  // Увеличено с 0.05 до 0.08
            return
        }
        _ = applyMagnet(step: ClockConstants.quarterTickStepRadians,
                        threshold: ClockConstants.quarterHourMagneticThreshold,
                        lerp: 0.04)
    }

    @discardableResult
    private func applyMagnet(step: Double, threshold: Double, lerp: Double) -> Bool {
        guard magnetsEnabled else { return false }
        guard step > 0 else { return false }
        let target = quantizedRotation(angle: rotationAngle, step: step)
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
        rotationAngle = rotationAngle + delta * adaptiveLerp
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
        withTransaction(transaction) {
            rotationAngle = value
        }
    }

    private func quantizedRotation(angle: Double, step: Double) -> Double {
        guard step > 0 else { return angle }
        let base = angle + magnetReferenceAngle
        let quantizedBase = round(base / step) * step
        var result = quantizedBase - magnetReferenceAngle
        
        // Нормализуем к кратчайшему пути от текущего угла
        while result - angle > .pi {
            result -= 2 * .pi
        }
        while result - angle < -.pi {
            result += 2 * .pi
        }
        
        return result
    }

    private func updateMagnetReferenceAngle() {
        // НЕ обновляем если пользователь покрутил стрелку
        if hasUserInteracted {
            return
        }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: currentTime)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let hour24 = Double(hour) + Double(minute) / 60.0
        magnetReferenceAngle = ClockConstants.calculateArrowAngle(hour24: hour24)
    }

    // MARK: - Haptic Feedback

    /// Проверяет пересечение рисок и воспроизводит соответствующий хаптический отклик
    private func checkAndPlayTickHaptic(for angle: Double) {
        let currentTickIndex = HapticFeedback.tickIndex(for: angle)

        // Проверяем, пересекли ли мы новую риску
        if let lastIndex = lastHapticTickIndex, lastIndex == currentTickIndex {
            // Мы всё ещё на той же риске, ничего не делаем
            return
        }

        // Обновляем последнюю пересечённую риску
        lastHapticTickIndex = currentTickIndex

        // Определяем тип риски и воспроизводим соответствующий хаптик
        let tickType = HapticFeedback.tickType(for: currentTickIndex)
        hapticFeedback.playTickCrossing(tickType: tickType, tickIndex: currentTickIndex)
    }

    /// Сбрасывает состояние хаптики (используется при окончании драга)
    private func resetHapticState() {
        lastHapticTickIndex = nil
        hapticFeedback.reset()
    }

    // MARK: - Reset Functions
    func resetRotation() {
        magnetsEnabled = false
        let currentVelocity = dragVelocity
        dragVelocity = 0
        dragSamples.removeAll()
        isDragging = false
        ReminderManager.shared.clearPreviewReminder()  // Очищаем preview при сбросе
        // НЕ сбрасываем хаптику здесь — даём ей работать во время анимации возврата

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
                duration: duration
            ) { [weak self] in
                guard let self else { return }
                self.setRotationNoAnimation(0)
                self.dragVelocity = 0
                self.resetHapticState()
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
            resetHapticState()
            return
        }

        direction = delta > 0 ? 1 : -1
        lastRotationDirection = direction

        let targetAngle = rotationAngle + delta
        let angularDistance = abs(delta)
        let duration = min(0.75, max(0.2, (angularDistance / twoPi) * 0.45 + 0.18))

        startRotationAnimation(
            to: targetAngle,
            duration: duration
        ) { [weak self] in
            guard let self else { return }
            self.setRotationNoAnimation(0)
            self.dragVelocity = 0
            self.resetHapticState()
        }
    }
    
    func resetToCurrentTime() {
        // Поворачиваем к текущему времени местного часового пояса
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        isDragging = false
        // НЕ сбрасываем хаптику здесь — даём ей работать во время анимации

        let targetAngle = ClockConstants.calculateArrowAngle(hour: hour, minute: minute)
        let destination = -targetAngle
        let delta = destination - rotationAngle
        if abs(delta) > directionEpsilon {
            lastRotationDirection = delta > 0 ? 1 : -1
        }

        startRotationAnimation(
            to: destination,
            duration: 0.5
        ) { [weak self] in
            self?.resetHapticState()
        }
    }
    
    // MARK: - Reminder Management

    /// Обновляет preview напоминания при вращении циферблата
    private func updatePreviewReminder() {
        // Если есть уже сохранённое напоминание, не показываем preview
        if ReminderManager.shared.currentReminder != nil {
            ReminderManager.shared.clearPreviewReminder()
            return
        }

        // Если вращение близко к нулю, очищаем preview
        if abs(rotationAngle) < ClockConstants.quarterTickStepRadians {
            ReminderManager.shared.clearPreviewReminder()
            return
        }

        // Создаём временное напоминание как one-time
        var reminder = ClockReminder.fromRotationAngle(rotationAngle, currentTime: currentTime)
        // Добавляем дату для one-time напоминания
        let nextDate = ClockReminder.nextTriggerDate(hour: reminder.hour, minute: reminder.minute, from: currentTime)
        reminder = ClockReminder(id: reminder.id, hour: reminder.hour, minute: reminder.minute, date: nextDate, isEnabled: reminder.isEnabled)
        ReminderManager.shared.setPreviewReminder(reminder)
    }

    /// Подтверждает preview напоминание (вызывается при долгом нажатии)
    func confirmPreviewReminder() async {
        // Если есть preview, подтверждаем его
        if ReminderManager.shared.previewReminder != nil {
            // Запрашиваем разрешение если нужно
            let hasPermission = await ReminderManager.shared.requestPermission()
            guard hasPermission else {
                print("Notification permission denied")
                return
            }

            await ReminderManager.shared.confirmPreview()

            #if os(iOS)
            // Хаптический отклик о создании напоминания
            HapticFeedback.shared.playImpact(intensity: .heavy)
            #endif
        }
    }

    /// Создаёт напоминание на основе текущего положения локальной стрелки
    func createReminderAtCurrentRotation() async {
        let reminder = ClockReminder.fromRotationAngle(rotationAngle, currentTime: currentTime)

        // Запрашиваем разрешение если нужно
        let hasPermission = await ReminderManager.shared.requestPermission()
        guard hasPermission else {
            print("Notification permission denied")
            return
        }

        // Создаём напоминание
        await ReminderManager.shared.setReminder(reminder)

        #if os(iOS)
        // Хаптический отклик о создании напоминания
        HapticFeedback.shared.playImpact(intensity: .heavy)
        #endif
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
