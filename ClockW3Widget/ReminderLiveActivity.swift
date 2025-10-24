#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            // Lock Screen / Notification контент
            ReminderLiveActivityContentView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            // Без Dynamic Island - только minimal состояние (колокольчик справа)
            DynamicIsland {
                // Expanded - не показываем
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                // Compact leading - не показываем
                EmptyView()
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let timeHasPassed = context.state.scheduledDate <= timeline.date
                    let isDone = context.state.hasTriggered || timeHasPassed
                    ReminderIslandBadge(isDone: isDone)
                }
            } minimal: {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let timeHasPassed = context.state.scheduledDate <= timeline.date
                    let isDone = context.state.hasTriggered || timeHasPassed
                    ReminderIslandBadge(isDone: isDone)
                }
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ReminderLiveActivityContentView: View {
    let context: ActivityViewContext<ReminderLiveActivityAttributes>

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let timeHasPassed = context.state.scheduledDate <= timeline.date
            let isTriggered = context.state.hasTriggered || timeHasPassed

            HStack(spacing: 16) {
                // Left side - Icon and Title
                VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.red)
                                .font(.headline)

                            Text(context.attributes.title)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }

                        Text(context.state.scheduledDate, format: Date.FormatStyle()
                                .weekday(.abbreviated)
                                .month(.abbreviated)
                                .day()
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Right side - Time and Countdown
                    VStack(alignment: .trailing, spacing: 8) {
                    Text(context.state.scheduledDate, style: .time)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.trailing)

                    // Показываем DONE если hasTriggered = true
                    if isTriggered {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("DONE")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                    } else {
                        // Показываем таймер
                        HStack(spacing: 4) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.scheduledDate, style: .timer)
                                .font(.caption.monospacedDigit())
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ReminderIslandBadge: View {
    let isDone: Bool

    private var iconColor: Color {
        isDone ? .green : .red
    }

    var body: some View {
        Image(systemName: isDone ? "bell.badge.fill" : "bell.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.primary, iconColor)
            .font(.system(size: 17, weight: .semibold))
            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
    }
}
#endif
