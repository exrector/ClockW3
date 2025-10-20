import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Clock Face View (основной компонент циферблата)
struct ClockFaceView: View {
    @StateObject private var viewModel = SimpleClockViewModel()  // НОВАЯ ПРОСТАЯ ВЕРСИЯ!
    @State private var isDragBlocked = false
    @Environment(\.colorScheme) private var environmentColorScheme

    private enum ActiveGestureMode { case rotate, scroll }
    @State private var activeMode: ActiveGestureMode? = nil

    // Выбор городов (используем общий UserDefaults для синхронизации с виджетом)
    @AppStorage(
        SharedUserDefaults.selectedCitiesKey,
        store: SharedUserDefaults.shared
    ) private var selectedCityIdentifiers: String = ""
    @AppStorage(
        SharedUserDefaults.seededDefaultsKey,
        store: SharedUserDefaults.shared
    ) private var hasSeededDefaults: Bool = false
    @AppStorage(
        SharedUserDefaults.use12HourFormatKey,
        store: SharedUserDefaults.shared
    ) private var use12HourFormat: Bool = false
    @AppStorage(
        SharedUserDefaults.mechanismDebugKey,
        store: SharedUserDefaults.shared
    ) private var mechanismDebugEnabled: Bool = false
    @State private var screwsUnlocked: [Bool] = [false, false, false, false]
    @State private var screwsRotation: [Double] = [0, 0, 0, 0]
    @State private var initialScrewsRotation: [Double] = [0, 0, 0, 0]
    @State private var currentEasterEggScene: AnyView? = nil
    var interactivityEnabled: Bool = true
    var overrideTime: Date? = nil  // Для виджетов - передаем время из timeline entry
    var overrideColorScheme: ColorScheme? = nil  // Для виджетов - передаем цветовую схему

    // Используем переданную схему или системную
    private var colorScheme: ColorScheme {
        overrideColorScheme ?? environmentColorScheme
    }

