import SwiftUI
import UIKit

/// Built-in **Gantt-style** presentation timeline (segment bars on a shared time axis) plus PNG / Markdown export.
struct PresetGanttTimelineView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @Environment(\.colorScheme) private var colorScheme

    let preset: Preset

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Each row is one segment; bar length matches its share of the total planned time.")
                    .font(.subheadline)
                    .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))

                PresetGanttChartBlock(preset: preset, style: .editor(colorScheme))
                    .taktCardStyle(elevation: .mid)

                if preset.segments.isEmpty {
                    ContentUnavailableView(
                        "No segments",
                        systemImage: "rectangle.stack",
                        description: Text("Add slides in the editor to see a timeline.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .padding(20)
        }
        .taktScreenBackground()
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let png = PresetGanttImageExport.makePNGFileURL(for: preset) {
                    ShareLink(
                        item: TaktSharedPNGFile(url: png),
                        subject: Text("\(preset.name) — timeline"),
                        message: Text("Gantt timeline image exported from Takt."),
                        preview: SharePreview("\(preset.name)-timeline.png", image: Image(systemName: "photo"))
                    ) {
                        Label("Image", systemImage: "square.and.arrow.up")
                    }
                }
                if let md = try? presetStore.exportMermaidGanttFileURL(for: preset) {
                    ShareLink(
                        item: TaktSharedMarkdownFile(url: md),
                        subject: Text("\(preset.name) — Mermaid"),
                        message: Text("Markdown with a fenced Mermaid gantt block."),
                        preview: SharePreview("\(preset.name)-timeline.md", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Markdown", systemImage: "doc.text")
                    }
                }
            }
        }
    }
}

// MARK: - Chart

private struct PresetGanttChartBlock: View {
    let preset: Preset
    let style: GanttChartStyle
    /// When set (e.g. PNG export), skips `GeometryReader` so `ImageRenderer` gets a deterministic layout.
    var layoutWidth: CGFloat?

    private let labelColumnWidth: CGFloat = 118
    private let durationColumnWidth: CGFloat = 44
    private let rowHeight: CGFloat = 44
    private let axisHeight: CGFloat = 28

    private var rows: [(title: String, start: TimeInterval, duration: TimeInterval)] {
        var start: TimeInterval = 0
        var out: [(String, TimeInterval, TimeInterval)] = []
        for (idx, seg) in preset.segments.enumerated() {
            let d = max(1, seg.durationSeconds.rounded())
            let t = seg.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = t.isEmpty ? "Slide \(idx + 1)" : t
            out.append((title, start, d))
            start += d
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(preset.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(style.titleColor)
                .lineLimit(2)

            Text("Total \(totalDuration > 0 ? formatDuration(totalDuration) : "0:00") · \(preset.segments.count) segment(s)")
                .font(.caption.weight(.medium))
                .foregroundStyle(style.subtitleColor)

            if !rows.isEmpty {
                chartSection
            }
        }
        .padding(style.isExportCard ? 0 : 16)
    }

    @ViewBuilder
    private var chartSection: some View {
        if let fixed = layoutWidth {
            chartSectionContent(totalWidth: fixed)
                .frame(minHeight: axisHeight + CGFloat(rows.count) * rowHeight)
        } else {
            GeometryReader { geo in
                chartSectionContent(totalWidth: geo.size.width)
            }
            .frame(minHeight: axisHeight + CGFloat(rows.count) * rowHeight)
        }
    }

    @ViewBuilder
    private func chartSectionContent(totalWidth: CGFloat) -> some View {
        let chartWidth = max(1, totalWidth - labelColumnWidth - 8 - durationColumnWidth)
        VStack(alignment: .leading, spacing: 0) {
            timeAxis(width: chartWidth)
                .frame(height: axisHeight)
                .padding(.leading, labelColumnWidth + 8)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ganttRow(
                    index: index,
                    title: row.title,
                    start: row.start,
                    duration: row.duration,
                    chartWidth: chartWidth
                )
            }
        }
    }

    private var totalDuration: TimeInterval {
        rows.map(\.duration).reduce(0, +)
    }

    /// Avoid division by zero in layout.
    private var chartScale: TimeInterval {
        max(totalDuration, 1)
    }

    private func timeAxis(width: CGFloat) -> some View {
        let ticks = axisTickSeconds(total: chartScale)
        return ZStack(alignment: .leading) {
            ForEach(ticks, id: \.self) { sec in
                let x = width * CGFloat(sec / chartScale)
                VStack(alignment: .leading, spacing: 2) {
                    Rectangle()
                        .fill(style.gridColor)
                        .frame(width: 1, height: 6)
                    Text(formatAxisTime(sec))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(style.subtitleColor)
                        .offset(x: -8)
                }
                .offset(x: x)
            }
        }
        .frame(width: width, height: axisHeight, alignment: .topLeading)
    }

