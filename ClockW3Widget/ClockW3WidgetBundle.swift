//
//  ClockW3WidgetBundle.swift
//  ПОВОРОТНЫЙ ЦИФЕРБЛАТ (Статичная стрелка) - Расширение виджетов
//
//  Created by AK on 10/12/25.
//

import WidgetKit
import SwiftUI

// MARK: - ПОВОРОТНЫЙ ЦИФЕРБЛАТ (Статичная стрелка)
// Это расширение виджетов с поворотным циферблатом и статичной стрелкой
// В отличие от основного приложения, здесь стрелка неподвижна, а вращается весь циферблат

@available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, visionOSApplicationExtension 1.0, *)
@main
struct ClockW3WidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        // MediumHalf — первым для удобства в симуляторе
        MediumHalfWidget()          // Половина циферблата (Medium)

        // Флип‑виджет (Medium)
        MediumElectroWidget()

        // Small Electro
        SmallLeftElectroWidget()    // Electro hours (Small)
        SmallRightElectroWidget()   // Electro minutes (Small)

        // КЛАССИЧЕСКИЕ ВИДЖЕТЫ (используют вью из приложения):
        MediumListWidget()          // Список городов (Medium)
        LargeFullFaceWidget()       // Полный циферблат (Large)
        SmallFullFaceWidget()       // Полный циферблат (Small)

        // МОДЕРНИЗИРОВАННЫЕ ВИДЖЕТЫ (своя логика рисования через Canvas):
        SmallQuarterWidget()        // Четверть циферблата (Small)
        LargeQuarterWidget()        // Четверть циферблата (Large)
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOSApplicationExtension 16.1, *) {
            ReminderLiveActivity()  // Live Activity для напоминаний
        }
#endif
    }
}
