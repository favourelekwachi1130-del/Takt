import UIKit

/// Foreground haptic feedback for timer cues. Uses short patterns (iOS does not allow arbitrary long motor runs).
enum HapticsService {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    private static func impact(for intensity: TaktUserSettings.HapticIntensity) -> UIImpactFeedbackGenerator {
        switch intensity {
        case .light: return lightImpact
        case .medium: return mediumImpact
        case .strong: return heavyImpact
        }
    }

    private static func pulseIntensity(for user: TaktUserSettings.HapticIntensity) -> CGFloat {
        switch user {
        case .light: return 0.55
        case .medium: return 1.0
        case .strong: return 1.0
        }
    }

    /// Single tap for the pre-start 3–2–1 countdown.
    static func countdownBeat() {
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.78)
    }

    /// Double pulse for first pacing cue (configurable segment fraction).
    static func playFirstCue(intensity user: TaktUserSettings.HapticIntensity = TaktUserSettings.hapticIntensity) {
        let gen = impact(for: user)
        let p = pulseIntensity(for: user)
        gen.prepare()
        gen.impactOccurred(intensity: p)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            gen.impactOccurred(intensity: p)
        }
    }

    /// Triple light taps — second pacing cue (between first cue and segment end).
    static func playSecondCue(intensity user: TaktUserSettings.HapticIntensity = TaktUserSettings.hapticIntensity) {
        let gen = impact(for: user)
        let p = min(1, pulseIntensity(for: user) * 0.92)
        gen.prepare()
        gen.impactOccurred(intensity: p)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            gen.impactOccurred(intensity: p * 0.95)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            gen.impactOccurred(intensity: p * 0.9)
        }
    }

    /// Stronger end cue for segment boundary.
    static func playSegmentEnd(intensity user: TaktUserSettings.HapticIntensity = TaktUserSettings.hapticIntensity) {
        switch user {
        case .light:
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                lightImpact.impactOccurred(intensity: 0.65)
            }
        case .medium:
            notification.prepare()
            notification.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                mediumImpact.prepare()
                mediumImpact.impactOccurred(intensity: 0.9)
            }
        case .strong:
            notification.prepare()
            notification.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                heavyImpact.prepare()
                heavyImpact.impactOccurred(intensity: 1.0)
            }
        }
    }

    /// Session finished.
    static func playSessionComplete(intensity user: TaktUserSettings.HapticIntensity = TaktUserSettings.hapticIntensity) {
        notification.prepare()
        notification.notificationOccurred(.success)
        if user == .strong {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                heavyImpact.prepare()
                heavyImpact.impactOccurred(intensity: 0.85)
            }
        }
    }
}

