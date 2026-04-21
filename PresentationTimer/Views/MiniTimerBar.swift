import SwiftUI

/// Always-visible summary when a talk is active but the full-screen timer is dismissed.
/// Interaction (tap / drag) is handled by ``DraggableFloatingMiniBar``.
struct MiniTimerBar: View {
    let presetName: String
    let remainingLabel: String
    let segmentLabel: String
    let ringPhase: TaktTheme.SessionRingPhase
    let isPaused: Bool
    let isCompleted: Bool
    /// Engine not running yet (e.g. countdown running in full screen only) — still show the bar after minimize.
    var isIdleEngine: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var statusTitle: String {
        if isCompleted { return "Talk finished" }
        if isPaused { return "Paused" }
        if isIdleEngine { return "Starting" }
        return "Live"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(TaktTheme.sessionRingColor(for: ringPhase), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Image(systemName: isCompleted ? "checkmark" : "waveform.path.ecg")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TaktTheme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                Text(presetName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !isCompleted && !isIdleEngine {
                    HStack(spacing: 8) {
                        Text(remainingLabel)
                            .font(.title3.weight(.medium).monospacedDigit())
                        Text(segmentLabel)
                            .font(.caption2)
                            .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                    }
                } else if isIdleEngine {
                    Text("Open to continue countdown")
                        .font(.caption)
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                } else {
                    Text("Tap to review or dismiss")
                        .font(.caption)
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.up")
                .font(.caption.weight(.bold))
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.16 : 0.5),
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(TaktTheme.cardBorder(for: colorScheme).opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.12), radius: 12, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    VStack {
        Spacer()
        MiniTimerBar(
            presetName: "Keynote",
            remainingLabel: "4:12",
            segmentLabel: "Segment 2 of 5",
            ringPhase: .steady,
            isPaused: false,
            isCompleted: false
        )
        .padding()
    }
    .taktScreenBackground()
}
