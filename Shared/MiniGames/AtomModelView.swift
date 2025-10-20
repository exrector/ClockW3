#if !WIDGET_EXTENSION
import SwiftUI

// MARK: - Main View
struct AtomModelView: View, MiniGameScene {
    private let layout = AtomLayout()

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
                AtomBackground()
                    .ignoresSafeArea()

                NucleusView(nucleus: layout.nucleus, minSide: minSide, time: time)
                    .position(center)

                ForEach(layout.electrons) { electron in
                    ElectronOrbitView(electron: electron, minSide: minSide, center: center, time: time)
                }
            }
            .frame(width: size.width, height: size.height)
        )
    }
}

// MARK: - Layout Definition
private struct AtomLayout {
    let nucleus: Nucleus
    let electrons: [Electron]

    init() {
        nucleus = Nucleus(sizeRatio: 0.15, color: Color.red)
        
        electrons = [
            Electron(
                orbit: .init(radiusRatioX: 0.25, radiusRatioY: 0.1, tiltAngle: .pi / 6),
                sizeRatio: 0.025,
                color: Color.cyan,
                speed: 1.2,
                phase: 0
            ),
            Electron(
                orbit: .init(radiusRatioX: 0.35, radiusRatioY: 0.3, tiltAngle: -.pi / 4),
                sizeRatio: 0.03,
                color: Color.yellow,
                speed: 0.9,
                phase: .pi / 2
            ),
            Electron(
                orbit: .init(radiusRatioX: 0.45, radiusRatioY: 0.4, tiltAngle: .pi / 2),
                sizeRatio: 0.02,
                color: Color.green,
                speed: 0.7,
                phase: .pi
            )
        ]
    }
}

// MARK: - Models
private struct Nucleus: Identifiable {
    let id = UUID()
    let sizeRatio: CGFloat
    let color: Color
}

private struct Electron: Identifiable {
    let id = UUID()
    let orbit: Orbit
    let sizeRatio: CGFloat
    let color: Color
    let speed: Double
    let phase: Double
}

private struct Orbit {
    let radiusRatioX: CGFloat
    let radiusRatioY: CGFloat
    let tiltAngle: Double // Angle of the ellipse's tilt
}

// MARK: - View Components
private struct NucleusView: View {
    let nucleus: Nucleus
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let size = nucleus.sizeRatio * minSide
        let pulse = 1.0 + 0.05 * sin(time * 2)
        
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        nucleus.color,                      // center brighter
                        nucleus.color.opacity(0.4)          // edge softer/darker
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size * pulse, height: size * pulse)
            .shadow(color: nucleus.color, radius: size / 1.5, x: 0, y: 0)
    }
}

private struct ElectronOrbitView: View {
    let electron: Electron
    let minSide: CGFloat
    let center: CGPoint
    let time: TimeInterval

    var body: some View {
        let orbit = electron.orbit
        let angle = (time * electron.speed) + electron.phase
        
        let untransformedX = orbit.radiusRatioX * minSide * cos(angle)
        let untransformedY = orbit.radiusRatioY * minSide * sin(angle)
        
        let x = center.x + untransformedX * cos(orbit.tiltAngle) - untransformedY * sin(orbit.tiltAngle)
        let y = center.y + untransformedX * sin(orbit.tiltAngle) + untransformedY * cos(orbit.tiltAngle)
        
        let zIndex = untransformedY // Use this to simulate depth
        
        return ZStack {
            // Orbit Path
            Ellipse()
                .stroke(electron.color.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .frame(width: orbit.radiusRatioX * minSide * 2, height: orbit.radiusRatioY * minSide * 2)
                .rotationEffect(.radians(orbit.tiltAngle))
                .position(center)

            // Electron Particle
            Circle()
                .fill(electron.color)
                .frame(width: electron.sizeRatio * minSide, height: electron.sizeRatio * minSide)
                .shadow(color: electron.color, radius: electron.sizeRatio * minSide, x: 0, y: 0)
                .position(x: x, y: y)
                .zIndex(zIndex)
        }
    }
}

// MARK: - Background
private struct AtomBackground: View {
    var body: some View {
        Color.black
    }
}

// MARK: - Preview
#if DEBUG
struct AtomModelView_Previews: PreviewProvider {
    static var previews: some View {
        AtomModelView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif
#endif
