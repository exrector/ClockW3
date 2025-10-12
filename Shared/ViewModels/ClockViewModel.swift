import SwiftUI
import Foundation
import Combine

// MARK: - Clock View Model
@MainActor
class ClockViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTime = Date()
    @Published var cities: [WorldCity] = WorldCity.defaultCities
    
    // Интерактивность
    @Published var rotationAngle: Double = 0
    @Published var isDragging = false
    @Published var isSnapping = false
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastDragAngle: Double = 0
    private var dragVelocity: Double = 0
    private var lastDragTime: Date = Date()
    
    // MARK: - Initialization
    init() {
        startTimeUpdates()
        setupDragPhysics()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Time Management
    private func startTimeUpdates() {
        // Обновляем время каждую минуту
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await MainActor.run {
                    self.currentTime = Date()
                }
            }
        }
        
        // Также обновляем сразу
        currentTime = Date()
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
    }
    
    func updateDrag(at location: CGPoint, in geometry: GeometryProxy) {
        guard isDragging else { return }

        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let currentAngle = atan2(location.y - center.y, location.x - center.x)

        var angleDelta = currentAngle - lastDragAngle
        angleDelta = ClockConstants.normalizeAngle(angleDelta)

        rotationAngle += angleDelta

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
        applyInertiaAndSnap()
    }
    
    // MARK: - Physics Simulation
    private func setupDragPhysics() {
        // Симуляция физики каждые 16ms (~60fps)
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await MainActor.run {
                    self.updatePhysics()
                }
            }
        }
    }
    
    private func updatePhysics() {
        guard !isDragging && !isSnapping else { return }

        // Плавная инерция с мягким затуханием
        dragVelocity *= 0.94

        if abs(dragVelocity) >= 0.02 {
            // Продолжаем движение по инерции (60 Гц)
            rotationAngle += dragVelocity / 60.0
            return
        }

        // Скорость мала — мягкий снэп к ближайшему тику без рывков
        let nearestTick = ClockConstants.nearestTickAngle(rotationAngle)
        var delta = nearestTick - rotationAngle
        delta = ClockConstants.normalizeAngle(delta)

        // Критически демпфированное подведение к цели
        let step = delta * 0.10
        rotationAngle += step

        // Когда очень близко — фиксируем точно и гасим скорость
        if abs(delta) < (0.3 * .pi / 180.0) { // 0.3°
            rotationAngle = nearestTick
            dragVelocity = 0
        }
    }
    
    private func applyMagneticAttraction() {
        let nearestTick = ClockConstants.nearestTickAngle(rotationAngle)
        let distance = abs(ClockConstants.normalizeAngle(rotationAngle - nearestTick))
        
        if distance < ClockConstants.magneticThreshold {
            let attraction = (nearestTick - rotationAngle) * 0.1
            rotationAngle += attraction
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
    
    // MARK: - Reset Functions
    func resetRotation() {
        withAnimation(.easeOut(duration: ClockConstants.snapDuration)) {
            rotationAngle = 0
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
}
