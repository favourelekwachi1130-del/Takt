import ActivityKit
import SwiftUI
import UIKit

struct TaktSettingsView: View {
    @AppStorage("taktAppearance") private var appearanceRaw = "dark"
    @AppStorage(TaktUserSettings.accentPaletteKey) private var accentPaletteRaw = TaktAccentPalette.tangerine.rawValue
    @AppStorage(TaktUserSettings.displayNameKey) private var displayName = ""
    @AppStorage(TaktUserSettings.miniBarExtraBottomKey) private var miniBarExtraBottom = 12.0
    @AppStorage(TaktUserSettings.rehearsalModeKey) private var rehearsalMode = false
    @AppStorage(TaktUserSettings.startCountdownRitualKey) private var countdownBeforeStart = true

    @AppStorage(TaktUserSettings.hapticIntensityKey) private var hapticRaw = TaktUserSettings.HapticIntensity.medium.rawValue
    @AppStorage(TaktUserSettings.cueSoundsEnabledKey) private var cueSounds = false
    @AppStorage(TaktUserSettings.backgroundNotificationsEnabledKey) private var bgNotifications = true

    @AppStorage(TaktUserSettings.firstCueFractionKey) private var storedFirstCueFraction = 0.75
    @AppStorage(TaktUserSettings.secondCueFractionKey) private var storedSecondCueFraction = 0.9

    @Environment(\.colorScheme) private var colorScheme
    @State private var iCloudStatusLabel = "…"

