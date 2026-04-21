import SwiftUI

/// Dashboard: fitness-style stat tiles + quick actions. Primary entry for Takt.
struct TaktHomeView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine
    @EnvironmentObject private var sessionStats: SessionStats
    @Environment(\.taktLaunchPresentation) private var launchPresentation
    @Environment(\.taktOpenTimerFullScreen) private var openTimerFullScreen
    @Environment(\.taktSelectTab) private var selectTab
    @Environment(\.taktHasActiveSession) private var hasActiveSession
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("taktAppearance") private var appearanceRaw = "dark"
    @AppStorage(TaktUserSettings.displayNameKey) private var displayName = ""

    @State private var path = NavigationPath()
    @State private var statSheet: StatInfoSheet?

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
                    TaktHeroBanner(displayName: displayName)

                    LazyVGrid(columns: Self.grid, spacing: 12) {
                        statTile(
                            title: "Completed",
                            value: "\(sessionStats.completedPresentations)",
                            caption: "talks",
                            icon: "checkmark.circle.fill",
                            tint: TaktTheme.accent,
                            elevation: .high
                        ) {
                            statSheet = .completed
                        }
                        statTile(
                            title: "Ongoing",
                            value: ongoingValue,
                            caption: ongoingCaption,
                            icon: "dot.radiowaves.left.and.right",
                            tint: TaktTheme.accentSecondary,
                            elevation: .mid
                        ) {
                            if hasActiveSession {
                                openTimerFullScreen?()
                            } else {
                                statSheet = .ongoing
                            }
                        }
                        statTile(
                            title: "Plans",
                            value: "\(presetStore.presets.count)",
                            caption: "saved",
                            icon: "square.stack.3d.up.fill",
                            tint: TaktTheme.iconNeutral(for: colorScheme),
                            elevation: .low
                        ) {
                            selectTab?(1)
                        }
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        TaktGlyphLogoView(accent: TaktTheme.accent)
                        Text("Takt")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .tracking(-0.55)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Takt, home")
                }
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
            .sheet(item: $statSheet) { sheet in
                statInfoSheetContent(sheet)
            }
        }
    }

    private func statInfoSheetContent(_ sheet: StatInfoSheet) -> some View {
        NavigationStack {
            ScrollView {
                Text(sheet.bodyCopy)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .taktScreenBackground()
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { statSheet = nil }
                }
            }
        }
    }

    private func statTile(
        title: String,
        value: String,
        caption: String,
        icon: String,
        tint: Color,
        elevation: TaktCardElevation,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .taktCardStyle(elevation: elevation)
    }
}

private enum StatInfoSheet: String, Identifiable {
    case completed
    case ongoing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .completed: return "Completed"
        case .ongoing: return "Ongoing"
        }
    }

    var bodyCopy: String {
        switch self {
        case .completed:
            return "This count goes up each time you finish a talk and tap Done on the session recap. It’s a simple tally of completed rehearsals or live runs—nothing is sent off-device."
        case .ongoing:
            return "When a timer is running (live, paused, or finished but not yet closed), this tile shows status and the mini bar appears above the tab bar. If you see “No active talk,” start a plan from Quick start or the Plans tab."
        }
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
                    .fill(TaktTheme.primaryFill)
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(TaktTheme.accent.opacity(0.45), lineWidth: 1.5)
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
