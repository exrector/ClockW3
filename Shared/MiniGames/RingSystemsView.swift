#if !WIDGET_EXTENSION
import SwiftUI

struct RingSystemsView: View, MiniGameScene {
    private let layout = RingSystemsLayout()
    
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
                RingSystemsBackground()
                    .ignoresSafeArea()
                
                ForEach(layout.ringSystems) { ringSystem in
                    RingSystemView(ringSystem: ringSystem, minSide: minSide, time: time)
                        .frame(width: ringSystem.radiusRatio * minSide * 2, height: ringSystem.radiusRatio * minSide * 2)
                        .position(center)
                }
                
                ForEach(layout.particles) { particle in
                    RingParticle(particle: particle, minSide: minSide, time: time)
                        .position(
                            particle.position(
                                center: center,
                                minSide: minSide,
                                time: time
                            )
                        )
                }
                
                RingSystemCore(minSide: minSide)
                    .frame(width: minSide * 0.15, height: minSide * 0.15)
                    .position(center)
            }
            .frame(width: size.width, height: size.height)
        )
    }
}

// MARK: - Layout
private struct RingSystemsLayout {
    struct RingSystem: Identifiable {
        let id = UUID()
        let radiusRatio: CGFloat
        let rotationSpeed: Double
        let rotationDirection: Double
        let ringCount: Int
        let ringColor: Color
        let opacity: Double
        let lineWidthRatio: CGFloat
    }
    
    struct RingParticle: Identifiable {
        let id = UUID()
        let ringSystemIndex: Int
        let positionRatio: CGFloat  // 0 to 1 along the ring
        let sizeRatio: CGFloat
        let color: Color
        let rotationSpeed: Double
        let orbitRadiusRatio: CGFloat
        let pulseSpeed: Double
        
        func position(center: CGPoint, minSide: CGFloat, time: TimeInterval) -> CGPoint {
            let angle = (time * rotationSpeed) + (2 * .pi * Double(positionRatio))
            let radius = orbitRadiusRatio * minSide
            
            return CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
        }
    }
    
    let ringSystems: [RingSystem]
    let particles: [RingParticle]
    
    init() {
        ringSystems = [
            RingSystem(radiusRatio: 0.22, rotationSpeed: 0.4, rotationDirection: 1, ringCount: 3, ringColor: Color.red.opacity(0.6), opacity: 0.3, lineWidthRatio: 0.004),
            RingSystem(radiusRatio: 0.32, rotationSpeed: 0.25, rotationDirection: -1, ringCount: 4, ringColor: Color.white.opacity(0.7), opacity: 0.25, lineWidthRatio: 0.003),
            RingSystem(radiusRatio: 0.42, rotationSpeed: 0.35, rotationDirection: 1, ringCount: 5, ringColor: Color.red.opacity(0.5), opacity: 0.2, lineWidthRatio: 0.0025),
            RingSystem(radiusRatio: 0.52, rotationSpeed: 0.15, rotationDirection: -1, ringCount: 6, ringColor: Color.white.opacity(0.6), opacity: 0.15, lineWidthRatio: 0.002)
        ]
        
        var allParticles: [RingParticle] = []
        for (i, ringSystem) in ringSystems.enumerated() {
            for j in 0..<Int(ringSystem.ringCount * 4) {  // More particles than rings
                let positionRatio = CGFloat(Double(j) / Double(ringSystem.ringCount * 4))
                let color = j % 2 == 0 ? Color.white.opacity(0.85) : Color.red.opacity(0.75)
                
                allParticles.append(
                    RingParticle(
                        ringSystemIndex: i,
                        positionRatio: positionRatio,
                        sizeRatio: 0.008 + CGFloat.random(in: -0.001...0.001),
                        color: color,
                        rotationSpeed: ringSystem.rotationSpeed * (1 + Double.random(in: -0.1...0.1)),
                        orbitRadiusRatio: ringSystem.radiusRatio + CGFloat.random(in: -0.02...0.02),
                        pulseSpeed: 0.8 + Double.random(in: -0.2...0.2)
                    )
                )
            }
        }
        
        particles = allParticles
    }
}

// MARK: - Elements
private struct RingSystemView: View {
    let ringSystem: RingSystemsLayout.RingSystem
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let rotationAngle = ringSystem.rotationDirection * ringSystem.rotationSpeed * time
        
        return ZStack {
            ForEach(0..<ringSystem.ringCount, id: \.self) { i in
                let offset = CGFloat(i) * 0.02
                let radius = (ringSystem.radiusRatio - offset) * minSide
                
                Circle()
                    .trim(from: 0, to: 0.99)
                    .stroke(
                        ringSystem.ringColor.opacity(ringSystem.opacity),
                        style: StrokeStyle(
                            lineWidth: ringSystem.lineWidthRatio * minSide,
                            lineCap: .round
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.radians(rotationAngle + Double(i) * .pi/8))
            }
        }
    }
}

private struct RingParticle: View {
    let particle: RingSystemsLayout.RingParticle
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let size = particle.sizeRatio * minSide
        let pulseFactor = 0.9 + 0.1 * sin(time * particle.pulseSpeed)
        let finalSize = size * CGFloat(pulseFactor)
        
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            particle.color,
                            particle.color.opacity(0.6)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: finalSize/2
                    )
                )
                .frame(width: finalSize, height: finalSize)
                .shadow(color: particle.color.opacity(0.6), radius: finalSize * 0.5)
        }
    }
}

private struct RingSystemCore: View {
    let minSide: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.9),
                            Color.red.opacity(0.3),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: minSide * 0.12
                    )
                )
                .frame(width: minSide * 0.24, height: minSide * 0.24)
                .blur(radius: 1)
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white,
                            Color.red.opacity(0.6)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: minSide * 0.08
                    )
                )
                .frame(width: minSide * 0.16, height: minSide * 0.16)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: minSide * 0.015)
                )
        }
        .allowsHitTesting(false)
    }
}

private struct RingSystemsBackground: View {
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 8/255, green: 10/255, blue: 14/255),
                Color(red: 2/255, green: 4/255, blue: 8/255)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 600
        )
    }
}

#if DEBUG
struct RingSystemsView_Previews: PreviewProvider {
    static var previews: some View {
        RingSystemsView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif

#endif