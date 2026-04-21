import SwiftUI
import UIKit

/// Prompts the user to enable Do Not Disturb / Focus before starting a timed run.
struct DNDGateView: View {
    @Binding var isPresented: Bool
    var onContinue: () -> Void

    @State private var skipNextTime = AppSettings.skipDNDPrompt

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Before you present")
                    .font(.title2.weight(.semibold))

                Text(
                    "Turn on Do Not Disturb or a Focus (e.g. Do Not Disturb) so calls and banners do not interrupt your timing cues. " +
                        "This app cannot enable Focus for you."
                )
                .font(.body)
                .foregroundStyle(.secondary)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                Toggle("Do not show this again", isOn: $skipNextTime)
                    .onChange(of: skipNextTime) { _, v in
                        AppSettings.skipDNDPrompt = v
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        AppSettings.skipDNDPrompt = skipNextTime
                        isPresented = false
                        onContinue()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    DNDGateView(isPresented: .constant(true), onContinue: {})
}
