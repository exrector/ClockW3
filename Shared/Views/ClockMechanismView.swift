import SwiftUI

/// Планетарий в фирменной палитре (чёрный / белый / красный). Не зависит от основного циферблата.
struct ClockMechanismView: View {
    private let layout = PlanetariumLayout()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    BackgroundGradient()
                        .ignoresSafeArea()

                    StarField(stars: layout.backgroundStars)
                        .ignoresSafeArea()

                    ForEach(layout.orbits) { orbit in
                        OrbitLayer(
                            orbit: orbit,
                            canvasSize: size,
                            time: time
                        )
                    }

                    FlaresLayer(flares: layout.flares, canvasSize: size, time: time)
                    CoreGlow()
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }
}

// MARK: - Layout Definition
private struct PlanetariumLayout {
    let orbits: [PlanetOrbit]
    let flares: [PlanetaryFlare]
    let backgroundStars: [BackgroundStar]

    init() {
        orbits = [
            PlanetOrbit(
                radiusRatio: 0.24,
                thicknessRatio: 0.012,
                strokeColor: Color.white.opacity(0.42),
                glowColor: Color.white.opacity(0.12),
                highlightColor: Color.red.opacity(0.85),
                rotationRPM: 6.8,
                direction: .forward,
                highlightPhaseOffset: 0.08,
                highlights: [
                    .init(offset: 0.00, length: 0.09, opacity: 0.95),
                    .init(offset: 0.33, length: 0.07, opacity: 0.65),
                    .init(offset: 0.66, length: 0.075, opacity: 0.8)
                ],
                satellites: [
                    .init(
                        sizeRatio: 0.032,
                        coreColor: .white,
                        ringColor: Color.red.opacity(0.9),
                        baseAngle: .pi * 0.12,
                        motionMultiplier: 1.0,
                        trailLength: 0.22,
                        pulse: true
                    ),
                    .init(
                        sizeRatio: 0.018,
                        coreColor: Color.white.opacity(0.7),
                        ringColor: Color.white.opacity(0.2),
                        baseAngle: .pi * 1.15,
                        motionMultiplier: 0.6,
                        trailLength: 0.18,
                        pulse: false
                    )
                ]
            ),
            PlanetOrbit(
                radiusRatio: 0.36,
                thicknessRatio: 0.016,
                strokeColor: Color.white.opacity(0.28),
                glowColor: Color.white.opacity(0.14),
                highlightColor: Color.red.opacity(0.75),
                rotationRPM: 3.4,
                direction: .reverse,
                highlightPhaseOffset: 0.21,
                highlights: [
                    .init(offset: 0.15, length: 0.11, opacity: 0.9),
                    .init(offset: 0.52, length: 0.08, opacity: 0.65)
                ],
                satellites: [
                    .init(
                        sizeRatio: 0.046,
                        coreColor: Color.white.opacity(0.93),
                        ringColor: Color.black.opacity(0.65),
                        baseAngle: .pi * 0.38,
                        motionMultiplier: 1.2,
                        trailLength: 0.26,
                        pulse: true
                    ),
                    .init(
                        sizeRatio: 0.024,
                        coreColor: Color.red.opacity(0.92),
                        ringColor: Color.white.opacity(0.5),
                        baseAngle: .pi * 1.62,
                        motionMultiplier: 0.8,
                        trailLength: 0.2,
                        pulse: true
                    ),
                    .init(
                        sizeRatio: 0.015,
                        coreColor: Color.white.opacity(0.55),
                        ringColor: Color.clear,
                        baseAngle: .pi * 2.45,
                        motionMultiplier: 1.6,
                        trailLength: 0.14,
                        pulse: false
                    )
                ]
            ),
            PlanetOrbit(
                radiusRatio: 0.49,
                thicknessRatio: 0.018,
                strokeColor: Color.white.opacity(0.22),
                glowColor: Color.white.opacity(0.1),
                highlightColor: Color.red.opacity(0.65),
                rotationRPM: 1.8,
                direction: .forward,
                highlightPhaseOffset: 0.34,
                highlights: [
                    .init(offset: 0.07, length: 0.08, opacity: 0.6),
                    .init(offset: 0.47, length: 0.09, opacity: 0.8),
                    .init(offset: 0.82, length: 0.07, opacity: 0.55)
                ],
                satellites: [
                    .init(
                        sizeRatio: 0.038,
                        coreColor: Color.white.opacity(0.88),
                        ringColor: Color.red.opacity(0.65),
                        baseAngle: .pi * 0.05,
                        motionMultiplier: 0.95,
                        trailLength: 0.22,
                        pulse: false
                    ),
                    .init(
                        sizeRatio: 0.021,
                        coreColor: Color.white,
                        ringColor: Color.white.opacity(0.15),
                        baseAngle: .pi * 1.28,
                        motionMultiplier: 1.4,
                        trailLength: 0.18,
                        pulse: true
                    ),
                    .init(
                        sizeRatio: 0.018,
                        coreColor: Color.red.opacity(0.9),
                        ringColor: Color.black.opacity(0.45),
                        baseAngle: .pi * 2.2,
                        motionMultiplier: 0.7,
                        trailLength: 0.24,
                        pulse: false
                    )
                ]
            ),
            PlanetOrbit(
                radiusRatio: 0.63,
                thicknessRatio: 0.02,
                strokeColor: Color.white.opacity(0.18),
                glowColor: Color.white.opacity(0.08),
                highlightColor: Color.red.opacity(0.55),
                rotationRPM: 1.1,
                direction: .reverse,
                highlightPhaseOffset: 0.5,
                highlights: [
                    .init(offset: 0.32, length: 0.12, opacity: 0.55),
                    .init(offset: 0.78, length: 0.1, opacity: 0.65)
                ],
                satellites: [
                    .init(
                        sizeRatio: 0.046,
                        coreColor: Color.white.opacity(0.82),
                        ringColor: Color.white.opacity(0.18),
                        baseAngle: .pi * 0.72,
                        motionMultiplier: 1.0,
                        trailLength: 0.28,
                        pulse: false
                    ),
                    .init(
                        sizeRatio: 0.028,
                        coreColor: Color.red.opacity(0.88),
                        ringColor: Color.white.opacity(0.5),
                        baseAngle: .pi * 1.92,
                        motionMultiplier: 1.3,
                        trailLength: 0.22,
                        pulse: true
                    ),
                    .init(
                        sizeRatio: 0.022,
                        coreColor: Color.white.opacity(0.65),
                        ringColor: Color.white.opacity(0.35),
                        baseAngle: .pi * 2.8,
                        motionMultiplier: 0.6,
                        trailLength: 0.16,
                        pulse: false
                    )
                ]
            )
        ]

        flares = [
            PlanetaryFlare(position: CGPoint(x: 0.78, y: 0.32), radiusRatio: 0.18, color: Color.red.opacity(0.8), pulseSpeed: 0.8),
            PlanetaryFlare(position: CGPoint(x: 0.24, y: 0.76), radiusRatio: 0.14, color: Color.white.opacity(0.4), pulseSpeed: 1.3),
            PlanetaryFlare(position: CGPoint(x: 0.64, y: 0.78), radiusRatio: 0.11, color: Color.red.opacity(0.55), pulseSpeed: 1.1)
        ]

        backgroundStars = [
            .init(position: CGPoint(x: 0.12, y: 0.18), radiusRatio: 0.01, brightness: 0.8),
            .init(position: CGPoint(x: 0.22, y: 0.32), radiusRatio: 0.012, brightness: 0.9),
            .init(position: CGPoint(x: 0.35, y: 0.18), radiusRatio: 0.008, brightness: 0.7),
            .init(position: CGPoint(x: 0.52, y: 0.14), radiusRatio: 0.014, brightness: 0.85),
            .init(position: CGPoint(x: 0.68, y: 0.22), radiusRatio: 0.01, brightness: 0.75),
            .init(position: CGPoint(x: 0.82, y: 0.18), radiusRatio: 0.009, brightness: 0.65),
            .init(position: CGPoint(x: 0.9, y: 0.32), radiusRatio: 0.008, brightness: 0.55),
            .init(position: CGPoint(x: 0.82, y: 0.52), radiusRatio: 0.011, brightness: 0.75),
            .init(position: CGPoint(x: 0.9, y: 0.68), radiusRatio: 0.009, brightness: 0.6),
            .init(position: CGPoint(x: 0.78, y: 0.86), radiusRatio: 0.013, brightness: 0.88),
            .init(position: CGPoint(x: 0.62, y: 0.88), radiusRatio: 0.009, brightness: 0.7),
            .init(position: CGPoint(x: 0.46, y: 0.82), radiusRatio: 0.011, brightness: 0.82),
            .init(position: CGPoint(x: 0.32, y: 0.88), radiusRatio: 0.008, brightness: 0.6),
            .init(position: CGPoint(x: 0.18, y: 0.82), radiusRatio: 0.011, brightness: 0.7),
            .init(position: CGPoint(x: 0.1, y: 0.66), radiusRatio: 0.012, brightness: 0.78),
            .init(position: CGPoint(x: 0.18, y: 0.52), radiusRatio: 0.009, brightness: 0.63),
            .init(position: CGPoint(x: 0.28, y: 0.42), radiusRatio: 0.012, brightness: 0.86),
            .init(position: CGPoint(x: 0.44, y: 0.28), radiusRatio: 0.009, brightness: 0.68)
        ]
    }
}

