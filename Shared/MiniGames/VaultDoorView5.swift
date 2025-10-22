#if !WIDGET_EXTENSION
import SwiftUI

struct VaultDoorView5: View, MiniGameScene {
    init() {}
    
    var body: some View {
        GeometryReader { geometry in
            render(size: geometry.size, time: Date().timeIntervalSince1970)
        }
    }
    
    func render(size: CGSize, time: TimeInterval) -> AnyView {
        AnyView(
            Image("VaultDoorView5")
                .resizable()
                .scaledToFit()
                .blur(radius: sin(time * 3) * 0.5)
                .frame(width: size.width, height: size.height)
        )
    }
}

#Preview {
    VaultDoorView5()
        .frame(width: 300, height: 300)
}
#endif
