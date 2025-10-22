#if !WIDGET_EXTENSION
import SwiftUI

enum MiniGameRegistry {
    private static let availableScenes: [any MiniGameScene.Type] = [
        PlanetariumView.self,
        VaultDoorView.self,
        VaultDoorView5.self,
        AtomModelView.self,
        QuantumFieldView.self,
        FlowerOfLifeView.self,
        RingSystemsView.self,
    ]

    // Счетчик для показа пасхалок по очереди
    @AppStorage("easterEggCounter", store: UserDefaults.standard)
    private static var counter: Int = 0

    /// Возвращает следующую пасхалку по кругу (0 → 1 → 0 → 1 → ...)
    static func nextSceneView() -> AnyView {
        guard !availableScenes.isEmpty else {
            return AnyView(Color.black)
        }

        // Получаем текущий индекс по модулю количества сцен
        let index = counter % availableScenes.count
        let type = availableScenes[index]

        // Увеличиваем счетчик для следующего раза
        counter += 1

        return AnyView(type.init())
    }
}
#endif
