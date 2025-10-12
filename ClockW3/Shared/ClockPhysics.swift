import SwiftUI
import Observation
import QuartzCore

#if os(iOS) || os(visionOS)
import UIKit
#endif

// MARK: - Clock Physics Engine (только для основного приложения)
@MainActor
@Observable
class ClockPhysics {
    var rotationAngle: CGFloat = 0  // Угол вращения (локальная стрелка становится "базой")
    var angularVelocity: CGFloat = 0

    var onRotationChanged: ((CGFloat) -> Void)? {
        didSet { notifyRotationChanged() }
    }

    private let angularDamping: CGFloat = 0.985  // Затухание скорости
    private let snapThreshold: CGFloat = 0.02    // Порог для магнитного притяжения
    private let snapStrength: CGFloat = 0.15     // Сила притяжения к делениям

    private var timer: Timer?
    private var lastUpdateTime: CFTimeInterval = 0
    private var lastDragAngle: CGFloat?  // Последний угол драга для вычисления скорости

    init() {}

    // MARK: - Start/Stop Physics Loop
    func startPhysicsLoop() {
        guard timer == nil else { return }

        lastUpdateTime = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updatePhysics()
            }
        }
        timer?.tolerance = 0.001  // 1ms tolerance
        notifyRotationChanged()
    }

    func stopPhysicsLoop() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePhysics() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = CGFloat(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        // Применяем затухание
        angularVelocity *= angularDamping

        // Обновляем угол
        rotationAngle += angularVelocity * deltaTime

        // Нормализуем угол в диапазон [0, 2π)
        rotationAngle = rotationAngle.truncatingRemainder(dividingBy: 2 * .pi)
        if rotationAngle < 0 {
            rotationAngle += 2 * .pi
        }

        // Магнитное притяжение к делениям
        applyMagneticSnapping()

        // Остановка при минимальной скорости
        if abs(angularVelocity) < 0.001 {
            angularVelocity = 0
        }

        notifyRotationChanged()
    }

    // MARK: - Magnetic Snapping
    private func applyMagneticSnapping() {
        guard abs(angularVelocity) < 0.5 else { return }  // Только при низкой скорости

        // Проверяем притяжение к часовым делениям (15°)
        let hourDivision = 15.0 * .pi / 180.0
        let nearestHourAngle = round(rotationAngle / hourDivision) * hourDivision
        let hourDistance = abs(rotationAngle - nearestHourAngle)

        if hourDistance < snapThreshold {
            let snapForce = (nearestHourAngle - rotationAngle) * snapStrength
            angularVelocity += snapForce
            ClockHaptics.shared.playImpact(strength: ClockHaptics.Strength.heavy)
            return
        }

        // Проверяем притяжение к получасовым делениям (7.5°)
        let halfHourDivision = 7.5 * .pi / 180.0
        let nearestHalfHourAngle = round(rotationAngle / halfHourDivision) * halfHourDivision
        let halfHourDistance = abs(rotationAngle - nearestHalfHourAngle)

        if halfHourDistance < snapThreshold {
            let snapForce = (nearestHalfHourAngle - rotationAngle) * snapStrength
            angularVelocity += snapForce
            ClockHaptics.shared.playImpact(strength: ClockHaptics.Strength.medium)
            return
        }

        // Проверяем притяжение к четвертьчасовым делениям (3.75°)
        let quarterHourDivision = 3.75 * .pi / 180.0
        let nearestQuarterAngle = round(rotationAngle / quarterHourDivision) * quarterHourDivision
        let quarterDistance = abs(rotationAngle - nearestQuarterAngle)

        if quarterDistance < snapThreshold {
            let snapForce = (nearestQuarterAngle - rotationAngle) * snapStrength
            angularVelocity += snapForce
            ClockHaptics.shared.playImpact(strength: ClockHaptics.Strength.light)
        }
    }

    // MARK: - Drag Gesture Handling (работает на всех платформах)
    func handleDragGesture(location: CGPoint, center: CGPoint, state: GestureState) {
        // Вычисляем угол от центра до текущей позиции курсора/пальца
        let dx = location.x - center.x
        let dy = location.y - center.y
        let currentAngle = atan2(dy, dx)

        switch state {
        case .changed:
            if let lastAngle = lastDragAngle {
                // Вычисляем изменение угла
                var deltaAngle = currentAngle - lastAngle

                // Нормализуем изменение угла в диапазон [-π, π]
                if deltaAngle > .pi {
                    deltaAngle -= 2 * .pi
                } else if deltaAngle < -.pi {
                    deltaAngle += 2 * .pi
                }

                // Обновляем угол вращения
                rotationAngle += deltaAngle

                // Вычисляем угловую скорость (для инерции)
                angularVelocity = deltaAngle * 60.0  // Умножаем на 60 FPS

                notifyRotationChanged()
            }

            lastDragAngle = currentAngle

        case .ended:
            // Применяем инерцию (скорость уже вычислена в .changed)
            angularVelocity *= 1.5  // Усиление начальной скорости
            lastDragAngle = nil
        }
    }

    // MARK: - Reset to UTC
    func resetToUTC() {
        // Плавно возвращаем локальную стрелку в UTC положение
        // UTC = 0° (стрелка смотрит вправо, на 18:00)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            rotationAngle = 0
        }
        angularVelocity = 0
        ClockHaptics.shared.playImpact(strength: ClockHaptics.Strength.medium)
        notifyRotationChanged()
    }

}

// MARK: - Private Helpers
private extension ClockPhysics {
    func notifyRotationChanged() {
        onRotationChanged?(rotationAngle)
    }
}

// MARK: - Gesture State Enum
enum GestureState {
    case changed
    case ended
}
