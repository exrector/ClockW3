#if !WIDGET_EXTENSION
import SwiftUI

struct QuantumFieldView: View, MiniGameScene {
    private let layout = QuantumFieldLayout()
    
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
                QuantumFieldBackground()
                    .ignoresSafeArea()
                
                ForEach(layout.energyFields) { field in
                    EnergyFieldLayer(field: field, minSide: minSide, time: time)
                        .frame(width: field.radiusRatio * minSide * 2, height: field.radiusRatio * minSide * 2)
                        .position(center)
                }
                
                ForEach(layout.quantumParticles) { particle in
                    QuantumParticle(particle: particle, minSide: minSide, time: time)
                        .position(
                            particle.position(
                                center: center,
                                minSide: minSide,
                                time: time
                            )
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white,
                                    Color.red.opacity(0.8),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 10
                            )
                        )
                        .frame(width: 20, height: 20)
                        .blur(radius: 1)
                    
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.red.opacity(0.9),
                                    Color.white,
                                    Color.red.opacity(0.9)
                                ]),
                                center: .center,
                                angle: .radians(time * 2)
                            )
                        )
                        .frame(width: 10, height: 10)
                }
                .allowsHitTesting(false)
                .frame(width: 20, height: 20)
                .position(
                    CGPoint(
                        x: center.x + CGFloat(sin(time * 0.5)) * minSide * 0.1,
                        y: center.y + CGFloat(cos(time * 0.7)) * minSide * 0.08
                    )
                )
            }
            .frame(width: size.width, height: size.height)
        )
    }
}

// MARK: - Layout
private struct QuantumFieldLayout {
    struct EnergyField: Identifiable {
        let id = UUID()
        let radiusRatio: CGFloat
        let frequency: Double
        let amplitude: CGFloat
        let speed: Double
        let color: Color
        let phase: Double
        let opacity: Double
        let thickness: CGFloat
        let particleDensity: CGFloat
    }
    
    struct QuantumParticle: Identifiable {
        let id = UUID()
        let initialPosition: CGPoint  // Position relative to center (0...1)
        let sizeRatio: CGFloat
        let color: Color
        let oscillationSpeed: Double
        let oscillationRadius: CGFloat
        let phase: Double
        let lifetime: Double
        let creationTime: Double
        
        func position(center: CGPoint, minSide: CGFloat, time: TimeInterval) -> CGPoint {
            let oscillationAngle = time * oscillationSpeed + phase
            let currentRadius = oscillationRadius * minSide * (0.8 + 0.2 * sin(time * 2))
            
            return CGPoint(
                x: center.x + (initialPosition.x - 0.5) * minSide + CGFloat(cos(oscillationAngle)) * currentRadius,
                y: center.y + (initialPosition.y - 0.5) * minSide + CGFloat(sin(oscillationAngle)) * currentRadius
            )
        }
    }
    
    let energyFields: [EnergyField]
    let quantumParticles: [QuantumParticle]
    
    init() {
        energyFields = [
            EnergyField(radiusRatio: 0.15, frequency: 8, amplitude: 0.01, speed: 1.2, color: Color.red.opacity(0.85), phase: 0, opacity: 0.7, thickness: 0.003, particleDensity: 0.02),
            EnergyField(radiusRatio: 0.28, frequency: 5, amplitude: 0.015, speed: 0.8, color: Color.white.opacity(0.75), phase: .pi/3, opacity: 0.5, thickness: 0.002, particleDensity: 0.015),
            EnergyField(radiusRatio: 0.42, frequency: 7, amplitude: 0.012, speed: 1.0, color: Color.red.opacity(0.65), phase: 2 * .pi/3, opacity: 0.3, thickness: 0.0015, particleDensity: 0.01),
            EnergyField(radiusRatio: 0.56, frequency: 6, amplitude: 0.008, speed: 0.9, color: Color.white.opacity(0.6), phase: .pi, opacity: 0.2, thickness: 0.001, particleDensity: 0.008)
        ]
        
        var particles: [QuantumParticle] = []
        for i in 0..<80 {
            particles.append(
                QuantumParticle(
                    initialPosition: CGPoint(
                        x: CGFloat.random(in: 0...1),
                        y: CGFloat.random(in: 0...1)
                    ),
                    sizeRatio: CGFloat.random(in: 0.005...0.015),
                    color: Double.random(in: 0...1) > 0.7 ? Color.red.opacity(0.8) : Color.white.opacity(0.9),
                    oscillationSpeed: Double.random(in: 1.0...3.0),
                    oscillationRadius: CGFloat.random(in: 0.01...0.05),
                    phase: Double.random(in: 0...(2 * .pi)),
                    lifetime: 10,
                    creationTime: Double(i) * 0.1
                )
            )
        }
        
        quantumParticles = particles
    }
}

// MARK: - Elements
private struct EnergyFieldLayer: View {
    let field: QuantumFieldLayout.EnergyField
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let waveValue = getWaveValue(time: time)
        
        return Circle()
            .trim(from: 0, to: 0.99)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        field.color,
                        field.color.opacity(0.3),
                        field.color.opacity(0.6)
                    ]),
                    center: .center,
                    angle: .radians(time * 0.8)
                ),
                style: StrokeStyle(
                    lineWidth: field.thickness * minSide,
                    lineCap: .round
                )
            )
            .frame(width: field.radiusRatio * minSide * 2 * (1 + CGFloat(waveValue)), height: field.radiusRatio * minSide * 2 * (1 + CGFloat(waveValue)))
            .opacity(field.opacity)
            .blur(radius: field.thickness * minSide * 2)
    }
    
    private func getWaveValue(time: TimeInterval) -> Double {
        return sin(time * field.frequency + field.phase) * field.amplitude
    }
}

private struct QuantumParticle: View {
    let particle: QuantumFieldLayout.QuantumParticle
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let size = particle.sizeRatio * minSide
        let pulseFactor = 0.8 + 0.2 * sin(time * 5 + particle.phase)
        let finalSize = size * CGFloat(pulseFactor)
        
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            particle.color,
                            particle.color.opacity(0.7),
                            particle.color.opacity(0.2)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: finalSize/2
                    )
                )
                .frame(width: finalSize, height: finalSize)
                .shadow(color: particle.color.opacity(0.8), radius: finalSize * 0.8)
        }
    }
}

private struct QuantumFieldBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 5/255, green: 5/255, blue: 8/255),
                Color(red: 15/255, green: 10/255, blue: 20/255),
                Color(red: 5/255, green: 5/255, blue: 8/255)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.2),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
        )
    }
}

#if DEBUG
struct QuantumFieldView_Previews: PreviewProvider {
    static var previews: some View {
        QuantumFieldView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif

#endif