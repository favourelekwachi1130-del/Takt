import SwiftUI
import WidgetKit

private struct TaktTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaktTimerEntry {
        TaktTimerEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaktTimerEntry) -> Void) {
        completion(TaktTimerEntry(date: .now, snapshot: TaktTimerSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaktTimerEntry>) -> Void) {
        let snap = TaktTimerSnapshot.load() ?? .placeholder
        let entry = TaktTimerEntry(date: .now, snapshot: snap)
        let refresh = Date().addingTimeInterval(snap.sessionActive ? 30 : 3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

private struct TaktTimerEntry: TimelineEntry {
    let date: Date
    let snapshot: TaktTimerSnapshot
}

struct TaktTimerLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.presentationtimer.timer", provider: TaktTimerProvider()) { entry in
            TaktTimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Takt timer")
        .description("Shows your current talk and segment time when a session is running.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

private struct TaktTimerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TaktTimerEntry

    var body: some View {
        switch family {
        case .accessoryRectangular, .accessoryInline:
            accessoryView
        default:
            systemSmallView
        }
    }

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot.presetName)
                .font(.headline.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack {
                Text(entry.snapshot.segmentTitle)
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(timeString(entry.snapshot.remainingSeconds))
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .minimumScaleFactor(0.8)
        }
        .widgetAccentable()
    }

    private var systemSmallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Takt")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            Text(entry.snapshot.presetName)
                .font(.headline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if entry.snapshot.sessionActive {
                Text(timeString(entry.snapshot.remainingSeconds))
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(entry.snapshot.segmentTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Start a talk in the app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.09, blue: 0.12)
        }
    }

    private func timeString(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", m, s)
    }
}
