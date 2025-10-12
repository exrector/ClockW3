import SwiftUI
import Observation
import Combine

@MainActor
final class ClockController: ObservableObject {
    @Published private(set) var clockState = ClockState()
    @Published private(set) var rotationAngle: CGFloat = 0

    private var clockTimer: Timer?
    private let physics = ClockPhysics()

    init() {
        configurePhysicsCallbacks()
    }

    // deinit intentionally left empty to avoid actor-isolation violations in Swift 6

    func start() {
        startClockTimer()
        physics.startPhysicsLoop()
    }

    func stop() {
        stopClockTimer()
        physics.stopPhysicsLoop()
    }

    func handleDragChanged(location: CGPoint, center: CGPoint) {
        physics.handleDragGesture(location: location, center: center, state: .changed)
    }

    func handleDragEnded(location: CGPoint, center: CGPoint) {
        physics.handleDragGesture(location: location, center: center, state: .ended)
    }

    func resetToUTC() {
        physics.resetToUTC()
    }

    private func configurePhysicsCallbacks() {
        rotationAngle = physics.rotationAngle
        physics.onRotationChanged = { [weak self] angle in
            guard let strongSelf = self else { return }
            strongSelf.rotationAngle = angle
        }
    }

    private func startClockTimer() {
        guard clockTimer == nil else { return }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.clockState.currentTime = Date()
            }
        }
        clockTimer?.tolerance = 0.1
        clockState.currentTime = Date()
    }

    private func stopClockTimer() {
        clockTimer?.invalidate()
        clockTimer = nil
    }
}
