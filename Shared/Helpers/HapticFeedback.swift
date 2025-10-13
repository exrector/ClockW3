import Foundation

#if os(iOS)
import UIKit
import QuartzCore
#endif

enum HapticFeedback {
    enum Strength {
        case light
        case medium
        case heavy
    }

    static func impact(_ strength: Strength) {
        #if os(iOS)
        HapticFeedbackEngine.shared.playImpact(strength)
        #endif
    }
}

#if os(iOS)
private final class HapticFeedbackEngine {
    static let shared = HapticFeedbackEngine()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    private var lastImpactTime: TimeInterval = 0
    private let minInterval: TimeInterval = 0.06  // 60ms

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
    }

    func playImpact(_ strength: HapticFeedback.Strength) {
        let now = CACurrentMediaTime()
        guard now - lastImpactTime >= minInterval else { return }
        lastImpactTime = now

        switch strength {
        case .light:
            lightGenerator.impactOccurred()
            lightGenerator.prepare()
        case .medium:
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        case .heavy:
            heavyGenerator.impactOccurred()
            heavyGenerator.prepare()
        }
    }
}
#endif
