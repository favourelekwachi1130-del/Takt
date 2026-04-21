import SwiftUI

/// Dashboard: fitness-style stat tiles + quick actions. Primary entry for Takt.
struct TaktHomeView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine
    @EnvironmentObject private var sessionStats: SessionStats
    @Environment(\.taktLaunchPresentation) private var launchPresentation
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("taktAppearance") private var appearanceRaw = "dark"

    @State private var path = NavigationPath()

    private static let grid = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var ongoingValue: String {
        switch timerEngine.runState {
        case .running:
            return "Live"
        case .paused:
            return "Paused"
        case .completed:
            return "Done"
        case .idle:
            return "—"
        }
    }

    private var ongoingCaption: String {
        switch timerEngine.runState {
        case .running, .paused:
            return timerEngine.currentSegment?.title ?? "In progress"
        case .completed:
            return "Finish on timer"
        case .idle:
            return timerEngine.segments.isEmpty ? "No active talk" : "Ready"
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    LazyVGrid(columns: Self.grid, spacing: 12) {
                        statTile(
                            title: "Completed",
                            value: "\(sessionStats.completedPresentations)",
                            caption: "talks",
                            icon: "checkmark.circle.fill",
                            tint: TaktTheme.accent
                        )
                        statTile(
                            title: "Ongoing",
                            value: ongoingValue,
                            caption: ongoingCaption,
                            icon: "dot.radiowaves.left.and.right",
                            tint: Color.orange
                        )
                        statTile(
                            title: "Plans",
                            value: "\(presetStore.presets.count)",
                            caption: "saved",
                            icon: "square.stack.3d.up.fill",
                            tint: Color.purple
                        )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick start")
                            .font(.title3.weight(.bold))
                        Button {
                            let p = Preset(name: "New talk", segments: [Segment(title: "Opening", durationSeconds: 180)])
                            presetStore.upsert(p)
                            path.append(p.id)
                        } label: {
                            Label("New presentation", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(TaktPrimaryButtonStyle())

                        if let first = presetStore.presets.first {
                            Button {
                                launchPresentation?(first)
                            } label: {
                                Label("Start — \(first.name)", systemImage: "play.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(TaktSecondaryButtonStyle())
                        }
                    }
                }
                .padding(20)
            }
            .taktScreenBackground()
            .navigationTitle("Takt")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Appearance", selection: $appearanceRaw) {
                            Text("Dark").tag("dark")
                            Text("Light").tag("light")
                            Text("System").tag("system")
                        }
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Appearance")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let preset = presetStore.presets.first(where: { $0.id == id }) {
                    PresetEditorView(preset: preset)
                } else {
                    Text("Missing plan")
                }
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(TaktTheme.heroGradient)
                .frame(height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text("Stay on tempo.")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text("Pacing cues, segment by segment.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(20)
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5 ..< 12: return "Good morning"
        case 12 ..< 17: return "Good afternoon"
        case 17 ..< 22: return "Good evening"
        default: return "Hello"
        }
    }

    private func statTile(title: String, value: String, caption: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(TaktTheme.secondaryLabel(for: colorScheme))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .taktCardStyle()
    }
}

// MARK: - Buttons

private struct TaktPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TaktTheme.ringGradient)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}

private struct TaktSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(TaktTheme.accent)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TaktTheme.accent.opacity(0.45), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(TaktTheme.cardBackground(for: colorScheme).opacity(0.6))
                    )
            )
    }
}

#Preview {
    TaktHomeView()
        .environmentObject(PresetStore())
        .environmentObject(TimerEngine())
        .environmentObject(SessionStats())
}