// MARK: - Orbit Model
private struct PlanetOrbit: Identifiable {
    struct Highlight: Identifiable {
        let id = UUID()
        let offset: Double     // 0...1
        let length: Double     // 0...1
        let opacity: Double
    }

    struct Satellite: Identifiable {
        let id = UUID()
        let sizeRatio: CGFloat
        let coreColor: Color
        let ringColor: Color
        let baseAngle: Double          // radians
        let motionMultiplier: Double
        let trailLength: CGFloat       // относительная длина (от радиуса орбиты)
        let pulse: Bool
    }

    enum Direction {
        case forward
        case reverse

        var sign: Double { self == .forward ? 1 : -1 }
    }

    let id = UUID()
    let radiusRatio: CGFloat
    let thicknessRatio: CGFloat
    let strokeColor: Color
    let glowColor: Color
    let highlightColor: Color
    let rotationRPM: Double
    let direction: Direction
    let highlightPhaseOffset: Double
    let highlights: [Highlight]
    let satellites: [Satellite]

    func angle(at time: TimeInterval) -> Double {
        direction.sign * (rotationRPM / 60.0) * 2.0 * .pi * time
    }

    func turns(at time: TimeInterval) -> Double {
        direction.sign * rotationRPM * time / 60.0
    }
}

// MARK: - Flares / Stars Model
private struct PlanetaryFlare: Identifiable {
    let id = UUID()
    let position: CGPoint       // 0...1
    let radiusRatio: CGFloat
    let color: Color
    let pulseSpeed: Double
}

