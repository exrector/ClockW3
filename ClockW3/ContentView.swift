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

                                Text("Designed by Exrector")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .kerning(1.5)
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

                Text("Designed by Exrector")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.primary)
                    .kerning(1.5)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("ClockBackground"))
            .preferredColorScheme(preferredColorScheme)
        }
        .onAppear {
            // Показываем настройки сразу
            showSettings = true
        }
    }
}


#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