    private func axisTickSeconds(total: TimeInterval) -> [TimeInterval] {
        if total <= 0 { return [0] }
        let n = min(5, max(2, Int(total / 60) + 1))
        return (0 ... n).map { i in total * TimeInterval(i) / TimeInterval(n) }
    }

    private func ganttRow(
        index: Int,
        title: String,
        start: TimeInterval,
        duration: TimeInterval,
        chartWidth: CGFloat
    ) -> some View {
        let startFrac = CGFloat(start / chartScale)
        let widthFrac = CGFloat(duration / chartScale)
        let barW = max(4, chartWidth * widthFrac)

        return HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.titleColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: labelColumnWidth, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(style.trackColor)
                    .frame(height: rowHeight - 12)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(style.barColor(at: index))
                    .frame(width: barW, height: rowHeight - 12)
                    .offset(x: chartWidth * startFrac)
            }
            .frame(width: chartWidth, height: rowHeight - 8)

            Text(formatDuration(duration))
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(style.subtitleColor)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let sec = Int(s.rounded())
        let m = sec / 60
        let r = sec % 60
        return String(format: "%d:%02d", m, r)
    }

    private func formatAxisTime(_ sec: TimeInterval) -> String {
        let s = Int(sec.rounded())
        let m = s / 60
        let r = s % 60
        if m >= 60 {
            let h = m / 60
            let mm = m % 60
            return String(format: "%d:%02d:%02d", h, mm, r)
        }
        return String(format: "%d:%02d", m, r)
    }
}

private enum GanttChartStyle {
    case editor(ColorScheme)
    case exportHero

    fileprivate var isExportCard: Bool {
        if case .exportHero = self { return true }
        return false
    }

    var titleColor: Color {
        switch self {
        case .editor(let scheme):
            return scheme == .dark ? .white : .primary
        case .exportHero:
            return .white
        }
    }

    var subtitleColor: Color {
        switch self {
        case .editor(let scheme):
            return TaktTheme.secondaryLabel(for: scheme)
        case .exportHero:
            return .white.opacity(0.75)
        }
    }

    var trackColor: Color {
        switch self {
        case .editor(let scheme):
            return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        case .exportHero:
            return .white.opacity(0.15)
        }
    }

    var gridColor: Color {
        switch self {
        case .editor(let scheme):
            return scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)
        case .exportHero:
            return .white.opacity(0.35)
        }
    }

    func barColor(at index: Int) -> Color {
        switch self {
        case .editor:
            let palette: [Color] = [
                TaktTheme.accent,
                TaktTheme.accentSecondary,
                TaktTheme.accent.opacity(0.72),
                TaktTheme.accentSecondary.opacity(0.88)
            ]
            return palette[index % palette.count]
        case .exportHero:
            let palette: [Color] = [
                .white.opacity(0.95),
                TaktTheme.accent.opacity(0.98),
                .white.opacity(0.78),
                TaktTheme.accentSecondary.opacity(0.95)
            ]
            return palette[index % palette.count]
        }
    }
}

// MARK: - PNG export (share card)

private struct PresetGanttShareCard: View {
    let preset: Preset

    private var cardHeight: CGFloat {
        let n = max(1, preset.segments.count)
        return min(980, 160 + 44 * CGFloat(n) + 80)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(TaktTheme.primaryFill)
                Spacer()
                Text("Takt")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.65))
            }

            PresetGanttChartBlock(preset: preset, style: .exportHero, layoutWidth: 312)
        }
        .padding(24)
        .frame(width: 360, height: cardHeight, alignment: .topLeading)
        .background(TaktTheme.heroShareCardFill)
    }
}

enum PresetGanttImageExport {
    /// Renders the built-in Gantt card to a **PNG** in **temporaryDirectory** for the share sheet (Save to Files, etc.).
    @MainActor
    static func makePNGFileURL(for preset: Preset) -> URL? {
        guard !preset.segments.isEmpty else { return nil }
        let card = PresetGanttShareCard(preset: preset)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }
        let base = sanitizeFilename(preset.name)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(base)-timeline.png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func sanitizeFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/:<>\"\\|?*\u{0000}")
        var s = trimmed.components(separatedBy: invalid).joined(separator: "-")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        if s.isEmpty { return "Presentation" }
        return String(s.prefix(80))
    }
}

#Preview("Editor") {
    NavigationStack {
        PresetGanttTimelineView(preset: .sample)
    }
    .environmentObject(PresetStore())
}

#Preview("Empty") {
    NavigationStack {
        PresetGanttTimelineView(preset: .empty)
    }
    .environmentObject(PresetStore())
}
