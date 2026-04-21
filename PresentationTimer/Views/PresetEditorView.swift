import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var presetStore: PresetStore
    @Environment(\.taktLaunchPresentation) private var launchPresentation

    @State private var preset: Preset
    /// At most one segment row shows the wheel timer at a time.
    @State private var expandedSegmentId: UUID?

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
                    SegmentEditorRow(
                        segment: $seg,
                        isTimingExpanded: expandedSegmentId == seg.id,
                        onToggleTiming: {
                            if expandedSegmentId == seg.id {
                                expandedSegmentId = nil
                            } else {
                                expandedSegmentId = seg.id
                            }
                        }
                    )
                }
                .onDelete { offsets in
                    let removed = offsets.map { preset.segments[$0].id }
                    if let ex = expandedSegmentId, removed.contains(ex) {
                        expandedSegmentId = nil
                    }
                    preset.segments.remove(atOffsets: offsets)
                }

                Button("Add segment") {
                    preset.segments.append(Segment(title: "Slide \(preset.segments.count + 1)", durationSeconds: 180))
                }
            }

            Section("Timeline") {
                NavigationLink {
                    PresetGanttTimelineView(preset: preset)
                } label: {
                    Label("Gantt chart", systemImage: "chart.bar.doc.horizontal")
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
            ToolbarItemGroup(placement: .primaryAction) {
                if let url = try? TaktPresetURL.shareURL(for: preset) {
                    ShareLink(
                        item: url,
                        subject: Text(preset.name),
                        message: Text("Opens in Takt if installed (takt-app.org). Otherwise use the App Store page for Takt, then open the link again."),
                        preview: SharePreview(preset.name, image: Image(systemName: "link"))
                    ) {
                        Label("Plan link", systemImage: "link")
                    }
                }
                if let jsonURL = try? presetStore.exportJSONFileURL(for: preset) {
                    ShareLink(
                        item: TaktSharedJSONFile(url: jsonURL),
                        subject: Text(preset.name),
                        message: Text("Takt preset (JSON)."),
                        preview: SharePreview("\(preset.name).json", image: Image(systemName: "doc.text"))
                    ) {
                        Label("JSON", systemImage: "doc.text")
                    }
                }
            }
        }
        .onDisappear {
            presetStore.upsert(preset)
        }
    }

    /// Same global session as Home / Plans (`ContentView` owns mini bar + Live Activity).
    private func beginRun() {
        guard !preset.segments.isEmpty else { return }
        launchPresentation?(preset)
    }
}

#Preview {
    NavigationStack {
        PresetEditorView(preset: .sample)
    }
    .environmentObject(PresetStore())
    .environmentObject(TimerEngine())
}
