#if !WIDGET_EXTENSION
import SwiftUI

struct VaultDoorView: View, MiniGameScene {
    init() {}
    
    var body: some View {
        GeometryReader { geometry in
            render(size: geometry.size, time: Date().timeIntervalSince1970)
        }
    }
    
    func render(size: CGSize, time: TimeInterval) -> AnyView {
        AnyView(
            Image("VaultDoorView")
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
        )
    }
}

#Preview {
    VaultDoorView()
        .frame(width: 300, height: 300)
}
#endif