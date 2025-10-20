#if !WIDGET_EXTENSION
import SwiftUI

struct ClockMechanismView: View {
    private let scene: AnyView

    init() {
        self.scene = MiniGameRegistry.nextSceneView()
    }

    var body: some View { scene }
}
#endif
