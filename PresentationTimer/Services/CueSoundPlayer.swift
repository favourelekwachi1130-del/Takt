import AudioToolbox
import Foundation

/// Short system sounds for pacing cues (optional). Silent mode affects device behavior per iOS rules.
enum CueSoundPlayer {
    /// Light tap — first pacing cue.
    private static let firstCueSound: SystemSoundID = 1104
    /// Slightly different tap — second pacing cue.
    private static let secondCueSound: SystemSoundID = 1105
    /// Short tone — segment boundary.
    private static let segmentEndSound: SystemSoundID = 1052
    /// Tri-tone — session complete.
    private static let completeSound: SystemSoundID = 1025

    static func playFirstCue() {
        guard TaktUserSettings.cueSoundsEnabled else { return }
        AudioServicesPlaySystemSound(firstCueSound)
    }

    static func playSecondCue() {
        guard TaktUserSettings.cueSoundsEnabled else { return }
        AudioServicesPlaySystemSound(secondCueSound)
    }

    static func playSegmentEnd() {
        guard TaktUserSettings.cueSoundsEnabled else { return }
        AudioServicesPlaySystemSound(segmentEndSound)
    }

    static func playSessionComplete() {
        guard TaktUserSettings.cueSoundsEnabled else { return }
        AudioServicesPlaySystemSound(completeSound)
    }
}
