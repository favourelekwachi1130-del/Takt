import UIKit

/// Keeps the Home Screen icon aligned with **Accent color** (alternate icons in the asset catalog).
enum TaktAppIconSync {
    static func applyCurrentPalette() {
        apply(TaktAccentPalette.resolved())
    }

    static func apply(_ palette: TaktAccentPalette) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = palette.alternateAppIconName
        guard UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name) { error in
            #if DEBUG
            if let error {
                print("Alternate app icon: \(error.localizedDescription)")
            }
            #endif
        }
    }
}
