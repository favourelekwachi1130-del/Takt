import Foundation

/// Builds a Markdown file with a **Mermaid Gantt** diagram of segment timing (presentation timeline).
enum TaktPresetMermaid {
    /// Full document: title + fenced `gantt` block (renders in GitHub, Obsidian, many editors).
    static func ganttMarkdownDocument(for preset: Preset) -> String {
        var lines: [String] = []
        lines.append("# \(escapeMarkdownHeading(preset.name))")
        lines.append("")
        lines.append("Timing breakdown for **\(escapeMarkdownInline(preset.name))** — \(preset.segments.count) segment(s).")
        lines.append("")
        lines.append("```mermaid")
        lines.append(contentsOf: ganttLines(for: preset))
        lines.append("```")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Raw `gantt` block lines (no fence), for tests or embedding.
    static func ganttLines(for preset: Preset) -> [String] {
        var out: [String] = []
        out.append("gantt")
        out.append("    title \(escapeGanttTitle(preset.name))")
        out.append("    dateFormat HH:mm:ss")
        out.append("    axisFormat %H:%M:%S")
        out.append("    section Segments")

        guard !preset.segments.isEmpty else {
            out.append("    No segments :placeholder, 00:00:00, 1s")
            out.append("    %% Add slides in Takt to build a timeline.")
            return out
        }

        var cumulative: TimeInterval = 0
        for (index, seg) in preset.segments.enumerated() {
            let sec = max(1, Int(seg.durationSeconds.rounded()))
            let label = escapeGanttTaskLabel(seg.title, fallback: "Slide \(index + 1)")
            let id = "s\(index)"

            if index == 0 {
                let start = formatClock(cumulative)
                out.append("    \(label) :\(id), \(start), \(sec)s")
            } else {
                let prev = "s\(index - 1)"
                out.append("    \(label) :\(id), after \(prev), \(sec)s")
            }

            cumulative += TimeInterval(sec)

            if !seg.speakerNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let note = seg.speakerNote
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                out.append("    %% \(note)")
            }
        }

        let totalSec = Int(cumulative.rounded())
        out.append("    %% Total: \(formatHumanDuration(totalSec))")
        return out
    }

    private static func formatClock(_ secondsFromMidnight: TimeInterval) -> String {
        let s = Int(secondsFromMidnight.rounded()) % 86_400
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return String(format: "%02d:%02d:%02d", h, m, sec)
    }

    private static func formatHumanDuration(_ totalSec: Int) -> String {
        if totalSec < 60 { return "\(totalSec)s" }
        let m = totalSec / 60
        let s = totalSec % 60
        if s == 0 { return "\(m)m" }
        return "\(m)m \(s)s"
    }

    private static func escapeGanttTitle(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Presentation" }
        return t.replacingOccurrences(of: "\"", with: "'")
    }

    private static func escapeGanttTaskLabel(_ raw: String, fallback: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let useText = t.isEmpty ? fallback : t
        let escaped = useText.replacingOccurrences(of: "\"", with: "'")
        return "\"\(escaped)\""
    }

    private static func escapeMarkdownHeading(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Presentation" : raw
    }

    private static func escapeMarkdownInline(_ raw: String) -> String {
        raw.replacingOccurrences(of: "*", with: "\\*")
    }
}
