#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.1, *)
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            ReminderLiveActivityContentView(context: context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ReminderLiveActivityContentView(context: context)
                }
            } compactLeading: {
                Text(context.state.scheduledDate, style: .time)
                    .font(.caption2.bold())
            } compactTrailing: {
                Image(systemName: "bell")
            } minimal: {
                Text(context.state.scheduledDate, style: .time)
                    .font(.caption2)
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct ReminderLiveActivityContentView: View {
    let context: ActivityViewContext<ReminderLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 16) {
            Text(context.attributes.title.uppercased())
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(context.state.scheduledDate, style: .time)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(context.state.scheduledDate, format: Date.FormatStyle()
                    .weekday(.wide)
                    .month()
                    .day()
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.6))
        )
        .padding()
    }
}
#endif