private struct BackgroundStar: Identifiable {
    let id = UUID()
    let position: CGPoint
    let radiusRatio: CGFloat
    let brightness: Double
}

// MARK: - Background Gradient
private struct BackgroundGradient: View {
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 8 / 255, green: 8 / 255, blue: 10 / 255),
                Color(red: 2 / 255, green: 2 / 255, blue: 2 / 255)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 520
        )
    }
}

// MARK: - Orbit Layer
private struct OrbitLayer: View {
    let orbit: PlanetOrbit
    let canvasSize: CGSize
    let time: TimeInterval

    private var minSide: CGFloat {
        min(canvasSize.width, canvasSize.height)
    }

    private var center: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    var body: some View {
        let radius = orbit.radiusRatio * minSide
        let diameter = radius * 2
        let baseThickness = orbit.thicknessRatio * minSide

        ZStack {
            Circle()
                .stroke(orbit.strokeColor, lineWidth: baseThickness)
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(orbit.glowColor, lineWidth: baseThickness * 1.8)
                .frame(width: diameter, height: diameter)
                .blur(radius: baseThickness * 0.8)

            ForEach(orbit.highlights) { highlight in
                let rotationTurns = orbit.turns(at: time) + orbit.direction.sign * (highlight.offset + orbit.highlightPhaseOffset)
                let normalizedTurn = rotationTurns - floor(rotationTurns)
                Circle()
                    .trim(from: 0, to: highlight.length)
                    .stroke(
                        orbit.highlightColor.opacity(highlight.opacity),
                        style: StrokeStyle(lineWidth: baseThickness * 1.6, lineCap: .round)
                    )
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.radians(2 * .pi * normalizedTurn - .pi / 2))
                    .shadow(color: orbit.highlightColor.opacity(highlight.opacity * 0.8), radius: baseThickness * 1.1)
            }

            ForEach(orbit.satellites) { satellite in
                SatelliteNode(
                    satellite: satellite,
                    orbit: orbit,
                    radius: radius,
                    center: center,
                    time: time,
                    baseThickness: baseThickness
                )
            }
        }
    }
}

