import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @EnvironmentObject private var timerEngine: TimerEngine

    @State private var preset: Preset
    @State private var showDNDGate = false
    @State private var showRunCover = false
    @State private var runningPreset: Preset?

    init(preset: Preset) {
        _preset = State(initialValue: preset)
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $preset.name)
                Text("Created \(preset.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Segments") {
                ForEach($preset.segments) { $seg in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Title", text: $seg.title)
                        Stepper(
                            value: $seg.durationSeconds,
                            in: 15...7200,
                            step: 15
                        ) {
                            Text(durationLabel(seg.durationSeconds))
                        }
                    }
                }
                .onDelete { preset.segments.remove(atOffsets: $0) }

                Button("Add segment") {
                    preset.segments.append(Segment(title: "Slide \(preset.segments.count + 1)", durationSeconds: 180))
                }
            }

            Section {
                Button("Start timer") {
                    presetStore.upsert(preset)
                    beginRun()
                }
                .disabled(preset.segments.isEmpty)
            }
        }
        .navigationTitle("Edit preset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    presetStore.upsert(preset)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if let data = try? presetStore.exportData(for: preset) {
                    ShareLink(
                        item: data,
                        preview: SharePreview(preset.name, image: Image(systemName: "doc"))
                    ) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onDisappear {
            presetStore.upsert(preset)
        }
        .sheet(isPresented: $showDNDGate) {
            DNDGateView(isPresented: $showDNDGate) {
                guard let p = runningPreset else { return }
                timerEngine.loadPreset(p)
                showRunCover = true
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
    }

    private func beginRun() {
        guard !preset.segments.isEmpty else { return }
        runningPreset = preset
        if AppSettings.skipDNDPrompt {
            timerEngine.loadPreset(preset)
            showRunCover = true
        } else {
            showDNDGate = true
        }
    }

    private func durationLabel(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        let r = Int(s) % 60
        if r == 0 { return "\(m) min" }
        return "\(m)m \(r)s"
    }
}

#Preview {
    NavigationStack {
        PresetEditorView(preset: .sample)
    }
    .environmentObject(PresetStore())
    .environmentObject(TimerEngine())
}
