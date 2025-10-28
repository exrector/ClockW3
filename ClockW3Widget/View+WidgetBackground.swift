import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        #if canImport(WidgetKit)
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            #if os(macOS)
            // На macOS используем системный материал, чтобы поддержать полу‑прозрачность/тонирование виджетов на рабочем столе.
            containerBackground(.ultraThinMaterial, for: .widget)
            #else
            containerBackground(for: .widget) { color }
            #endif
        } else {
            background(color)
        }
        #else
        background(color)
        #endif
    }
}
