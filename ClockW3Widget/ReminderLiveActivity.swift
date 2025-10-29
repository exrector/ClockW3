#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import WidgetKit
import SwiftUI
// No AppIntents here; DONE is purely visual

@available(iOSApplicationExtension 16.1, *)
struct ReminderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            ReminderLiveActivityContentView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
            DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.red)
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
                // Left side: Title (single-line), City and Date
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)

                    if let city = context.state.selectedCityName, !city.isEmpty {
                        Text(city)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    // Always show the date as a second line
                    // System-formatted date per device settings
                    Text(context.state.endDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // No DONE badge; rely on a large countdown timer on the right
                }

                Spacer()

                // Right side: large countdown timer only (00:00 after end)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(16)
    }
}

@available(iOSApplicationExtension 16.1, *)
private extension ReminderLiveActivityContentView {}

// (Badge removed — no bell icon in Dynamic Island)
#endif
