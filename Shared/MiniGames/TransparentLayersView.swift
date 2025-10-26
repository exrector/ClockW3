#if !WIDGET_EXTENSION
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TransparentLayersView: View, MiniGameScene {
    @AppStorage("transparentModeActive", store: UserDefaults.standard)
    private var transparentModeActive: Bool = false

    var body: some View {
        Color.clear
            .onAppear {
                transparentModeActive = true
                activateTransparency()
            }
            .onDisappear {
                transparentModeActive = false
                deactivateTransparency()
            }
    }

    func render(size: CGSize, time: TimeInterval) -> AnyView {
        return AnyView(Color.clear)
    }

    // MARK: - Transparency Control
    private func activateTransparency() {
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.hasShadow = false
            }
        }
        #endif
    }

    private func deactivateTransparency() {
        #if os(macOS)
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.backgroundColor = NSColor.windowBackgroundColor
                window.isOpaque = true
                window.hasShadow = true
            }
        }
        #endif
    }
}

// MARK: - Preview
#if DEBUG
struct TransparentLayersView_Previews: PreviewProvider {
    static var previews: some View {
        TransparentLayersView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif

#endif
