//
//  ContentView.swift
//  ОСНОВНОЕ ПРИЛОЖЕНИЕ (Движущиеся стрелки)
//
//  Created by AK on 10/9/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @AppStorage(
        SharedUserDefaults.colorSchemeKey,
        store: SharedUserDefaults.shared
    ) private var colorSchemePreference: String = "system"

#if os(macOS)
    @AppStorage(
        SharedUserDefaults.windowOrientationKey,
        store: SharedUserDefaults.shared
    ) private var windowOrientationPreference: String = "landscape"
    @AppStorage("transparentModeActive", store: UserDefaults.standard)
    private var transparentModeActive: Bool = false
#endif
    @State private var showSettings = false
#if os(macOS)
    @State private var hostingWindow: NSWindow?
#endif

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        content
            .onAppear {
                // Показываем настройки сразу
                showSettings = true
#if os(macOS)
                applyAppAppearance(for: colorSchemePreference)
#endif
            }
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
        macOSContainer
#else
        iOSContent()
#endif
    }

#if os(macOS)
    private var macOSContainer: some View {
        macOSContent()
            .background(
                WindowAccessor { window in
                    guard let window else { return }

                    if hostingWindow !== window {
                        hostingWindow = window
                        configureWindow(window, orientation: windowOrientationPreference)
                        applyWindowAppearance(window, preference: colorSchemePreference)
                    }
                }
            )
            .onChange(of: colorSchemePreference) { _, newValue in
                applyAppAppearance(for: newValue)
                if let window = hostingWindow {
                    applyWindowAppearance(window, preference: newValue)
                }
            }
            .onChange(of: windowOrientationPreference) { _, newValue in
                guard let window = hostingWindow else { return }
                applyWindowSize(to: window, orientation: newValue, animated: true)
            }
    }

    private func macOSContent() -> some View {
        let targetSize = macOSContentSize(for: windowOrientationPreference)
        let isLandscape = windowOrientationPreference == "landscape"
        let portraitClockMaxHeight = targetSize.height * 0.6

        return VStack(spacing: 0) {
            Group {
                if isLandscape {
                    HStack(spacing: 0) {
                        ClockFaceView()
                            .frame(width: targetSize.height, height: targetSize.height)
                            .frame(maxHeight: .infinity)

                        VStack(spacing: 0) {
                            if showSettings {
                                SettingsView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            } else {
                                Button("Settings") { showSettings = true }
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color("ClockBackground"))
                    }
                } else {
                    VStack(spacing: 0) {
                        ClockFaceView()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: portraitClockMaxHeight)

                        VStack(spacing: 0) {
                            if showSettings {
                                SettingsView()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                            } else {
                                Button("Settings") { showSettings = true }
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .background(Color("ClockBackground"))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: targetSize.width, height: targetSize.height)
        // Не форсируем .preferredColorScheme на macOS — используем NSWindow/NSApp.appearance
        // Форсируем полное перестроение при смене режима System/Light/Dark,
        // чтобы убрать/применить override цветовой схемы корректно.
        .id("appearance-\(colorSchemePreference)")
        .fixedSize()
    }
#else
    private func iOSContent() -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let isLandscape = width >= height

            VStack(spacing: 0) {
                Group {
                    if isLandscape {
                        HStack(spacing: 0) {
                            ClockFaceView()
                                .frame(width: height, height: height)
                                .frame(maxHeight: .infinity)

                            VStack(spacing: 0) {
                                if showSettings {
                                    SettingsView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                } else {
                                    Button("Settings") { showSettings = true }
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color("ClockBackground"))
                        }
                    } else {
                        VStack(spacing: 0) {
                            ClockFaceView()
                                .frame(maxWidth: .infinity, maxHeight: height * 0.6)

                            VStack(spacing: 0) {
                                if showSettings {
                                    SettingsView()
                                        .frame(maxWidth: .infinity)
                                        .frame(maxHeight: .infinity, alignment: .topLeading)
                                } else {
                                    Button("Settings") { showSettings = true }
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .background(Color("ClockBackground"))
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(preferredColorScheme)
    }
    }
#endif
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif

#if os(macOS)
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

// Применяет внешность приложения на macOS (System/Light/Dark)
private func applyAppAppearance(for preference: String) {
    switch preference {
    case "light":
        NSApp.appearance = NSAppearance(named: .aqua)
    case "dark":
        NSApp.appearance = NSAppearance(named: .darkAqua)
    default:
        NSApp.appearance = nil // следовать системной теме
    }
}

private func macOSContentSize(for orientation: String) -> CGSize {
    orientation == "landscape"
        ? CGSize(width: 1000, height: 600)
        : CGSize(width: 400, height: 950)
}

private func configureWindow(_ window: NSWindow, orientation: String) {
    window.styleMask.remove(.resizable)
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isEnabled = false
    window.isRestorable = false
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.collectionBehavior.remove(.fullScreenPrimary)
    window.contentResizeIncrements = NSSize(width: 1, height: 1)
    applyWindowSize(to: window, orientation: orientation, animated: false)
}

private func applyWindowAppearance(_ window: NSWindow, preference: String) {
    switch preference {
    case "light":
        window.appearance = NSAppearance(named: .aqua)
    case "dark":
        window.appearance = NSAppearance(named: .darkAqua)
    default:
        window.appearance = nil // следовать системной теме
    }
}

private func applyWindowSize(to window: NSWindow, orientation: String, animated: Bool) {
    let contentSize = macOSContentSize(for: orientation)
    let contentRect = NSRect(origin: .zero, size: contentSize)
    var newFrame = window.frameRect(forContentRect: contentRect)

    let currentFrame = window.frame
    let newOrigin = NSPoint(
        x: currentFrame.midX - newFrame.width / 2,
        y: currentFrame.midY - newFrame.height / 2
    )
    newFrame.origin = newOrigin

    if let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
        newFrame.origin.x = max(screenFrame.minX, min(newFrame.origin.x, screenFrame.maxX - newFrame.width))
        newFrame.origin.y = max(screenFrame.minY, min(newFrame.origin.y, screenFrame.maxY - newFrame.height))
    }

    window.minSize = newFrame.size
    window.maxSize = newFrame.size

    let sizeDelta = abs(currentFrame.width - newFrame.width) + abs(currentFrame.height - newFrame.height)
    let positionDelta = abs(currentFrame.origin.x - newFrame.origin.x) + abs(currentFrame.origin.y - newFrame.origin.y)
    guard sizeDelta > 0.5 || positionDelta > 0.5 else { return }

    window.setFrame(
        newFrame,
        display: window.isVisible,
        animate: animated && window.isVisible
    )
}
#endif
