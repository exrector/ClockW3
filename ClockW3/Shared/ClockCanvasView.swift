import SwiftUI

// MARK: - Компонент рисования часов для основного приложения
struct ClockCanvasView: View {
    let currentTime: Date
    let cities: [ClockCity]
    let rotationAngle: CGFloat  // Угол вращения контейнера (0 для виджетов, динамичный для app)

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let baseRadius = min(size.width, size.height) / 2.0 * 0.85
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                // Рисуем статичные элементы (фон, тики, цифры, дни месяца, кольца с городами)
                ClockDrawingHelpers.drawStaticElements(
                    context: context,
                    size: size,
                    baseRadius: baseRadius,
                    center: center,
                    currentTime: currentTime,
                    cities: cities
                )

                // Рисуем глобус под стрелками
                ClockDrawingHelpers.drawGlobe(
                    context: context,
                    baseRadius: baseRadius,
                    center: center,
                    rotationAngle: rotationAngle
                )

                // Рисуем вращающиеся элементы (стрелки, подписи городов, weekday bubbles)
                // С учётом rotationAngle для интерактивности в основном приложении
                ClockDrawingHelpers.drawRotatingElements(
                    context: context,
                    size: size,
                    baseRadius: baseRadius,
                    center: center,
                    rotationAngle: rotationAngle,
                    cities: cities,
                    currentTime: currentTime
                )
            }
        }
        .background(Color.black)
    }
}