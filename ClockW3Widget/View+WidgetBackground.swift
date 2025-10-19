import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        #if canImport(WidgetKit)
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            background(color)
        }
        #else
        background(color)
        #endif
    }
}
