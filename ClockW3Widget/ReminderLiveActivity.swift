#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            ReminderLiveActivityContentView(context: context)
                .activityBackgroundTint(Color("ClockBackground"))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.red)
                        Text(context.attributes.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.hasTriggered {
                        Text("DONE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    } else {
                        Text(context.state.scheduledDate, style: .timer)
                            .font(.caption.monospacedDigit())
                            .fontWeight(.medium)
                            .multilineTextAlignment(.trailing)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.scheduledDate, style: .time)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reminder at")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(context.state.scheduledDate, style: .time)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(context.state.hasTriggered ? "Status" : "Time left")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if context.state.hasTriggered {
                                Text("DONE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            } else {
                                Text(context.state.scheduledDate, style: .timer)
                                    .font(.caption.monospacedDigit())
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.state.hasTriggered ? "checkmark.circle.fill" : "bell.fill")
                        .foregroundStyle(context.state.hasTriggered ? .green : .red)
                        .font(.caption2)
                    if context.state.hasTriggered {
                        Text("DONE")
                            .font(.caption2)
                            .fontWeight(.bold)
                    } else {
                        Text(context.state.scheduledDate, style: .timer)
                            .font(.caption2.monospacedDigit())
                            .fontWeight(.semibold)
                    }
                }
            } compactTrailing: {
                Text(context.state.scheduledDate, style: .time)
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ReminderLiveActivityContentView: View {
    let context: ActivityViewContext<ReminderLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Icon and Title
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.red)
                        .font(.title3)

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

                if context.state.hasTriggered {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("DONE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                } else {
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
#endif
