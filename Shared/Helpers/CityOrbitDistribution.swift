import Foundation

// MARK: - City Orbit Distribution Result
struct OrbitDistributionResult {
    let assignment: [UUID: Int]
    let hasConflicts: Bool
    let conflictMessage: String?
}

// MARK: - City Orbit Distribution
struct CityOrbitDistribution {

    /// Распределяет города по орбитам (1 или 2)
    static func distributeCities(
        cities: [WorldCity],
        currentTime: Date
    ) -> OrbitDistributionResult {
        guard !cities.isEmpty else {
            return OrbitDistributionResult(assignment: [:], hasConflicts: false, conflictMessage: nil)
        }

        var assignment: [UUID: Int] = [:]
        var conflicts: [String] = []

        // Используем ОТНОСИТЕЛЬНЫЕ значения (коэффициенты)
        let fontSizeRatio = ClockConstants.labelRingFontSizeRatio  // 0.05
        let letterSpacingRatio = fontSizeRatio * 0.8  // 0.04

        // Размещаем города по очереди, предпочитая шахматный порядок
        var nextPreferredOrbit = 1

        for city in cities {
            guard let timeZone = city.timeZone else { continue }

            var calendar = Calendar.current
            calendar.timeZone = timeZone

            let hour = Double(calendar.component(.hour, from: currentTime))
            let minute = Double(calendar.component(.minute, from: currentTime))
            let hour24 = hour + minute / 60.0
            let centerAngle = ClockConstants.calculateArrowAngle(hour24: hour24)

            // Пробуем сначала предпочитаемую орбиту, потом другую
            let orbitsToTry = nextPreferredOrbit == 1 ? [1, 2] : [2, 1]
            var placed = false

            for orbit in orbitsToTry {
                let radiusRatio = orbit == 1 ? ClockConstants.outerLabelRingRadius : ClockConstants.middleLabelRingRadius

                // Вычисляем интервал для этого города на этой орбите
                let cityCode = city.iataCode
                let letterCount = cityCode.count
                // ВАЖНО: при рисовании используется (letterCount - 1), т.к. это расстояния МЕЖДУ буквами
                let totalWidthRatio = Double(letterCount - 1) * letterSpacingRatio
                // Угловая ширина = линейная ширина / радиус (всё в относительных единицах)
                let angularWidth = totalWidthRatio / radiusRatio

                // Минимальный зазор с каждой стороны (для предотвращения наложения)
                let minGap = letterSpacingRatio / radiusRatio * 2.0

                // Интервал города УЖЕ включает зазоры слева и справа
                let startAngle = centerAngle - angularWidth / 2 - minGap
                let endAngle = centerAngle + angularWidth / 2 + minGap

                // Проверяем конфликты с уже размещёнными городами на этой орбите
                let orbitCities = cities.filter { assignment[$0.id] == orbit }
                var hasConflict = false

                for existingCity in orbitCities {
                    guard let existingTZ = existingCity.timeZone else { continue }

                    var cal = Calendar.current
                    cal.timeZone = existingTZ

                    let h = Double(cal.component(.hour, from: currentTime))
                    let m = Double(cal.component(.minute, from: currentTime))
                    let h24 = h + m / 60.0
                    let existingAngle = ClockConstants.calculateArrowAngle(hour24: h24)

                    let existingCode = existingCity.iataCode
                    let existingCount = existingCode.count
                    // ВАЖНО: при рисовании используется (count - 1), т.к. это расстояния МЕЖДУ буквами
                    let existingWidthRatio = Double(existingCount - 1) * letterSpacingRatio
                    let existingAngular = existingWidthRatio / radiusRatio

                    // Интервал существующего города тоже включает зазоры
                    let existingStart = existingAngle - existingAngular / 2 - minGap
                    let existingEnd = existingAngle + existingAngular / 2 + minGap

                    if intervalsOverlap(startAngle, endAngle, existingStart, existingEnd) {
                        hasConflict = true
                        break
                    }
                }

                if !hasConflict {
                    assignment[city.id] = orbit
                    placed = true
                    break
                }
            }

            if !placed {
                // Конфликт на обеих орбитах
                conflicts.append("Cannot place \(city.name) - both orbits are occupied")
            } else {
                // Чередуем предпочитаемую орбиту для следующего города
                nextPreferredOrbit = nextPreferredOrbit == 1 ? 2 : 1
            }
        }

        return OrbitDistributionResult(
            assignment: assignment,
            hasConflicts: !conflicts.isEmpty,
            conflictMessage: conflicts.isEmpty ? nil : conflicts.joined(separator: "\n")
        )
    }

    // Проверка пересечения двух угловых интервалов
    private static func intervalsOverlap(_ start1: Double, _ end1: Double,
                                        _ start2: Double, _ end2: Double) -> Bool {
        // Нормализуем углы в [0, 2π]
        let s1 = normalizeAngle(start1)
        let e1 = normalizeAngle(end1)
        let s2 = normalizeAngle(start2)
        let e2 = normalizeAngle(end2)

        // Если интервал пересекает 0° (start > end), нужна специальная логика
        let interval1CrossesZero = s1 > e1
        let interval2CrossesZero = s2 > e2

        if interval1CrossesZero && interval2CrossesZero {
            // Оба интервала пересекают 0° - они всегда пересекаются
            return true
        } else if interval1CrossesZero {
            // Первый интервал: [s1, 2π] ∪ [0, e1]
            // НЕ пересекается только если второй интервал целиком в промежутке (e1, s1)
            return !(s2 > e1 && e2 < s1)
        } else if interval2CrossesZero {
            // Второй интервал: [s2, 2π] ∪ [0, e2]
            // НЕ пересекается только если первый интервал целиком в промежутке (e2, s2)
            return !(s1 > e2 && e1 < s2)
        } else {
            // Оба интервала нормальные [start, end]
            return !(e1 < s2 || e2 < s1)
        }
    }

    private static func normalizeAngle(_ angle: Double) -> Double {
        var result = angle
        while result < 0 { result += 2 * .pi }
        while result >= 2 * .pi { result -= 2 * .pi }
        return result
    }
}
