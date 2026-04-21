import ActivityKit
import SwiftUI
import WidgetKit

struct TaktTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaktTimerAttributes.self) { context in
            TaktLiveActivityLockView(state: context.state, presetName: context.attributes.presetName)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.presetName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(taktFormatTime(context.state.remainingSeconds))
                        .font(.title3.weight(.bold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.segmentTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(taktFormatTime(context.state.remainingSeconds))
                    .font(.caption2.weight(.bold).monospacedDigit())
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

private func taktFormatTime(_ sec: Int) -> String {
    let m = sec / 60
    let s = sec % 60
    return String(format: "%d:%02d", m, s)
}

private struct TaktLiveActivityLockView: View {
    let state: TaktTimerAttributes.ContentState
    let presetName: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presetName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(state.segmentTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Segment \(state.segmentIndex + 1) of \(max(state.segmentCount, 1))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(taktFormatTime(state.remainingSeconds))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if state.isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
}
