import Foundation

#if os(iOS)
import UIKit
#endif

// MARK: - Clock Division Haptics
class ClockHaptics {
    static let shared = ClockHaptics()

    #if os(iOS)
    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private var lastImpactTime: TimeInterval = 0
    private let minImpactInterval: TimeInterval = 0.06  // 60ms throttle

    init() {
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
    }

    enum Strength { case light, medium, heavy }

    func playImpact(strength: Strength = .light) {
        // Throttling
        let now = CACurrentMediaTime()
        if now - lastImpactTime < minImpactInterval { return }
        lastImpactTime = now

        switch strength {
        case .light:
            lightGen.prepare()
            lightGen.impactOccurred()
        case .medium:
            mediumGen.prepare()
            mediumGen.impactOccurred()
        case .heavy:
            heavyGen.prepare()
            heavyGen.impactOccurred()
        }
    }
    #else
    init() {}
    enum Strength { case light, medium, heavy }
    func playImpact(strength: Strength = .light) {}
    #endif
}
