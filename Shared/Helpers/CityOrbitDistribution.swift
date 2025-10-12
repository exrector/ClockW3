import Foundation

// MARK: - City Orbit Distribution
/// Распределяет города по двум орбитам, избегая наложения текста
struct CityOrbitDistribution {

    /// Распределяет города по орбитам (1 или 2)
    static func distributeCities(
        cities: [WorldCity],
        currentTime: Date
    ) -> [UUID: Int] {
        guard !cities.isEmpty else { return [:] }

        // Вычисляем углы для всех городов
        let cityAngles: [(city: WorldCity, angle: Double)] = cities.compactMap { city in
            guard let timeZone = city.timeZone else { return nil }

            var calendar = Calendar.current
            calendar.timeZone = timeZone

            let hour = Double(calendar.component(.hour, from: currentTime))
            let minute = Double(calendar.component(.minute, from: currentTime))
            let hour24 = hour + minute / 60.0
            let angle = ClockConstants.calculateArrowAngle(hour24: hour24)

            return (city, angle)
        }

        // Вычисляем интервалы для каждого города
        var intervals: [CityInterval] = []
        let fontSize = ClockConstants.labelRingFontSizeRatio // Относительный размер
        let letterSpacing = fontSize * 0.8

        for cityEntry in cityAngles {
            let cityCode = cityEntry.city.iataCode
            let textWidth = Double(cityCode.count) * Double(letterSpacing)
            let padding = Double(letterSpacing) * 0.5
            let span = textWidth + 2 * padding

            var start = cityEntry.angle - span / 2
            var end = cityEntry.angle + span / 2

            // Нормализуем в [0, 2π]
            start = normalizeAngle(start)
            end = normalizeAngle(end)

            // Если интервал пересекает 0, разбиваем на два
            if start > end {
                intervals.append(CityInterval(
                    cityId: cityEntry.city.id,
                    angle: cityEntry.angle,
                    start: start,
                    end: 2 * .pi
                ))
                intervals.append(CityInterval(
                    cityId: cityEntry.city.id,
                    angle: cityEntry.angle,
                    start: 0,
                    end: end
                ))
            } else {
                intervals.append(CityInterval(
                    cityId: cityEntry.city.id,
                    angle: cityEntry.angle,
                    start: start,
                    end: end
                ))
            }
        }

        // Сортируем интервалы
        intervals.sort { a, b in
            if abs(a.start - b.start) < 0.0001 {
                return a.cityId.uuidString < b.cityId.uuidString
            }
            return a.start < b.start
        }

        // Группируем в кластеры (города с пересекающимися интервалами)
        let clusters = buildClusters(intervals: intervals)

        // Распределяем кластеры по двум орбитам
        return distributeClustersAcrossOrbits(
            clusters: clusters,
            cityAngles: cityAngles
        )
    }

    // MARK: - Private Helpers

    private static func normalizeAngle(_ angle: Double) -> Double {
        var result = angle
        while result < 0 { result += 2 * .pi }
        while result >= 2 * .pi { result -= 2 * .pi }
        return result
    }

    private static func buildClusters(intervals: [CityInterval]) -> [[UUID]] {
        var clusters: [[UUID]] = []
        var cityToCluster: [UUID: Int] = [:]

        for interval in intervals {
            // Ищем кластер с пересечением
            var foundCluster: Int? = nil

            for (clusterIndex, cluster) in clusters.enumerated() {
                let clusterIntervals = intervals.filter { cluster.contains($0.cityId) }
                for clusterInterval in clusterIntervals {
                    if interval.overlaps(with: clusterInterval) {
                        foundCluster = clusterIndex
                        break
                    }
                }
                if foundCluster != nil { break }
            }

            if let clusterIndex = foundCluster {
                if !clusters[clusterIndex].contains(interval.cityId) {
                    clusters[clusterIndex].append(interval.cityId)
                }
                cityToCluster[interval.cityId] = clusterIndex
            } else {
                clusters.append([interval.cityId])
                cityToCluster[interval.cityId] = clusters.count - 1
            }
        }

        // Проверяем замыкание круга
        if clusters.count > 1 {
            let firstCluster = clusters[0]
            let lastCluster = clusters[clusters.count - 1]

            let firstIntervals = intervals.filter {
                firstCluster.contains($0.cityId) && $0.start < .pi
            }
            let lastIntervals = intervals.filter {
                lastCluster.contains($0.cityId) && $0.end > .pi
            }

            var shouldMerge = false
            for lastInterval in lastIntervals {
                for firstInterval in firstIntervals {
                    let gap = (2 * .pi - lastInterval.end) + firstInterval.start
                    if gap < 0.01 {
                        shouldMerge = true
                        break
                    }
                }
                if shouldMerge { break }
            }

            if shouldMerge {
                clusters[0].append(contentsOf: lastCluster)
                for cityId in lastCluster {
                    cityToCluster[cityId] = 0
                }
                clusters.removeLast()
            }
        }

        return clusters
    }

    private static func distributeClustersAcrossOrbits(
        clusters: [[UUID]],
        cityAngles: [(city: WorldCity, angle: Double)]
    ) -> [UUID: Int] {
        var orbit1Cities: [UUID] = []
        var orbit2Cities: [UUID] = []

        for cluster in clusters {
            let uniqueCities = Array(Set(cluster))

            if uniqueCities.count == 1 {
                // Одиночный город - балансируем
                let cityId = uniqueCities[0]

                if orbit1Cities.count <= orbit2Cities.count {
                    orbit1Cities.append(cityId)
                } else {
                    orbit2Cities.append(cityId)
                }
            } else {
                // Кластер - распределяем round-robin
                let sortedCluster = uniqueCities.sorted { id1, id2 in
                    guard let city1 = cityAngles.first(where: { $0.city.id == id1 }),
                          let city2 = cityAngles.first(where: { $0.city.id == id2 }) else {
                        return id1.uuidString < id2.uuidString
                    }
                    if abs(city1.angle - city2.angle) < 0.0001 {
                        return id1.uuidString < id2.uuidString
                    }
                    return city1.angle < city2.angle
                }

                for (index, cityId) in sortedCluster.enumerated() {
                    if index % 2 == 0 {
                        orbit1Cities.append(cityId)
                    } else {
                        orbit2Cities.append(cityId)
                    }
                }
            }
        }

        // Формируем результат
        var assignment: [UUID: Int] = [:]
        for cityId in orbit1Cities { assignment[cityId] = 1 }
        for cityId in orbit2Cities { assignment[cityId] = 2 }

        return assignment
    }
}

// MARK: - City Interval
private struct CityInterval {
    let cityId: UUID
    let angle: Double
    let start: Double
    let end: Double

    func overlaps(with other: CityInterval) -> Bool {
        return !(end < other.start || other.end < start)
    }
}