    @available(iOS 16.2, *)
    private var liveActivityAuthorizationRow: some View {
        let ok = ActivityAuthorizationInfo().areActivitiesEnabled
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
                .imageScale(.large)
            VStack(alignment: .leading, spacing: 4) {
                Text(ok ? "Live Activities allowed for Takt" : "Live Activities are off")
                    .font(.subheadline.weight(.semibold))
                if !ok {
                    Text("Turn on: Settings → Takt → Live Activities (allow updates).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var hapticBinding: Binding<TaktUserSettings.HapticIntensity> {
        Binding(
            get: { TaktUserSettings.HapticIntensity(rawValue: hapticRaw) ?? .medium },
            set: { hapticRaw = $0.rawValue }
        )
    }

    private var firstCueBinding: Binding<Double> {
        Binding(
            get: { storedFirstCueFraction },
            set: { newVal in
                var f = TaktUserSettings.clampFirstCueFraction(newVal)
                let maxFirstAllowed = storedSecondCueFraction - TaktUserSettings.minimumCueGapFraction
                if f > maxFirstAllowed {
                    f = max(TaktUserSettings.cueTimingMinFraction, maxFirstAllowed)
                }
                storedFirstCueFraction = f
                let minSecond = f + TaktUserSettings.minimumCueGapFraction
                if storedSecondCueFraction < minSecond {
                    storedSecondCueFraction = min(TaktUserSettings.cueTimingMaxFraction, minSecond)
                }
            }
        )
    }

    private var accentPaletteBinding: Binding<TaktAccentPalette> {
        Binding(
            get: { TaktAccentPalette(rawValue: accentPaletteRaw) ?? .tangerine },
            set: { accentPaletteRaw = $0.rawValue }
        )
    }

    private var secondCueBinding: Binding<Double> {
        Binding(
            get: { storedSecondCueFraction },
            set: { newVal in
                var s = TaktUserSettings.clampSecondCueFraction(first: storedFirstCueFraction, proposed: newVal)
                let minSecond = storedFirstCueFraction + TaktUserSettings.minimumCueGapFraction
                if s < minSecond {
                    s = min(TaktUserSettings.cueTimingMaxFraction, minSecond)
                }
                storedSecondCueFraction = s
                let maxFirst = s - TaktUserSettings.minimumCueGapFraction
                if storedFirstCueFraction > maxFirst {
                    storedFirstCueFraction = max(TaktUserSettings.cueTimingMinFraction, maxFirst)
                }
            }
        )
    }

    private func cuePercentLabel(_ fraction: Double) -> String {
        "\(Int(round(fraction * 100)))% through each segment"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name for greetings", text: $displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)

                    Button("Clear name") {
                        displayName = ""
                    }
                    .foregroundStyle(.secondary)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Used on Home (“Good morning, …”) and nowhere else. Leave blank for a generic greeting.")
                }

                Section {
                    Toggle("Countdown before start", isOn: $countdownBeforeStart)
                        .tint(TaktTheme.accent)
                    Toggle("Rehearsal timing in recap", isOn: $rehearsalMode)
                        .tint(TaktTheme.accent)
                } header: {
                    Text("Timer session")
                } footer: {
                    Text("Countdown: 3-2-1 before the segment timer runs. Rehearsal: after a talk, the recap can show planned vs actual time per segment.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lift above tab bar")
                            .font(.subheadline)
                        Slider(value: $miniBarExtraBottom, in: 0...28, step: 2)
                            .tint(TaktTheme.accent)
                        Text("\(Int(miniBarExtraBottom)) pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Mini timer bar")
                } footer: {
                    Text(
                        "When you minimize a live talk, drag the bar along the top or bottom edge so it doesn’t cover your plans. Tap once to open the full-screen timer. Use Lift if the bottom edge still feels tight near the Home indicator or tabs."
                    )
                }

                Section {
                    LabeledContent("iCloud sync", value: iCloudStatusLabel)
                } footer: {
                    Text(
                        "Plans sync to your private iCloud database (CloudKit). Completed-talk counts stay on this device. Sign in to iCloud on your device for plan sync; Takt never creates its own account. Widgets and Live Activities use the App Group on this device only."
                    )
                }

                Section {
                    Picker("Accent color", selection: accentPaletteBinding) {
                        ForEach(TaktAccentPalette.allCases) { palette in
                            Text(palette.displayName).tag(palette)
                        }
                    }
                    .tint(TaktTheme.accent)

                    Picker("Appearance", selection: $appearanceRaw) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .tint(TaktTheme.accent)
                } header: {
                    Text("Look")
                } footer: {
                    Text("Accent updates tabs, buttons, timer rings, the home header mark, and—when supported—the Home Screen app icon. Dark is the default appearance—easy on the eyes before you go on stage.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("First cue")
                            .font(.subheadline.weight(.semibold))
                        Slider(
                            value: firstCueBinding,
                            in: TaktUserSettings.cueTimingMinFraction ... TaktUserSettings.cueTimingMaxFraction,
                            step: 0.01
                        )
                        .tint(TaktTheme.accent)
                        Text(cuePercentLabel(storedFirstCueFraction))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Second cue")
                            .font(.subheadline.weight(.semibold))
                        Slider(
                            value: secondCueBinding,
                            in: TaktUserSettings.cueTimingMinFraction ... TaktUserSettings.cueTimingMaxFraction,
                            step: 0.01
                        )
                        .tint(TaktTheme.accent)
                        Text(cuePercentLabel(storedSecondCueFraction))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Cue timing")
                } footer: {
                    Text(
                        "Both cues use the same allowed range (10%–95% of each segment). The second cue must come after the first. These times apply to all plans."
                    )
                    .font(.footnote)
                }

                Section {
                    Picker("Haptic intensity", selection: hapticBinding) {
                        ForEach(TaktUserSettings.HapticIntensity.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .tint(TaktTheme.accent)

                    Button("Preview first cue") {
                        HapticsService.playFirstCue()
                    }
                    Button("Preview second cue") {
                        HapticsService.playSecondCue()
                    }
                    Button("Preview segment end") {
                        HapticsService.playSegmentEnd()
                    }
                } header: {
                    Text("Cues")
                } footer: {
                    Text("Haptics work best while Takt is open. Intensity follows your setting above.")
                }

                Section {
                    Toggle("Cue sounds", isOn: $cueSounds)
                        .tint(TaktTheme.accent)
                } footer: {
                    Text("Short taps when a cue fires. Respects your device volume and silent mode behavior.")
                }

                Section {
                    Toggle("Background notifications", isOn: $bgNotifications)
                        .tint(TaktTheme.accent)
                } footer: {
                    Text("When off, Takt will not schedule the next lock-screen alert while the timer runs in the background.")
                }

                Section {
                    Text(
                        "Focus and Do Not Disturb apply system-wide. Takt cannot override them or guarantee vibration when another app is in front."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }

                    Text(
                        "To improve alerts: Settings → Focus → choose your Focus → Apps → allow Takt. Also ensure Notifications are allowed for Takt under Settings → Notifications."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Focus & notifications")
                }

                if #available(iOS 16.2, *) {
                    Section {
                        liveActivityAuthorizationRow
                    } header: {
                        Text("Lock Screen & Dynamic Island")
                    } footer: {
                        Text("The timer uses a Live Activity. Dynamic Island appears on iPhone 14 Pro and newer; use an iPhone Pro simulator to preview it. Non‑Pro simulators have no Island.")
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TaktTheme.rootBackdrop(for: colorScheme))
            .navigationTitle("Settings")
            .task {
                iCloudStatusLabel = await TaktICloudPresetsSync.iCloudStatusLabel()
            }
        }
    }
}

#Preview {
    TaktSettingsView()
}
