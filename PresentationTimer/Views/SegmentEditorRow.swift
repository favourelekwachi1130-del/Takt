import SwiftUI

/// One segment: title field + collapsible **minutes / seconds** wheel timing (no hours).
struct SegmentEditorRow: View {
    @Binding var segment: Segment
    let isTimingExpanded: Bool
    let onToggleTiming: () -> Void

    private var minuteBinding: Binding<Int> {
        Binding(
            get: {
                let t = clampedSeconds
                return min(120, t / 60)
            },
            set: { m in
                let s = Int(segment.durationSeconds) % 60
                segment.durationSeconds = Self.clampTotal(m * 60 + s)
            }
        )
    }

    private var secondBinding: Binding<Int> {
        Binding(
            get: {
                let t = clampedSeconds
                return t % 60
            },
            set: { s in
                let m = Int(segment.durationSeconds) / 60
                segment.durationSeconds = Self.clampTotal(m * 60 + s)
            }
        )
    }

    private var clampedSeconds: Int {
        let raw = Int(segment.durationSeconds.rounded(.down))
        return min(7200, max(1, raw))
    }

    private static func clampTotal(_ x: Int) -> TimeInterval {
        TimeInterval(min(7200, max(1, x)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Slide title", text: $segment.title)
                .textInputAutocapitalization(.words)

            Button {
                onToggleTiming()
            } label: {
                HStack {
                    Text("Timer")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatMMSS(clampedSeconds))
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: isTimingExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Segment duration, \(formatMMSS(clampedSeconds))")
            .accessibilityHint(isTimingExpanded ? "Collapse timer" : "Expand to change minutes and seconds")

            if isTimingExpanded {
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 8) {
                        Picker("Minutes", selection: minuteBinding) {
                            ForEach(0 ... 120, id: \.self) { m in
                                Text("\(m)").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Text("min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        Picker("Seconds", selection: secondBinding) {
                            ForEach(0 ..< 60, id: \.self) { s in
                                Text(String(format: "%02d", s)).tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Text("sec")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .leading)
                    }
                    .frame(height: 148)

                    Button("Done") {
                        onToggleTiming()
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(TaktTheme.accent.opacity(0.15))
                    )
                    .foregroundStyle(TaktTheme.accent)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isTimingExpanded)
    }

    private func formatMMSS(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var seg = Segment(title: "Slide 1", durationSeconds: 195)
        @State private var open = true
        var body: some View {
            Form {
                Section {
                    SegmentEditorRow(segment: $seg, isTimingExpanded: open) {
                        open.toggle()
                    }
                }
            }
        }
    }
    return PreviewHost()
}
