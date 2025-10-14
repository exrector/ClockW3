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
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if showSettings {
                                SettingsView()
                                    .frame(maxWidth: width * 0.4)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            } else {
                                Button("Settings") { showSettings = true }
                                    .frame(maxWidth: width * 0.4)
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("ClockBackground"))
            .preferredColorScheme(preferredColorScheme)
        }
        .onAppear {
            // Автоматически показываем настройки через 0.5 сек
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showSettings = true
            }
        }
    }
}


#Preview {
    ContentView()
}
