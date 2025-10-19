//
//  ContentView.swift
//  ClockW3
//
//  Created by AK on 10/9/25.
//

import SwiftUI

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
#endif

    @State private var showSettings = false

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
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

                                HStack(spacing: 6) {
                                    // Левый винтик
                                    Text("⊗")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(.primary)

                                    Text("Designed by Exrector")
                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .kerning(1.5)

                                    // Правый винтик
                                    Text("⊕")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    } else {
                        VStack(spacing: 0) {
                            ClockFaceView()
                                .frame(maxWidth: .infinity, maxHeight: height * 0.6)

                            if showSettings {
                                SettingsView()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity, alignment: .topLeading)
                            } else {
                                Button("Settings") { showSettings = true }
                                    .frame(maxHeight: .infinity)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 6) {
                    // Левый винтик
                    Text("⊗")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.primary)

                    Text("Designed by Exrector")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.primary)
                        .kerning(1.5)

                    // Правый винтик
                    Text("⊕")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("ClockBackground"))
            .preferredColorScheme(preferredColorScheme)
#if os(macOS)
            .onChange(of: windowOrientationPreference) { _, newValue in
                updateWindowSize(isLandscape: newValue == "landscape")
            }
#endif
        }
        .onAppear {
            // Показываем настройки сразу
            showSettings = true
#if os(macOS)
            // Устанавливаем начальный размер окна с задержкой для безопасности
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let window = NSApplication.shared.windows.first, window.isVisible {
                    // Убираем возможность ресайза
                    window.styleMask.remove(.resizable)
                    updateWindowSize(isLandscape: windowOrientationPreference == "landscape")
                }
            }
#endif
        }
    }

#if os(macOS)
    private func updateWindowSize(isLandscape: Bool) {
        // Безопасная проверка наличия окна
        guard let window = NSApplication.shared.windows.first else {
            print("⚠️ [Window Update] No window found")
            return
        }

        // Проверяем, что окно готово к работе
        guard window.isVisible else {
            print("⚠️ [Window Update] Window not visible yet")
            return
        }

        let newSize: NSSize
        if isLandscape {
            // Landscape: 893 ширина, 500 высота
            newSize = NSSize(width: 893, height: 500)
        } else {
            // Portrait: 449 ширина, 938 высота
            newSize = NSSize(width: 449, height: 938)
        }

        // Безопасно устанавливаем размер в main thread с дополнительной проверкой
        if Thread.isMainThread {
            setWindowSize(window: window, size: newSize)
        } else {
            DispatchQueue.main.async { [weak window] in
                guard let window = window else { return }
                setWindowSize(window: window, size: newSize)
            }
        }
    }

    private func setWindowSize(window: NSWindow, size: NSSize) {
        // Дополнительная проверка перед изменением размера
        guard window.isVisible else { return }

        window.setContentSize(size)

        // Устанавливаем минимальный и максимальный размер равными текущему
        window.minSize = size
        window.maxSize = size
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
