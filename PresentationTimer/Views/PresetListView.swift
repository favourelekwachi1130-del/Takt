import SwiftUI
import UniformTypeIdentifiers

struct PresetListView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine

    @State private var showDNDGate = false
    @State private var pendingRunPreset: Preset?
    @State private var showRunCover = false
    @State private var runningPreset: Preset?
    @State private var importError: String?
    @State private var showImportError = false
    @State private var isImporting = false

    var body: some View {
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
        .navigationTitle("Presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New preset") {
                        let p = Preset(name: "Untitled", segments: [Segment(title: "Slide 1", durationSeconds: 180)])
                        presetStore.upsert(p)
                    }
                    Button("Import JSON…") {
                        isImporting = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let first = presetStore.presets.first {
                Button {
                    beginRunIfAllowed(with: first)
                } label: {
                    Label("Start with \(first.name)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .sheet(isPresented: $showDNDGate) {
            DNDGateView(isPresented: $showDNDGate) {
                guard let p = pendingRunPreset else { return }
                timerEngine.loadPreset(p)
                runningPreset = p
                showRunCover = true
                pendingRunPreset = nil
            }
        }
        .fullScreenCover(isPresented: $showRunCover, onDismiss: {
            runningPreset = nil
        }) {
            if let p = runningPreset {
                RunSessionView(
                    preset: p,
                    onMinimize: { showRunCover = false },
                    onEnd: {
                        showRunCover = false
                        runningPreset = nil
                    },
                    onRecordCompletion: {}
                )
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
                CrashReporting.recordError(error)
            }
        }
        .alert("Import failed", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func beginRunIfAllowed(with preset: Preset) {
        guard !preset.segments.isEmpty else { return }
        if AppSettings.skipDNDPrompt {
            timerEngine.loadPreset(preset)
            runningPreset = preset
            showRunCover = true
        } else {
            pendingRunPreset = preset
            showDNDGate = true
        }
    }
}

#Preview {
    NavigationStack {
        PresetListView()
    }
    .environmentObject(PresetStore())
    .environmentObject(TimerEngine())
}
