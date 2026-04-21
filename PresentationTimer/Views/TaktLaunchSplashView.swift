import SwiftUI
import UIKit

/// Launch overlay: ambient drift, soft wordmark, settling bar (loading gate), then handoff.
struct TaktLaunchSplashView: View {
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentVisible = false
    @State private var sessionStart = Date()

    /// How long the settling bar runs — also minimum time before dismiss (luxury pacing).
    private var settlingSeconds: Double { reduceMotion ? 0.42 : 1.34 }

    var body: some View {
        ZStack {
            TaktSplashAmbientView()

            VStack(spacing: 32) {
                wordmarkBlock
                    .opacity(contentVisible ? 1 : 0)
                    .offset(y: contentVisible ? 0 : 10)

                settlingBar
                    .opacity(contentVisible ? 1 : 0)
            }
            .padding(.horizontal, 36)
        }
        .onAppear {
            sessionStart = Date()
        }
        .task {
            await runLaunchGate()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Takt")
    }

    private func runLaunchGate() async {
        if reduceMotion {
            contentVisible = true
        } else {
            withAnimation(.easeOut(duration: 0.7)) {
                contentVisible = true
            }
        }

        let ms = UInt64(settlingSeconds * 1_000)
        try? await Task.sleep(for: .milliseconds(ms))

        // One frame of yield so the main hierarchy has begun layout under the overlay.
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 40))

        await MainActor.run {
            onFinished()
        }
    }

    @ViewBuilder
    private var wordmarkBlock: some View {
        Group {
            if reduceMotion {
                wordmarkCore
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let breathe = 1.0 + 0.014 * sin(t * 0.88)
                    wordmarkCore
                        .scaleEffect(breathe)
                }
            }
        }
    }

    @ViewBuilder
    private var wordmarkCore: some View {
        ZStack {
            // Soft bloom — reads depth without loud glow
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            TaktTheme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 200, height: 100)
                .blur(radius: 28)
                .opacity(0.85)

            if let uiImage = UIImage(named: "TaktWordmark"), uiImage.size.width > 1 {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 248, maxHeight: 68)
                    .shadow(color: TaktTheme.accent.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 20, y: 8)
            } else {
                textWordmark
            }
        }
    }

    private var textWordmark: some View {
        Text("Takt")
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .tracking(-1.0)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        TaktTheme.accent,
                        TaktTheme.accent.opacity(0.78),
                        TaktTheme.accentSecondary.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: TaktTheme.accent.opacity(colorScheme == .dark ? 0.32 : 0.14), radius: 16, y: 6)
            .overlay {
                if !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 25.0, paused: false)) { ctx in
                        let u = ctx.date.timeIntervalSinceReferenceDate
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.28),
                                .clear
                            ],
                            startPoint: UnitPoint(x: 0.15 + 0.7 * (0.5 + 0.5 * sin(u * 0.55)), y: 0.2),
                            endPoint: UnitPoint(x: 0.85 + 0.7 * (0.5 + 0.5 * sin(u * 0.55 + 1.4)), y: 0.85)
                        )
                        .blendMode(.plusLighter)
                        .mask(
                            Text("Takt")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .tracking(-1.0)
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
    }

    private var settlingBar: some View {
        Group {
            if reduceMotion {
                Capsule()
                    .fill(TaktTheme.accent.opacity(0.4))
                    .frame(width: 96, height: 4)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 40.0, paused: false)) { context in
                    let elapsed = context.date.timeIntervalSince(sessionStart)
                    let p = min(1.0, elapsed / settlingSeconds)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                            .frame(width: 120, height: 4)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        TaktTheme.accent.opacity(0.55),
                                        TaktTheme.accent,
                                        TaktTheme.accentSecondary.opacity(0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, 120 * p), height: 4)
                            .shadow(color: TaktTheme.accent.opacity(0.35), radius: 6, y: 0)
                    }
                    .animation(.easeInOut(duration: 0.12), value: p)
                }
            }
        }
    }
}

#Preview {
    TaktLaunchSplashView(onFinished: {})
}
