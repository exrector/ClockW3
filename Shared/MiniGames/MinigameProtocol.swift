import SwiftUI

/// Базовый контракт для анимированных сцен-пасхалок.
protocol MiniGameScene: View {
    /// Отрисовать сцену в заданном размере и времени.
    /// Возвращаемый View должен быть уже в `.frame(width: size.width, height: size.height)`.
    func render(size: CGSize, time: TimeInterval) -> AnyView
}
