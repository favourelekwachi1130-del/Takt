import SwiftUI

/// Floats the mini timer in a **top** or **bottom** band so it never covers the middle of the tab content
/// or the **tab bar** (Home / Plans / Settings).
struct DraggableFloatingMiniBar: View {
    let presetName: String
    let remainingLabel: String
    let segmentLabel: String
    let ringPhase: TaktTheme.SessionRingPhase
    let isPaused: Bool
    let isCompleted: Bool
    var isIdleEngine: Bool = false
    let extraBottomLift: CGFloat
    let onOpen: () -> Void

    @AppStorage(TaktUserSettings.miniBarBandKey) private var bandRaw = "bottom"
    @AppStorage(TaktUserSettings.miniBarNormXKey) private var normX = 0.5
    @AppStorage(TaktUserSettings.miniBarNormYKey) private var normY = 0.35

    @State private var dragTranslation: CGSize = .zero
    @State private var barSize: CGSize = CGSize(width: 320, height: 72)

    private let marginH: CGFloat = 16
    private let tapMaxDistance: CGFloat = 14
    private let approxBarHeight: CGFloat = 72
    /// Standard `UITabBar` height on iPhone; keeps the mini bar’s frame above the Home / Plans / Settings row.
    private let tabBarHeight: CGFloat = 49
    /// Minimum gap between the mini bar’s bottom edge and the top of the tab bar.
    private let clearanceAboveTabBar: CGFloat = 20
    /// Extra height allowance for shadow / rounding so clamping is conservative.
    private let barVerticalSlop: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let safe = geo.safeAreaInsets
            let metrics = layoutMetrics(width: w, height: h, safe: safe)
            let settled = settledCenter(metrics: metrics, width: w, height: h, safe: safe)
            let raw = CGPoint(x: settled.x + dragTranslation.width, y: settled.y + dragTranslation.height)
            let barW = min(w - marginH * 2, max(200, barSize.width))
            let effectiveBarH = max(barSize.height, approxBarHeight) + barVerticalSlop
            let live = clampCenter(raw, metrics: metrics, barW: barW, barH: effectiveBarH, width: w)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)

                MiniTimerBar(
                    presetName: presetName,
                    remainingLabel: remainingLabel,
                    segmentLabel: segmentLabel,
                    ringPhase: ringPhase,
                    isPaused: isPaused,
                    isCompleted: isCompleted,
                    isIdleEngine: isIdleEngine
                )
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: MiniBarSizePreference.self, value: g.size)
                    }
                )
                .onPreferenceChange(MiniBarSizePreference.self) { barSize = $0 }
                .frame(width: barW, alignment: .center)
                .position(x: live.x, y: live.y)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            dragTranslation = value.translation
                        }
                        .onEnded { value in
                            let dist = hypot(value.translation.width, value.translation.height)
                            if dist < tapMaxDistance {
                                onOpen()
                            } else {
                                commitDrag(
                                    settledCenter: settled,
                                    metrics: metrics,
                                    width: w,
                                    height: h,
                                    safe: safe,
                                    effectiveBarH: effectiveBarH
                                )
                            }
                            dragTranslation = .zero
                        }
                )
                .allowsHitTesting(true)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default) { onOpen() }
            }
        }
        .ignoresSafeArea()
    }

    private var accessibilityLabel: String {
        if isCompleted { return "Talk finished. Open to review." }
        return "Live timer. Drag along the top or bottom; it stays above the tab bar. Tap to open full screen."
    }

    private func layoutMetrics(width w: CGFloat, height h: CGFloat, safe: EdgeInsets) -> MiniBarBandMetrics {
        let lift = extraBottomLift
        let barH = max(barSize.height, approxBarHeight) + barVerticalSlop

        // Top edge of the system tab bar (Home, Plans, Settings).
        let tabBarTopY = h - safe.bottom - tabBarHeight
        // Lowest allowed center Y: mini bar bottom sits at tabBarTopY - clearance - lift.
        let bottomCenterMax = tabBarTopY - clearanceAboveTabBar - barH / 2 - lift
        let bottomCenterMin = bottomCenterMax - 88
        let bottomBand = (minY: min(bottomCenterMin, bottomCenterMax), maxY: max(bottomCenterMin, bottomCenterMax))

        let topInnerY = safe.top + 12 + barH / 2
        let topOuterY = safe.top + 100 + barH / 2
        let topBand = (minY: min(topInnerY, topOuterY), maxY: max(topInnerY, topOuterY))

        return MiniBarBandMetrics(bottomBand: bottomBand, topBand: topBand, marginH: marginH)
    }

    private func settledCenter(metrics: MiniBarBandMetrics, width w: CGFloat, height h: CGFloat, safe: EdgeInsets) -> CGPoint {
        let range = bandRaw == "top" ? metrics.topBand : metrics.bottomBand
        let x = metrics.marginH + CGFloat(normX) * (w - 2 * metrics.marginH)
        let y = range.minY + CGFloat(normY) * (range.maxY - range.minY)
        let barW = min(w - marginH * 2, max(200, barSize.width))
        let effectiveBarH = max(barSize.height, approxBarHeight) + barVerticalSlop
        return clampCenter(CGPoint(x: x, y: y), metrics: metrics, barW: barW, barH: effectiveBarH, width: w)
    }

    /// Keeps the bar in the top or bottom strip only; never over the tab bar or the middle of the screen.
    private func clampCenter(_ p: CGPoint, metrics: MiniBarBandMetrics, barW: CGFloat, barH: CGFloat, width w: CGFloat) -> CGPoint {
        let halfW = barW / 2
        let x = min(max(p.x, metrics.marginH + halfW), w - metrics.marginH - halfW)
        var y = p.y

        let t = metrics.topBand
        let b = metrics.bottomBand

        if y <= t.maxY {
            y = min(max(y, t.minY), t.maxY)
        } else if y >= b.minY {
            y = min(max(y, b.minY), b.maxY)
        } else {
            let mid = (t.maxY + b.minY) / 2
            y = y < mid ? t.maxY : b.minY
        }
        return CGPoint(x: x, y: y)
    }

    private func commitDrag(
        settledCenter: CGPoint,
        metrics: MiniBarBandMetrics,
        width w: CGFloat,
        height h: CGFloat,
        safe: EdgeInsets,
        effectiveBarH: CGFloat
    ) {
        let endRaw = CGPoint(x: settledCenter.x + dragTranslation.width, y: settledCenter.y + dragTranslation.height)
        let end = clampCenter(endRaw, metrics: metrics, barW: min(w - marginH * 2, max(200, barSize.width)), barH: effectiveBarH, width: w)

        let mid = (metrics.topBand.maxY + metrics.bottomBand.minY) / 2
        let newIsTop = end.y < mid
        bandRaw = newIsTop ? "top" : "bottom"

        let range = newIsTop ? metrics.topBand : metrics.bottomBand
        let halfW = barSize.width / 2
        let clampedX = min(max(end.x, metrics.marginH + halfW), w - metrics.marginH - halfW)
        let clampedY = min(max(end.y, range.minY), range.maxY)

        normX = Double((clampedX - metrics.marginH) / max(1, w - 2 * metrics.marginH))
        normX = min(1, max(0, normX))

        let ny = Double((clampedY - range.minY) / max(1, range.maxY - range.minY))
        normY = min(1, max(0, ny))
    }
}

private struct MiniBarBandMetrics {
    let bottomBand: (minY: CGFloat, maxY: CGFloat)
    let topBand: (minY: CGFloat, maxY: CGFloat)
    let marginH: CGFloat
}

private struct MiniBarSizePreference: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 320, height: 72)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
