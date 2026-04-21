import SwiftUI

/// Always-visible summary when a talk is active but the full-screen timer is dismissed.
struct MiniTimerBar: View {
    let presetName: String
    let remainingLabel: String
    let segmentLabel: String
    let ringPhase: TaktTheme.SessionRingPhase
    let isPaused: Bool
    let isCompleted: Bool
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(TaktTheme.sessionRingGradient(for: ringPhase), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    Image(systemName: isCompleted ? "checkmark" : "waveform.path.ecg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TaktTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCompleted ? "Talk finished" : (isPaused ? "Paused" : "Live"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                    Text(presetName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !isCompleted {
                        HStack(spacing: 8) {
                            Text(remainingLabel)
                                .font(.title3.weight(.medium).monospacedDigit())
                            Text(segmentLabel)
                                .font(.caption2)
                                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                        }
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
                    .fill(TaktTheme.cardBackground(for: colorScheme))
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.12), radius: 20, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(TaktTheme.cardBorder(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Talk finished. Open to review." : "Live timer. Open full screen.")
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
            isCompleted: false,
            onOpen: {}
        )
        .padding()
    }
    .taktScreenBackground()
}

