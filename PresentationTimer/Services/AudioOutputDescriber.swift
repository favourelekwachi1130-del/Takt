import AVFoundation
import Foundation

/// Short label for where cue sounds are likely to play (not a guarantee of volume).
enum AudioOutputDescriber {
    static func currentOutputLabel() -> String {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        guard let out = route.outputs.first else {
            return "Sounds: Unknown"
        }
        let name = out.portName.isEmpty ? out.portType.rawValue : out.portName
        switch out.portType {
        case .builtInSpeaker:
            return "Sounds: Speaker"
        case .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return "Sounds: \(name)"
        case .airPlay:
            return "Sounds: AirPlay"
        default:
            return "Sounds: \(name)"
        }
    }
}
