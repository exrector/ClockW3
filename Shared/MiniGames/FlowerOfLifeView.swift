#if !WIDGET_EXTENSION
import SwiftUI

struct FlowerOfLifeView: View, MiniGameScene {
    private let layout = FlowerOfLifeLayout()
    
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
                SacredGeometryBackground()
                    .ignoresSafeArea()
                
                ForEach(layout.flowers) { flower in
                    SacredCircle(circle: flower, minSide: minSide, time: time)
                        .frame(width: flower.radiusRatio * minSide * 2, height: flower.radiusRatio * minSide * 2)
                        .position(flower.position(center: center, minSide: minSide))
                }
                
                CentralSacredCircle(minSide: minSide)
                    .frame(width: minSide * 0.15, height: minSide * 0.15)
                    .position(center)
            }
            .frame(width: size.width, height: size.height)
        )
    }
}

// MARK: - Layout
private struct FlowerOfLifeLayout {
    struct SacredCircle: Identifiable {
        let id = UUID()
        let radiusRatio: CGFloat
        let color: Color
        let positionRatio: CGPoint
        let pulseSpeed: Double
        let basePhase: Double
        
        func position(center: CGPoint, minSide: CGFloat) -> CGPoint {
            return CGPoint(
                x: center.x + positionRatio.x * minSide,
                y: center.y + positionRatio.y * minSide
            )
        }
    }
    
    let flowers: [SacredCircle]
    
    init() {
        // Creating 19 circles for the classic flower of life pattern
        flowers = [
            // Center circle
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.9), positionRatio: CGPoint(x: 0, y: 0), pulseSpeed: 0.8, basePhase: 0),
            
            // First ring of 6 circles
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.6), positionRatio: CGPoint(x: 0.08, y: 0), pulseSpeed: 0.9, basePhase: 0),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.7), positionRatio: CGPoint(x: -0.08, y: 0), pulseSpeed: 1.0, basePhase: .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.5), positionRatio: CGPoint(x: 0.04, y: 0.069), pulseSpeed: 0.85, basePhase: 2 * .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.6), positionRatio: CGPoint(x: -0.04, y: -0.069), pulseSpeed: 1.1, basePhase: .pi),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.4), positionRatio: CGPoint(x: 0.04, y: -0.069), pulseSpeed: 0.95, basePhase: 4 * .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.5), positionRatio: CGPoint(x: -0.04, y: 0.069), pulseSpeed: 0.75, basePhase: 5 * .pi/3),
            
            // Second ring of 12 circles
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.3), positionRatio: CGPoint(x: 0.16, y: 0), pulseSpeed: 1.05, basePhase: 0),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.4), positionRatio: CGPoint(x: -0.16, y: 0), pulseSpeed: 0.92, basePhase: .pi/6),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.25), positionRatio: CGPoint(x: 0.08, y: 0.138), pulseSpeed: 1.12, basePhase: .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.35), positionRatio: CGPoint(x: -0.08, y: -0.138), pulseSpeed: 0.88, basePhase: 2 * .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.2), positionRatio: CGPoint(x: 0.08, y: -0.138), pulseSpeed: 1.18, basePhase: .pi/2),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.3), positionRatio: CGPoint(x: -0.08, y: 0.138), pulseSpeed: 0.82, basePhase: 4 * .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.15), positionRatio: CGPoint(x: 0.12, y: 0.069), pulseSpeed: 1.22, basePhase: 5 * .pi/6),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.25), positionRatio: CGPoint(x: -0.12, y: -0.069), pulseSpeed: 0.78, basePhase: 7 * .pi/6),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.12), positionRatio: CGPoint(x: 0.12, y: -0.069), pulseSpeed: 1.25, basePhase: 7 * .pi/6),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.2), positionRatio: CGPoint(x: -0.12, y: 0.069), pulseSpeed: 0.75, basePhase: 11 * .pi/6),
            SacredCircle(radiusRatio: 0.08, color: Color.red.opacity(0.1), positionRatio: CGPoint(x: 0, y: 0.138), pulseSpeed: 1.3, basePhase: 2 * .pi/3),
            SacredCircle(radiusRatio: 0.08, color: Color.white.opacity(0.18), positionRatio: CGPoint(x: 0, y: -0.138), pulseSpeed: 0.7, basePhase: 5 * .pi/3)
        ]
    }
}

// MARK: - Elements
private struct SacredCircle: View {
    let circle: FlowerOfLifeLayout.SacredCircle
    let minSide: CGFloat
    let time: TimeInterval
    
    var body: some View {
        let pulseFactor = 0.95 + 0.05 * sin(time * circle.pulseSpeed + circle.basePhase)
        let size = circle.radiusRatio * minSide * 2 * CGFloat(pulseFactor)
        
        return ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            circle.color,
                            circle.color.opacity(0.3),
                            circle.color,
                            circle.color.opacity(0.5)
                        ]),
                        center: .center,
                        angle: .radians(time * 0.3 + circle.basePhase)
                    ),
                    lineWidth: 0.5
                )
                .frame(width: size, height: size)
                .shadow(color: circle.color.opacity(0.4), radius: 1)
            
            Circle()
                .stroke(circle.color.opacity(0.15), lineWidth: 1.5)
                .frame(width: size * 1.2, height: size * 1.2)
        }
    }
}

private struct CentralSacredCircle: View {
    let minSide: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.7),
                            Color.red.opacity(0.05),
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
                            Color.red.opacity(0.4)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: minSide * 0.07
                    )
                )
                .frame(width: minSide * 0.14, height: minSide * 0.14)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: minSide * 0.01)
                )
        }
        .allowsHitTesting(false)
    }
}

private struct SacredGeometryBackground: View {
    var body: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 15/255, green: 15/255, blue: 20/255),
                Color(red: 5/255, green: 5/255, blue: 8/255)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 600
        )
    }
}

#if DEBUG
struct FlowerOfLifeView_Previews: PreviewProvider {
    static var previews: some View {
        FlowerOfLifeView()
            .frame(width: 400, height: 400)
            .preferredColorScheme(.dark)
    }
}
#endif

#endif