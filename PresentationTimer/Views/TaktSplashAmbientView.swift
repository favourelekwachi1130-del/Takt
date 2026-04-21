import SwiftUI

/// Slow, layered color drift behind the launch wordmark — visible but never loud.
struct TaktSplashAmbientView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                staticBackdrop
            } else {
                animatedBackdrop
            }
        }
    }

    private var staticBackdrop: some View {
        ZStack {
            Color("TaktLaunchBackground").ignoresSafeArea()
            TaktTheme.accent.opacity(colorScheme == .dark ? 0.06 : 0.04)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
        }
    }

    private var animatedBackdrop: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                baseFill

                auroraBlob(
                    t: t,
                    speed: 0.31,
                    phase: 0.0,
                    diameter: 340,
                    colors: [TaktTheme.accent.opacity(colorScheme == .dark ? 0.14 : 0.09), .clear]
                )
                .offset(
                    x: sin(t * 0.27 + 0.8) * 56,
                    y: cos(t * 0.23 + 0.3) * 44
                )

                auroraBlob(
                    t: t,
                    speed: 0.24,
                    phase: 2.1,
                    diameter: 280,
                    colors: [
                        Color(red: 0.45, green: 0.35, blue: 0.92).opacity(colorScheme == .dark ? 0.07 : 0.045),
                        .clear
                    ]
                )
                .offset(
                    x: cos(t * 0.21 + 1.2) * 48,
                    y: sin(t * 0.29 + 0.5) * 52
                )

                auroraBlob(
                    t: t,
                    speed: 0.35,
                    phase: 4.0,
                    diameter: 220,
                    colors: [
                        TaktTheme.accentSecondary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                        .clear
                    ]
                )
                .offset(
                    x: sin(t * 0.19) * 36,
                    y: cos(t * 0.25 + 2.0) * 38
                )

                RadialGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06)
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: 520
                )
                .allowsHitTesting(false)
            }
            .drawingGroup(opaque: false)
        }
    }

    private var baseFill: some View {
        ZStack {
            Color("TaktLaunchBackground")
            TaktTheme.accent.opacity(colorScheme == .dark ? 0.045 : 0.028)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }

    private func auroraBlob(
        t: TimeInterval,
        speed: Double,
        phase: Double,
        diameter: CGFloat,
        colors: [Color]
    ) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: colors,
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: 52 + CGFloat(sin(t * speed + phase)) * 6)
            .blendMode(.plusLighter)
    }
}

#Preview {
    TaktSplashAmbientView()
}
