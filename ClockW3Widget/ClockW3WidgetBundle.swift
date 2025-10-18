//
//  ClockW3WidgetBundle.swift
//  ClockW3Widget
//
//  Created by AK on 10/12/25.
//

import WidgetKit
import SwiftUI

@main
struct ClockW3WidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        ClockW3Widget()
#if canImport(ActivityKit) && !os(macOS)
        if #available(iOSApplicationExtension 16.1, *) {
            ReminderLiveActivity()
        }
#endif
    }
}
