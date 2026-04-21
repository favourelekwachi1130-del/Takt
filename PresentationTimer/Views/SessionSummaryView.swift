import SwiftUI
import UIKit

/// One row for rehearsal mode: planned vs actual wall time in a segment.
struct SessionRehearsalRow: Identifiable, Hashable {
    let index: Int
    let title: String
    let plannedSeconds: TimeInterval
    let actualSeconds: TimeInterval

    var id: Int { index }

    static func build(segments: [Segment], actuals: [TimeInterval]) -> [SessionRehearsalRow] {
        actuals.indices.compactMap { i in
            guard segments.indices.contains(i) else { return nil }
            let s = segments[i]
            return SessionRehearsalRow(
                index: i,
                title: s.title,
                plannedSeconds: s.durationSeconds,
                actualSeconds: actuals[i]
            )
        }
    }

    var deltaSeconds: TimeInterval {
        actualSeconds - plannedSeconds
    }
}

/// Post-session recap shown after a completed talk (fitness-style closure).
struct SessionSummaryView: View {
    let presetName: String
    let segmentCount: Int
    let wallSeconds: TimeInterval?
    let plannedTotalSeconds: TimeInterval
    var rehearsalRows: [SessionRehearsalRow]?
    var onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Session recap")
                        .font(.title2.weight(.bold))

                    VStack(alignment: .leading, spacing: 8) {
                        summaryRow(title: "Talk", value: presetName)
                        summaryRow(title: "Segments", value: "\(segmentCount)")
                        summaryRow(title: "Planned total", value: formatDuration(plannedTotalSeconds))
                        if let w = wallSeconds {
                            summaryRow(title: "Session time", value: formatDuration(w))
                        }
                    }
                    .taktCardStyle()

                    if let rows = rehearsalRows, !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rehearsal timing")
                                .font(.headline)
                            Text("Actual time spent in each segment (includes any overrun before the next cue).")
                                .font(.caption)
                                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))

                            ForEach(rows) { row in
                                HStack(alignment: .firstTextBaseline) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text("Planned \(formatDuration(row.plannedSeconds))")
                                            .font(.caption)
                                            .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(formatDuration(row.actualSeconds))
                                            .font(.subheadline.weight(.semibold))
                                        Text(deltaLabel(row.deltaSeconds))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(deltaColor(row.deltaSeconds))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .taktCardStyle()
                    }

                    shareSection

                    Text("Takt cannot bypass Focus or Do Not Disturb. For alerts when the app is in the background, allow Takt in Settings → Focus → Apps, and keep notifications on.")
                        .font(.footnote)
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))

                    Button {
                        onDone()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(TaktSummaryDoneStyle())
                }
                .padding(20)
            }
            .taktScreenBackground()
            .navigationTitle("Nice work")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var shareSection: some View {
        if let url = recapImageURL() {
            ShareLink(
                item: url,
                subject: Text("Takt session — \(presetName)"),
                message: Text("Session recap from Takt."),
                preview: SharePreview("Takt recap", image: Image(systemName: "photo.on.rectangle.angled"))
            ) {
                Label("Share recap image", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(TaktTheme.accent)
        }
    }

    private func recapImageURL() -> URL? {
        let card = RecapShareCard(
            presetName: presetName,
            plannedTotal: formatDuration(plannedTotalSeconds),
            sessionTime: wallSeconds.map { formatDuration($0) } ?? "—",
            segmentCount: segmentCount,
            rehearsalRows: rehearsalRows ?? []
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("takt-recap-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let r = Int(s) % 60
        return String(format: "%d:%02d", m, r)
    }

    private func deltaLabel(_ d: TimeInterval) -> String {
        let sign = d >= 0 ? "+" : "-"
        let absSec = abs(Int(d.rounded()))
        let m = absSec / 60
        let sec = absSec % 60
        if m > 0 {
            return "\(sign)\(m)m \(sec)s vs plan"
        }
        return "\(sign)\(sec)s vs plan"
    }

    private func deltaColor(_ d: TimeInterval) -> Color {
        if abs(d) < 2 { return TaktTheme.secondaryLabel(for: colorScheme) }
        return d > 0 ? Color.orange : Color.green
    }
}

private struct RecapShareCard: View {
    let presetName: String
    let plannedTotal: String
    let sessionTime: String
    let segmentCount: Int
    let rehearsalRows: [SessionRehearsalRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "timer")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TaktTheme.ringGradient)
                Spacer()
                Text("Takt")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
            }

            Text(presetName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                row("Planned total", plannedTotal)
                row("Session time", sessionTime)
                row("Segments", "\(segmentCount)")
            }
            .font(.subheadline)

            if !rehearsalRows.isEmpty {
                Divider()
                Text("Rehearsal timing")
                    .font(.headline)
                ForEach(Array(rehearsalRows.prefix(6))) { r in
                    HStack {
                        Text(r.title)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%d:%02d", Int(r.actualSeconds) / 60, Int(r.actualSeconds) % 60))
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                    .font(.caption)
                }
                if rehearsalRows.count > 6 {
                    Text("+\(rehearsalRows.count - 6) more…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 360, height: 420, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.06, green: 0.07, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .foregroundStyle(.secondary)
            Spacer()
            Text(v)
                .fontWeight(.semibold)
        }
    }
}

private struct TaktSummaryDoneStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TaktTheme.ringGradient)
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
    }
}

#Preview {
    SessionSummaryView(
        presetName: "Keynote",
        segmentCount: 5,
        wallSeconds: 1834,
        plannedTotalSeconds: 1800,
        rehearsalRows: [
            SessionRehearsalRow(index: 0, title: "Intro", plannedSeconds: 120, actualSeconds: 118),
            SessionRehearsalRow(index: 1, title: "Body", plannedSeconds: 300, actualSeconds: 312)
        ],
        onDone: {}
    )
}

