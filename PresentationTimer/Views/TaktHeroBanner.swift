import SwiftUI

/// Eye-catching hero: personalized greeting (device timezone) + rotating taglines with bubbly motion.
struct TaktHeroBanner: View {
    var displayName: String

    @State private var taglineIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = .current
        return cal
    }

    private var greetingLine: String {
        let period = periodGreeting()
        let first = firstName(from: displayName)
        if first.isEmpty {
            return "\(period)!"
        }
        return "\(period), \(first)!"
    }

    private func firstName(from full: String) -> String {
        let t = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return String(t.split(separator: " ").first ?? "")
    }

    /// Uses the user's current calendar and **TimeZone.current** (device setting).
    private func periodGreeting(now: Date = .now) -> String {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5 ..< 12:
            return "Good morning"
        case 12 ..< 17:
            return "Good afternoon"
        case 17 ..< 22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    private var taglines: [String] { TaktHeroTaglines.all }

    private var heroPrimaryText: Color {
        colorScheme == .dark ? .white : Color(red: 0.11, green: 0.10, blue: 0.10)
    }

    private var heroSecondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.52)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    TaktTheme.accent.opacity(colorScheme == .dark ? 0.4 : 0.2),
                                    TaktTheme.accent.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.22 : 0.65),
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .frame(minHeight: 168)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14), radius: 8, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 12) {
                Text(greetingLine)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(heroPrimaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(1.0)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 84, alignment: .topLeading)
                    .layoutPriority(1)

                ZStack(alignment: .leading) {
                    Text(taglines[taglineIndex])
                        .font(.title3.weight(.bold))
                        .foregroundStyle(heroPrimaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .id(taglineIndex)
                        .transition(
                            .asymmetric(
                                insertion: AnyTransition
                                    .move(edge: .trailing)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.88, anchor: .leading)),
                                removal: AnyTransition
                                    .move(edge: .leading)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 1.06, anchor: .trailing))
                            )
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()

                Text("Pacing cues · haptics · segment flow")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(heroSecondaryText)
            }
            .padding(22)
        }
        .onAppear {
            taglineIndex = Int.random(in: 0 ..< taglines.count)
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            let next = (taglineIndex + 1) % taglines.count
            withAnimation(.spring(response: 0.52, dampingFraction: 0.76, blendDuration: 0.15)) {
                taglineIndex = next
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TaktHeroBanner(displayName: "Jordan")
        .padding()
        .background(Color.black)
}
