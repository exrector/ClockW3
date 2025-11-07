import Foundation

#if os(iOS)
import UIKit
#endif

// MARK: - Haptic Feedback Manager
/// Управляет тактильными откликами для циферблата
/// Поддерживает различные уровни интенсивности в зависимости от типа риски
@MainActor
class HapticFeedback {
    static let shared = HapticFeedback()

    #if os(iOS) && !WIDGET_EXTENSION
    // Генераторы для разных типов тактильного отклика
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)

    // Отслеживание последнего пересечённого тика для предотвращения дублирования
    private var lastCrossedTickIndex: Int?
    private var lastImpactTime: TimeInterval = 0
    private let minImpactInterval: TimeInterval = 0.04  // 40ms минимальный интервал между хаптиками

    private init() {
        // Подготовка всех генераторов для минимальной задержки
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
    }

    // MARK: - Public API

    /// Типы тактильного отклика в зависимости от типа риски
    enum TickType {
        case hour       // Часовая риска (каждые 60 минут) - самая сильная
        case halfHour   // Получасовая риска (каждые 30 минут) - средняя
        case quarter    // Четвертьчасовая риска (каждые 15 минут) - лёгкая
        case minute     // Минутная риска (10, 20, 30, 40, 50) - очень лёгкая

        var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .hour:     return .heavy
            case .halfHour: return .medium
            case .quarter:  return .light
            case .minute:   return .light
            }
        }
    }

    /// Воспроизводит тактильный отклик для пересечения риски циферблата
    /// - Parameters:
    ///   - tickType: Тип риски (часовая, получасовая, четвертьчасовая)
    ///   - tickIndex: Индекс риски (0-95) для предотвращения дублирования
    func playTickCrossing(tickType: TickType, tickIndex: Int) {
        let now = CACurrentMediaTime()

        // Предотвращаем слишком частые вызовы
        guard now - lastImpactTime >= minImpactInterval else { return }

        // Предотвращаем повторные вызовы для той же риски
        if let lastIndex = lastCrossedTickIndex, lastIndex == tickIndex {
            return
        }

        lastCrossedTickIndex = tickIndex
        lastImpactTime = now

        // Выбираем и активируем соответствующий генератор
        let generator: UIImpactFeedbackGenerator
        switch tickType {
        case .hour:
            generator = heavyGenerator
        case .halfHour:
            generator = mediumGenerator
        case .quarter, .minute:
            generator = lightGenerator
        }

        generator.prepare()
        generator.impactOccurred()
    }

    /// Сбрасывает состояние отслеживания (используется при окончании драга или снэпе)
    func reset() {
        lastCrossedTickIndex = nil
    }

    /// Воспроизводит простой тактильный отклик (для кнопок, переключателей и т.д.)
    /// - Parameter intensity: Интенсивность отклика
    func playImpact(intensity: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let now = CACurrentMediaTime()
        guard now - lastImpactTime >= minImpactInterval else { return }
        lastImpactTime = now

        let generator: UIImpactFeedbackGenerator
        switch intensity {
        case .light:
            generator = lightGenerator
        case .medium:
            generator = mediumGenerator
        case .heavy:
            generator = heavyGenerator
        case .rigid:
            generator = rigidGenerator
        case .soft:
            generator = lightGenerator
        @unknown default:
            generator = lightGenerator
        }

        generator.prepare()
        generator.impactOccurred()
    }

    /// Подготавливает генераторы для минимизации задержки
    func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
    }

    #else
    // MARK: - Stub Implementation for widget/macOS/watchOS

    private init() {}

    enum TickType {
        case hour, halfHour, quarter, minute
    }

    func playTickCrossing(tickType: TickType, tickIndex: Int) {}
    func reset() {}
    #if os(iOS)
    func playImpact(intensity: UIImpactFeedbackGenerator.FeedbackStyle = .light) {}
    #else
    func playImpact(intensity: Int = 0) {}
    #endif
    func prepare() {}

    #endif
}

// MARK: - Tick Detection Helper
extension HapticFeedback {
    /// Определяет тип риски по её индексу (0-95)
    /// - Parameter tickIndex: Индекс риски на циферблате (96 рисок всего)
    /// - Returns: Тип риски
    static func tickType(for tickIndex: Int) -> TickType {
        // 96 рисок: 0, 1, 2, ..., 95
        // Часовые риски: каждые 4 тика (0, 4, 8, 12, ..., 92) = 24 часа
        // Получасовые риски: каждые 2 тика, но не часовые (2, 6, 10, ..., 94)
        // Четвертьчасовые: остальные (1, 3, 5, 7, ...)

        let normalizedIndex = tickIndex % ClockConstants.tickCount

        if normalizedIndex % ClockConstants.hourTickSpacing == 0 {
            return .hour
        } else if normalizedIndex % ClockConstants.halfHourTickSpacing == 0 {
            return .halfHour
        } else {
            return .quarter
        }
    }

    /// Вычисляет индекс ближайшей риски для заданного угла поворота
    /// - Parameter angle: Угол в радианах
    /// - Returns: Индекс риски (0-95)
    static func tickIndex(for angle: Double) -> Int {
        // Нормализуем угол к диапазону [0, 2π]
        var normalizedAngle = angle.truncatingRemainder(dividingBy: 2.0 * .pi)
        if normalizedAngle < 0 {
            normalizedAngle += 2.0 * .pi
        }

        // Вычисляем индекс тика
        let anglePerTick = 2.0 * .pi / Double(ClockConstants.tickCount)
        let tickIndex = Int(round(normalizedAngle / anglePerTick)) % ClockConstants.tickCount

        return tickIndex
    }
}
