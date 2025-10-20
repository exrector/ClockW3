#if !WIDGET_EXTENSION
import SwiftUI
import Foundation

/// Стиллизованная солнечная система в фирменной палитре.
struct SolarSystemView: View, MiniGameScene {
    private let layout = SolarSystemLayout()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                render(size: geometry.size, time: time)
            }
        }
    }

    func render(size: CGSize, time: TimeInterval) -> AnyView {
        let minSide = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        return AnyView(
            ZStack {
                SolarBackground()
                    .ignoresSafeArea()

                ForEach(layout.orbits) { orbit in
                    OrbitRing(orbit: orbit, minSide: minSide)
                        .stroke(
                            Color.white.opacity(0.12),
                            style: StrokeStyle(
                                lineWidth: orbit.lineWidthRatio * minSide,
                                lineCap: .round,
                                dash: [4, 6]
                            )
                        )
                        .frame(width: orbit.radiusRatio * minSide * 2, height: orbit.radiusRatio * minSide * 2)
                        .position(center)
                }

                AsteroidBelt(belt: layout.asteroidBelt, minSide: minSide, time: time)
                    .position(center)

                ForEach(layout.planets) { planet in
                    PlanetNode(planet: planet, minSide: minSide, time: time)
                        .position(planet.position(center: center, minSide: minSide, time: time))
                }

                SolarSun(minSide: minSide)
                    .frame(width: minSide * 0.36, height: minSide * 0.36)
                    .position(center)
            }
            .frame(width: size.width, height: size.height)
        )
    }
}

// MARK: - Layout
private struct SolarSystemLayout {
    struct Orbit: Identifiable {
        let id = UUID()
        let radiusRatio: CGFloat
        let lineWidthRatio: CGFloat
        let revolutionPeriod: Double // секунд на полный оборот
    }

    struct Planet: Identifiable {
        let id = UUID()
        let orbitRadiusRatio: CGFloat
        let sizeRatio: CGFloat
        let color: Color
        let accent: Color
        let revolutionPeriod: Double
        let phase: Double
        let ringOpacity: Double

        func position(center: CGPoint, minSide: CGFloat, time: TimeInterval) -> CGPoint {
            let angle = (2 * .pi * time / revolutionPeriod) + phase
            let radius = orbitRadiusRatio * minSide
            return CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
        }
    }

    struct Asteroid: Identifiable {
        let id = UUID()
        let radiusRatio: CGFloat
        let baseAngle: Double
        let speedMultiplier: Double
        let sizeRatio: CGFloat
    }

    let orbits: [Orbit]
    let planets: [Planet]
    let asteroidBelt: [Asteroid]

    init() {
        orbits = [
            Orbit(radiusRatio: 0.18, lineWidthRatio: 0.002, revolutionPeriod: 18),
            Orbit(radiusRatio: 0.28, lineWidthRatio: 0.0025, revolutionPeriod: 32),
            Orbit(radiusRatio: 0.40, lineWidthRatio: 0.003, revolutionPeriod: 54),
            Orbit(radiusRatio: 0.54, lineWidthRatio: 0.0035, revolutionPeriod: 78),
            Orbit(radiusRatio: 0.68, lineWidthRatio: 0.004, revolutionPeriod: 120)
        ]

        planets = [
            Planet(orbitRadiusRatio: 0.18, sizeRatio: 0.025, color: Color.white.opacity(0.85), accent: Color.white.opacity(0.35), revolutionPeriod: 12, phase: 0.2, ringOpacity: 0),
            Planet(orbitRadiusRatio: 0.28, sizeRatio: 0.032, color: Color.red.opacity(0.8), accent: Color.white.opacity(0.4), revolutionPeriod: 20, phase: 1.1, ringOpacity: 0),
            Planet(orbitRadiusRatio: 0.40, sizeRatio: 0.055, color: Color.white.opacity(0.95), accent: Color.red.opacity(0.5), revolutionPeriod: 34, phase: 0.7, ringOpacity: 0),
            Planet(orbitRadiusRatio: 0.54, sizeRatio: 0.05, color: Color.white.opacity(0.9), accent: Color.red.opacity(0.45), revolutionPeriod: 48, phase: 2.2, ringOpacity: 0.6),
            Planet(orbitRadiusRatio: 0.68, sizeRatio: 0.036, color: Color.white.opacity(0.7), accent: Color.red.opacity(0.35), revolutionPeriod: 64, phase: 0.9, ringOpacity: 0)
        ]

        asteroidBelt = (0..<110).map { index in
            let angle = Double(index) / 110.0 * 2 * .pi
            return Asteroid(
                radiusRatio: 0.47 + CGFloat.random(in: -0.01...0.01),
                baseAngle: angle,
                speedMultiplier: 0.4 + Double.random(in: -0.05...0.05),
                sizeRatio: 0.004 + CGFloat.random(in: -0.001...0.001)
            )
        }
    }
}

// MARK: - Elements
private struct OrbitRing: Shape {
    let orbit: SolarSystemLayout.Orbit
    let minSide: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = orbit.radiusRatio * minSide
        let rect = CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2)
        var path = Path()
        path.addEllipse(in: rect)
        return path
    }
}

private struct PlanetNode: View {
    let planet: SolarSystemLayout.Planet
    let minSide: CGFloat
    let time: TimeInterval

    var body: some View {
        let size = planet.sizeRatio * minSide
        let angle = (2 * .pi * time / planet.revolutionPeriod) + planet.phase

        return ZStack {
            if planet.ringOpacity > 0 {
                Circle()
                    .stroke(planet.accent.opacity(planet.ringOpacity), lineWidth: size * 0.5)
                    .frame(width: size * 2.2, height: size * 2.2)
                    .rotationEffect(.radians(angle * 0.4))
            }

            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [planet.color, planet.accent, planet.color.opacity(0.85)]),
                        center: .center
                    )
                )
                .overlay(
                    Circle()
                        .stroke(planet.accent.opacity(0.4), lineWidth: size * 0.12)
                )
                .frame(width: size, height: size)
        }
        .shadow(color: planet.accent.opacity(0.6), radius: size * 0.4)
        .offset(x: CGFloat(cos(angle)) * planet.orbitRadiusRatio * minSide,
                y: CGFloat(sin(angle)) * planet.orbitRadiusRatio * minSide)
    }
}

private struct AsteroidBelt: View {
    let belt: [SolarSystemLayout.Asteroid]
    let minSide: CGFloat
    let time: TimeInterval

    var body: some View {
        ZStack {
            ForEach(belt) { asteroid in
                let radius = asteroid.radiusRatio * minSide
                let angle = asteroid.baseAngle + asteroid.speedMultiplier * time * 0.4
                Circle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: asteroid.sizeRatio * minSide, height: asteroid.sizeRatio * minSide)
                    .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
            }
        }
        .blur(radius: 0.3)
    }
}

private struct SolarSun: View {
    let minSide: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.red.opacity(0.7), Color.red.opacity(0.05), Color.clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: minSide * 0.24
                    )
                )
                .frame(width: minSide * 0.48, height: minSide * 0.48)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white, Color.red.opacity(0.4)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: minSide * 0.18
                    )
                )
                .frame(width: minSide * 0.36, height: minSide * 0.36)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: minSide * 0.015)
                )
        }
        .allowsHitTesting(false)
    }
}

private struct SolarBackground: View {
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.black,
                Color(red: 10 / 255, green: 10 / 255, blue: 14 / 255)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 600
        )
    }
}

#if DEBUG
struct SolarSystemView_Previews: PreviewProvider {
    static var previews: some View {
        SolarSystemView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif
#endif
