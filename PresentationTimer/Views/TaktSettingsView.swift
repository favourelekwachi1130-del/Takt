import SwiftUI
import UIKit

struct TaktSettingsView: View {
    @AppStorage("taktAppearance") private var appearanceRaw = "dark"
    @AppStorage(TaktUserSettings.hapticIntensityKey) private var hapticRaw = TaktUserSettings.HapticIntensity.medium.rawValue
    @AppStorage(TaktUserSettings.cueSoundsEnabledKey) private var cueSounds = false
    @AppStorage(TaktUserSettings.backgroundNotificationsEnabledKey) private var bgNotifications = true

    @Environment(\.colorScheme) private var colorScheme

    private var hapticBinding: Binding<TaktUserSettings.HapticIntensity> {
        Binding(
            get: { TaktUserSettings.HapticIntensity(rawValue: hapticRaw) ?? .medium },
            set: { hapticRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                        Text("System").tag("system")
                    }
                    .tint(TaktTheme.accent)
                } header: {
                    Text("Look")
                } footer: {
                    Text("Dark is the default—easy on the eyes before you go on stage.")
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
            }
            .scrollContentBackground(.hidden)
            .background(TaktTheme.background(for: colorScheme))
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    TaktSettingsView()
}
