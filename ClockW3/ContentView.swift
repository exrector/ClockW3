//
//  ContentView.swift
//  ClockW3
//
//  Created by AK on 10/9/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreference: String = "system"

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

            Group {
                if isLandscape {
                    HStack(spacing: 0) {
                        ClockFaceView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        SettingsView()
                            .frame(maxWidth: width * 0.4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    VStack(spacing: 0) {
                        ClockFaceView()
                            .frame(maxWidth: .infinity, maxHeight: height * 0.6)

                        SettingsView()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("ClockBackground"))
            .preferredColorScheme(preferredColorScheme)
        }
    }
}


#Preview {
    ContentView()
}
