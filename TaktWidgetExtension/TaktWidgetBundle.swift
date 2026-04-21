import SwiftUI
import WidgetKit

@main
struct TaktWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaktTimerLockWidget()
        TaktTimerLiveActivityWidget()
    }
}
