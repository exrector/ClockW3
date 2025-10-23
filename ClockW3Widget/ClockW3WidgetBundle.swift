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
        // ПОВОРОТНЫЕ ЦИФЕРБЛАТЫ (со статичной стрелкой):
        ClockW3SmallWidget()        // Маленький поворотный циферблат
        ClockW3ClassicSmallWidget() // Классический маленький поворотный
        ClockW3Widget()             // Основной поворотный циферблат
        ClockW3LargeWidget()        // Большой поворотный циферблат
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOSApplicationExtension 16.1, *) {
            ReminderLiveActivity()  // Live Activity для напоминаний
        }
#endif
    }
}