    var body: some View {
        GeometryReader { geometry in
            let minSide = min(geometry.size.width, geometry.size.height)
            let size = CGSize(width: minSide, height: minSide)
            let baseRadius = minSide / 2.0 * ClockConstants.clockSizeRatio
            let dialDiameter = baseRadius * 2
            let centerPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let currentTime = overrideTime ?? viewModel.currentTime
            let palette = ClockColorPalette.system(colorScheme: colorScheme)
            // Пасхалка показывается ТОЛЬКО если:
            // 1. Режим активирован (mechanismDebugEnabled)
            // 2. Интерактивность включена (не виджет)
            // 3. Сцена выбрана (currentEasterEggScene != nil)
            let showEasterEgg = mechanismDebugEnabled && interactivityEnabled && currentEasterEggScene != nil

            if showEasterEgg {
                ZStack {
                    palette.background
                        .ignoresSafeArea()

                    #if !WIDGET_EXTENSION
                    if let easterEggScene = currentEasterEggScene {
                        easterEggScene
                            .frame(width: dialDiameter, height: dialDiameter)
                            .clipShape(Circle())
                            .onTapGesture {
                                // Выход из режима пасхалки при нажатии
                                #if os(iOS)
                                HapticFeedback.shared.playImpact(intensity: .light)
                                #endif
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    mechanismDebugEnabled = false
                                    screwsUnlocked = [false, false, false, false]
                                    screwsRotation = [0, 0, 0, 0]
                                    currentEasterEggScene = nil  // Сбрасываем текущую сцену
                                }
                            }
                    }
                    #endif
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                ZStack {
                    // Фон приложения
                    palette.background
                        .ignoresSafeArea()

                    // Основной циферблат
                    ZStack {
                        // Статический фон (Layer01) - НЕ ВРАЩАЕТСЯ
                        StaticBackgroundView(
                            size: size,
                            colors: palette,
                            currentTime: currentTime,
                            use12HourFormat: use12HourFormat
                        )

                        // Декоративные винты в углах (только для неинтерактивных view, например виджетов)
                        if !interactivityEnabled {
                            CornerScrewDecorationView(size: size, colorScheme: colorScheme)
                                .allowsHitTesting(false)
                        }

                        // Вращающиеся кольца с подписями городов
                        CityLabelRingsView(
                            size: size,
                            cities: viewModel.cities,
                            currentTime: viewModel.timeForArrows,
                            palette: palette
                        )
                        .rotationEffect(.radians(viewModel.rotationAngle))
                        .animation(
                            viewModel.isDragging ? .none : .easeOut(duration: 0.3),
                            value: viewModel.rotationAngle
                        )

                        // Вращающийся контейнер со стрелками (Layer05)
                        CityArrowsView(
                            size: size,
                            cities: viewModel.cities,
                            currentTime: viewModel.timeForArrows,
                            minutesOffset: viewModel.minutesOffsetForArrows,
                            palette: palette,
                            containerRotation: viewModel.rotationAngle
                        )
                        .rotationEffect(.radians(viewModel.rotationAngle))
                        .animation(
                            viewModel.isDragging ? .none : .easeOut(duration: 0.3),
                            value: viewModel.rotationAngle
                        )

                        // Интерактивные винты для входа в пасхалку (размещаем ДО центральной кнопки)
                        if interactivityEnabled {
                            allInteractiveScrews(size: size, palette: palette)
                        }

                        if interactivityEnabled {
                            ZStack {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(
                                        width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                                        height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                                    )

                                // Центральный пузырь с AM/PM текстом
                                ZStack {
                                    Circle()
                                        .fill(palette.centerCircle)
                                        .shadow(color: palette.centerCircle.opacity(0.4), radius: baseRadius * 0.02)

                                    if use12HourFormat {
                                        let ampmText = getAMPM(for: currentTime)
                                        Text(ampmText)
                                            .font(.system(size: baseRadius * 0.05, weight: .semibold, design: .default))
                                            .foregroundColor(colorScheme == .light ? .white : .black)
                                    }
                                }
                                .frame(
                                    width: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio),
                                    height: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio)
                                )
                            }
                            .contentShape(Circle())
                            .frame(
                                width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                                height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.7)
                                    .onEnded { _ in
                                        Task {
                                            await viewModel.confirmPreviewReminder()
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                TapGesture()
                                    .onEnded { _ in
                                        #if os(iOS)
                                        HapticFeedback.shared.playImpact(intensity: .medium)
                                        #endif
                                        viewModel.resetRotation()
                                    }
                            )
                            .accessibilityLabel("Reset rotation or hold to confirm reminder")
                        } else {
                            ZStack {
                                Circle()
                                    .fill(palette.centerCircle)

                                if use12HourFormat {
                                    let ampmText = getAMPM(for: currentTime)
                                    Text(ampmText)
                                        .font(.system(size: baseRadius * 0.05, weight: .semibold, design: .default))
                                        .foregroundColor(colorScheme == .light ? .white : .black)
                                }
                            }
                            .frame(
                                width: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio),
                                height: baseRadius * 2 * (use12HourFormat ? ClockConstants.weekdayBubbleRadiusRatio : ClockConstants.centerButtonVisualRatio)
                            )
                            .frame(
                                width: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio,
                                height: baseRadius * 2 * ClockConstants.deadZoneRadiusRatio
                            )
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .clipped()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                // Высокий приоритет, но с фильтрацией направления, чтобы не мешать скроллу
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if !interactivityEnabled { return }
                            if isDragBlocked { return }

                            // Первый контакт: если вне мёртвой зоны — сразу вращаем
                            if activeMode == nil {
                                let startPoint = value.startLocation
                                if isInDeadZone(point: startPoint, center: centerPoint, baseRadius: baseRadius) {
                                    isDragBlocked = true
                                    return
                                }
                                activeMode = .rotate
                                if !viewModel.isDragging {
                                    viewModel.startDrag(at: value.startLocation, in: geometry)
                                }
                            }

                            // Обрабатываем только если выбрано вращение
                            if activeMode == .rotate {
                                viewModel.updateDrag(at: value.location, in: geometry)
                            }
                        }
                        .onEnded { _ in
                            if activeMode == .rotate, !isDragBlocked {
                                viewModel.endDrag()
                            }
                            activeMode = nil
                            isDragBlocked = false
                        }
                )
            }
        }
        .onAppear {
            // ВАЖНО: При загрузке приложения ВСЕГДА показываем циферблат, а не пасхалку
            // Сбрасываем режим пасхалки и все состояния
            mechanismDebugEnabled = false
            currentEasterEggScene = nil
            screwsUnlocked = [false, false, false, false]
            screwsRotation = [0, 0, 0, 0]

            // Инициализируем углы всех 4 винтов из кэша декоративных винтов
            for i in 0..<4 {
                initialScrewsRotation[i] = CornerScrewDecorationView.getRotationAngle(for: i)
            }

            syncCitiesToViewModel()
            if interactivityEnabled {
                viewModel.resumePhysics()
            } else {
                viewModel.suspendPhysics()
            }
        }
        .onDisappear {
            // Останавливаем физику, когда экран уходит (особенно важно для виджетов/превью)
            viewModel.suspendPhysics()
        }
        .onChange(of: selectedCityIdentifiers) { _, _ in
            syncCitiesToViewModel()
        }
    }

    private func syncCitiesToViewModel() {
        var identifiers = selectedCityIdentifiers
            .split(separator: ",")
            .map { String($0) }

        if identifiers.isEmpty {
            let seeded = WorldCity.initialSelectionIdentifiers()
            identifiers = seeded
            selectedCityIdentifiers = seeded.joined(separator: ",")
            hasSeededDefaults = true
        } else {
            let ensured = WorldCity.ensureLocalIdentifier(in: identifiers)
            if ensured != identifiers {
                identifiers = ensured
                selectedCityIdentifiers = ensured.joined(separator: ",")
            }
            if !identifiers.isEmpty {
                hasSeededDefaults = true
            }
        }

        let cities = WorldCity.cities(from: identifiers)
        viewModel.cities = cities
    }
    
    private func isInDeadZone(point: CGPoint, center: CGPoint, baseRadius: CGFloat) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return hypot(dx, dy) <= baseRadius * ClockConstants.deadZoneRadiusRatio
    }

    private func getAMPM(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        return hour < 12 ? "AM" : "PM"
    }

    @ViewBuilder
    private func allInteractiveScrews(size: CGSize, palette: ClockColorPalette) -> some View {
        ForEach(0..<4, id: \.self) { index in
            interactiveScrew(index: index, size: size, palette: palette)
        }
    }

    @ViewBuilder
    private func interactiveScrew(index: Int, size: CGSize, palette: ClockColorPalette) -> some View {
        let layout = screwLayout(for: size, index: index)
        let screwDiameter = layout.diameter
        let position = layout.position
        let isLight = colorScheme == .light
        let faceFill: Color = isLight ? .black : .white
        let slotColor: Color = isLight ? .white : .black

        let slotLength = screwDiameter * 0.56
        let slotThickness = screwDiameter * 0.16
        let slotCorner = slotThickness * 0.45

        ZStack {
            Color.clear

            // Отверстие (появляется когда винт откручивается)
            Circle()
                .stroke(faceFill, lineWidth: screwDiameter * 0.15)
                .frame(width: screwDiameter * 0.6, height: screwDiameter * 0.6)
                .opacity(screwsUnlocked[index] ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.9), value: screwsUnlocked[index])
                .position(position)

            // Винт (исчезает когда откручивается)
            ZStack {
                Circle()
                    .fill(faceFill)

                // Горизонтальный слот
                RoundedRectangle(cornerRadius: slotCorner)
                    .fill(slotColor)
                    .frame(width: slotLength, height: slotThickness)

                // Вертикальный слот
                RoundedRectangle(cornerRadius: slotCorner)
                    .fill(slotColor)
                    .frame(width: slotThickness, height: slotLength)
            }
            .frame(width: screwDiameter, height: screwDiameter)
            .rotationEffect(.degrees(initialScrewsRotation[index] + screwsRotation[index]))
            .opacity(screwsUnlocked[index] ? 0 : 1)
            .animation(.easeOut(duration: 0.3).delay(0.6), value: screwsUnlocked[index])
            .position(position)
            .onTapGesture(count: 2) { unlockScrew(index: index) }
        }
        .frame(width: size.width, height: size.height)
    }

    private func unlockScrew(index: Int) {
        guard !screwsUnlocked[index] else { return }
        screwsUnlocked[index] = true
        withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
            screwsRotation[index] -= 360
        }
        #if os(iOS)
        HapticFeedback.shared.playImpact(intensity: .medium)
        #endif

        // Проверяем, все ли винты откручены
        let allUnlocked = screwsUnlocked.allSatisfy { $0 == true }

        if allUnlocked {
            // Выбираем СЛЕДУЮЩУЮ пасхалку по кругу ОДИН РАЗ при откручивании последнего винта
            #if !WIDGET_EXTENSION
            currentEasterEggScene = MiniGameRegistry.nextSceneView()
            #endif

            // Включаем режим пасхалки с задержкой после анимации вращения последнего винта
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    mechanismDebugEnabled = true
                }
            }
        }
    }

    private func screwLayout(for size: CGSize, index: Int) -> (position: CGPoint, diameter: CGFloat) {
        let minDimension = min(size.width, size.height)
        let centerX = size.width / 2
        let centerY = size.height / 2
        let isCircular = abs(size.width - size.height) < 10

        if isCircular {
            let nutSize = minDimension * 0.095 * 0.7
            let diameter = minDimension * ClockConstants.clockSizeRatio
            let baseRadius = diameter / 2
            let desiredDistance = baseRadius * 1.2
            let maxDistance = max(0, (minDimension / 2 - nutSize / 2) * CGFloat(sqrt(2.0)))
            let radialDistance = min(desiredDistance, maxDistance)
            let diagonal = radialDistance / CGFloat(sqrt(2.0))

            // Вычисляем позицию в зависимости от индекса
            // 0: левый верхний, 1: правый верхний, 2: левый нижний, 3: правый нижний
            let dx = (index % 2 == 0) ? -diagonal : diagonal
            let dy = (index < 2) ? -diagonal : diagonal

            let position = CGPoint(x: centerX + dx, y: centerY + dy)
            return (position, nutSize)
        } else {
            let nutSize = minDimension * 0.095 * 1.4
            let horizontalInset: CGFloat = 16
            let verticalInset: CGFloat = 8
            let horizontalOffset = size.width / 2 - horizontalInset
            let verticalOffset = size.height / 2 - verticalInset

            // Вычисляем позицию в зависимости от индекса
            let dx = (index % 2 == 0) ? -horizontalOffset : horizontalOffset
            let dy = (index < 2) ? -verticalOffset : verticalOffset

            let position = CGPoint(x: centerX + dx, y: centerY + dy)
            return (position, nutSize)
        }
    }
}

// MARK: - City Label Rings View

private extension View {
    @ViewBuilder
    func conditionalGesture<G: Gesture>(_ gesture: G, enabled: Bool) -> some View {
        if enabled {
            self.gesture(gesture)
        } else {
            self
        }
    }
}

#if DEBUG
struct ClockFaceView_Previews: PreviewProvider {
    static var previews: some View {
        ClockFaceView()
    }
}
#endif
