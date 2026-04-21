import SwiftUI
import UniformTypeIdentifiers

struct PresetListView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @Environment(\.taktLaunchPresentation) private var launchPresentation

    @State private var importError: String?
    @State private var showImportError = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(presetStore.presets) { preset in
                    NavigationLink {
                        PresetEditorView(preset: preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                            Text("\(preset.segments.count) segments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Start timer") {
                            beginRunIfAllowed(with: preset)
                        }
                    }
                }
                .onDelete(perform: presetStore.delete)
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New plan") {
                            let p = Preset(name: "Untitled talk", segments: [Segment(title: "Slide 1", durationSeconds: 180)])
                            presetStore.upsert(p)
                        }
                        Button("Import JSON…") {
                            isImporting = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add or import plan")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let data = try Data(contentsOf: url)
                    try presetStore.importPreset(from: data)
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                    CrashReporting.recordError(error)
                }
            case .failure(let error):
                importError = error.localizedDescription
                showImportError = true
            }
        }
        .alert("Import failed", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    /// Uses the same `ContentView` session shell as Home (mini timer, Live Activity, single full-screen cover).
    private func beginRunIfAllowed(with preset: Preset) {
        guard !preset.segments.isEmpty else { return }
        launchPresentation?(preset)
    }
}

#Preview {
    PresetListView()
        .environmentObject(PresetStore())
        .environmentObject(TimerEngine())
}
