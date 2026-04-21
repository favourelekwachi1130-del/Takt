import SwiftUI

/// First-run friendly name capture (device timezone greetings use this on Home).
struct TaktNameSetupSheet: View {
    @Binding var isPresented: Bool
    @Binding var displayName: String
    @Binding var profileSetupCompleted: Bool

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome to Takt")
                    .font(.title2.weight(.bold))

                Text("What should we call you? We’ll greet you on the home screen using your device’s time zone.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $draft)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
                    .focused($focused)

                Spacer()

                Button {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    displayName = trimmed
                    profileSetupCompleted = true
                    isPresented = false
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaktTheme.accent)

                Button("Skip for now") {
                    profileSetupCompleted = true
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                draft = displayName
                focused = true
            }
        }
    }
}
