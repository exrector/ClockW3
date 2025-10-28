import SwiftUI

// MARK: - Corner Decorations
struct CornerScrewDecorationView: View {
    let size: CGSize
    let colorScheme: ColorScheme
    var palette: ClockColorPalette? = nil

    private struct CornerDescriptor {
        let rotation: Angle
        let position: CGPoint
    }

    private static let baseAngles: [Double] = [-10, 10, -170, 170]
    private let randomOffsets: [Double]

    init(size: CGSize, colorScheme: ColorScheme, palette: ClockColorPalette? = nil) {
        self.size = size
        self.colorScheme = colorScheme
        self.palette = palette

        if let stored = CornerScrewDecorationView.cachedOffsets {
            self.randomOffsets = stored
        } else {
            let offsets = (0..<4).map { _ in Double.random(in: -18...18) }
            CornerScrewDecorationView.cachedOffsets = offsets
            self.randomOffsets = offsets
        }
    }

    private static var cachedOffsets: [Double]? = nil

    // Публичный метод для получения угла конкретного винта
    static func getRotationAngle(for index: Int) -> Double {
        guard index >= 0 && index < 4 else { return 0 }
        if let stored = cachedOffsets {
            return baseAngles[index] + stored[index]
        }
        // Если кэш пустой, инициализируем его
        let offsets = (0..<4).map { _ in Double.random(in: -18...18) }
        cachedOffsets = offsets
        return baseAngles[index] + offsets[index]
    }

    private var minDimension: CGFloat {
        min(size.width, size.height)
    }

    private var nutSize: CGFloat {
        let isCircular = abs(size.width - size.height) < 10
        if isCircular {
            // Размер для циферблата
            return minDimension * 0.095 * 0.7
        } else {
            // Размер для панели настроек - в 2 раза больше
            return minDimension * 0.095 * 1.4
        }
    }

    private var cornerDescriptors: [CornerDescriptor] {
        let centerX = size.width / 2
        let centerY = size.height / 2

        // Определяем, круглая ли это область (циферблат) или прямоугольная (панель настроек)
        let isCircular = abs(size.width - size.height) < 10

        if isCircular {
            // Для циферблата - используем старую логику (квадратное размещение)
            let diameter = minDimension * ClockConstants.clockSizeRatio
            let baseRadius = diameter / 2
            let desiredDistance = baseRadius * 1.2
            let maxDistance = max(0, (minDimension / 2 - nutSize / 2) * CGFloat(sqrt(2.0)))
            let radialDistance = min(desiredDistance, maxDistance)
            let diagonal = radialDistance / CGFloat(sqrt(2.0))

            return (0..<4).map { index in
                let baseAngle = CornerScrewDecorationView.baseAngles[index]
                let randomOffset = randomOffsets[index]
                let rotation = Angle.degrees(baseAngle + randomOffset)

                let dx = (index % 2 == 0) ? -diagonal : diagonal
                let dy = (index < 2) ? -diagonal : diagonal

                return CornerDescriptor(
                    rotation: rotation,
                    position: CGPoint(x: centerX + dx, y: centerY + dy)
                )
            }
        } else {
            // Для прямоугольной панели - фиксированные отступы от краёв плитки
            let verticalInset: CGFloat = 8 // 8pt от верха/низа плитки
            let horizontalInset: CGFloat = 16 // 16pt от левого/правого края плитки
            let horizontalOffset = size.width / 2 - horizontalInset
            let verticalOffset = size.height / 2 - verticalInset

            return (0..<4).map { index in
                let baseAngle = CornerScrewDecorationView.baseAngles[index]
                let randomOffset = randomOffsets[index]
                let rotation = Angle.degrees(baseAngle + randomOffset)

                let dx = (index % 2 == 0) ? -horizontalOffset : horizontalOffset
                let dy = (index < 2) ? -verticalOffset : verticalOffset

                return CornerDescriptor(
                    rotation: rotation,
                    position: CGPoint(x: centerX + dx, y: centerY + dy)
                )
            }
        }
    }

    var body: some View {
        ZStack {
            // Декоративные винты для виджетов и неинтерактивных view
            ForEach(Array(cornerDescriptors.enumerated()), id: \.offset) { descriptor in
                cornerScrew(rotation: descriptor.element.rotation)
                    .position(descriptor.element.position)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func cornerScrew(rotation: Angle) -> some View {
        // Если передана палитра, используем её цвета
        let faceFill: Color
        let slotColor: Color

        if let palette = palette {
            // Используем цвет из палитры (для виджетов)
            faceFill = palette.numbers
            slotColor = palette.background == .clear ? Color(white: 0.5, opacity: 0.3) : palette.background
        } else {
            // Стандартная логика для приложения
            let isLight = colorScheme == .light
            faceFill = isLight ? .black : .white
            slotColor = isLight ? .white : .black
        }

        let slotLength = nutSize * 0.56
        let slotThickness = nutSize * 0.16
        let slotCorner = slotThickness * 0.45

        let slotHorizontal = RoundedRectangle(cornerRadius: slotCorner)
            .fill(slotColor)
            .frame(width: slotLength, height: slotThickness)

        let slotVertical = RoundedRectangle(cornerRadius: slotCorner)
            .fill(slotColor)
            .frame(width: slotThickness, height: slotLength)
        return ZStack {
            Circle()
                .fill(faceFill)
            slotHorizontal
            slotVertical
        }
        .frame(width: nutSize, height: nutSize)
        .rotationEffect(rotation)
    }
}