// MARK: - Satellite Node
private struct SatelliteNode: View {
    let satellite: PlanetOrbit.Satellite
    let orbit: PlanetOrbit
    let radius: CGFloat
    let center: CGPoint
    let time: TimeInterval
    let baseThickness: CGFloat

    private var minSide: CGFloat {
        radius * 2
    }

    var body: some View {
        let angle = satellite.baseAngle + orbit.angle(at: time) * satellite.motionMultiplier
        let position = CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )

        let size = satellite.sizeRatio * minSide
        let pulseFactor: CGFloat = {
            if satellite.pulse {
                let oscillation = (sin(time * 2.4 + satellite.baseAngle) + 1) / 2
                return 0.88 + 0.22 * CGFloat(oscillation)
            } else {
                return 1.0
            }
        }()
        let finalSize = size * pulseFactor
        let trailLength = satellite.trailLength * radius
        let motionSign = orbit.direction.sign
        let tangentAngle = angle + motionSign * (.pi / 2)

        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            satellite.coreColor.opacity(0.0),
                            satellite.coreColor.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: trailLength, height: max(baseThickness * 0.6, finalSize * 0.45))
                .rotationEffect(.radians(tangentAngle))
                .position(
                    CGPoint(
                        x: position.x - CGFloat(cos(tangentAngle)) * trailLength / 2,
                        y: position.y - CGFloat(sin(tangentAngle)) * trailLength / 2
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            satellite.coreColor,
                            satellite.coreColor.opacity(0.15)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: finalSize * 0.7
                    )
                )
                .frame(width: finalSize, height: finalSize)
                .overlay(
                    Circle()
                        .stroke(satellite.ringColor, lineWidth: finalSize * 0.25)
                )
                .shadow(color: satellite.coreColor.opacity(0.65), radius: finalSize * 0.6)
                .position(position)
        }
    }
}

// MARK: - Flares
private struct FlaresLayer: View {
    let flares: [PlanetaryFlare]
    let canvasSize: CGSize
    let time: TimeInterval

    var body: some View {
        ZStack {
            ForEach(flares) { flare in
                let minSide = min(canvasSize.width, canvasSize.height)
                let baseRadius = flare.radiusRatio * minSide
                let pulse = 0.85 + 0.18 * sin(time * flare.pulseSpeed + flare.position.x * 4.2)
                let radius = baseRadius * CGFloat(pulse)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [flare.color, flare.color.opacity(0)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(
                        CGPoint(
                            x: flare.position.x * canvasSize.width,
                            y: flare.position.y * canvasSize.height
                        )
                    )
            }
        }
    }
}

// MARK: - Star Field
private struct StarField: View {
    let stars: [BackgroundStar]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let minSide = min(size.width, size.height)
                for star in stars {
                    let position = CGPoint(x: star.position.x * size.width, y: star.position.y * size.height)
                    let radius = star.radiusRatio * minSide

                    var starPath = Path()
                    starPath.addEllipse(in: CGRect(
                        x: position.x - radius,
                        y: position.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    context.fill(
                        starPath,
                        with: .radialGradient(
                            Gradient(colors: [
                                Color.white.opacity(star.brightness),
                                Color.white.opacity(0.0)
                            ]),
                            center: position,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Core Glow
private struct CoreGlow: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.42),
                            Color.red.opacity(0.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .frame(width: 220, height: 220)

            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white, Color.white.opacity(0.05)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview
#if DEBUG
struct ClockMechanismView_Previews: PreviewProvider {
    static var previews: some View {
        ClockMechanismView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif
