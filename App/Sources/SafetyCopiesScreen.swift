import SwiftUI

struct SafetyCopiesScreen: View {
    @EnvironmentObject var store: Store
    @State private var restoring: URL?

    var body: some View {
        Form {
            Section {
                SettingsNote("FermentLog keeps a safety copy of everything once a day, for 30 days. Copies made before an import or a restore, and the ones you make yourself, are kept for good.")
                Button("Make a safety copy now") {
                    store.showToast(store.writeCopy(named: "Copy") ? "Safety copy made" : "Could not make a safety copy")
                }
                .buttonStyle(PrimaryButtonStyle(area: .settings))
                .disabled(store.needsUpdate)
                .accessibilityIdentifier("settings-copy-make")
            }
            SettingsSection(title: "Copies, newest first") {
                if store.safetyCopies.isEmpty { SettingsNote("No copies yet. Make one with the button above.") }
                ForEach(store.safetyCopies, id: \.self) { url in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.gap) {
                            Text(Self.title(url)).fontWeight(.semibold)
                            Spacer(minLength: 0)
                            Button("Restore this copy") { restoring = url }
                                .buttonStyle(.borderless).foregroundStyle(Area.settings.color)
                                .disabled(store.needsUpdate)
                                .accessibilityIdentifier("settings-copy-restore-\(url.deletingPathExtension().lastPathComponent)")
                        }
                        Text(Self.when(store.mod(url)) + " · " + (store.copySummaries[url] ?? "Reading…"))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    .accessibilityIdentifier("settings-copy-\(url.deletingPathExtension().lastPathComponent)")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Area.settings.color)
        .navigationTitle("Safety copies")
        .task(id: store.safetyCopies.count) { store.refreshCopies(); await store.loadCopySummaries() }
        .confirmationDialog("Restore this copy?", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }), titleVisibility: .visible) {
            Button("Restore this copy", role: .destructive) {
                if let u = restoring {
                    store.showToast(store.restore(from: u) ? "Copy restored" : "Could not restore this copy")
                    Alarms.reschedule(store: store)
                }
                restoring = nil
            }
            Button("Cancel", role: .cancel) { restoring = nil }
        } message: {
            Text("Everything goes back to how it was in this copy. A copy of how it is now is kept first, called “Before restore”.")
        }
    }

    /// "Daily 2026-11-25", "Before import" … without the time stamp that makes the file name unique.
    static func title(_ url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        return base.replacingOccurrences(of: #"\s\d{4}-\d{2}-\d{2}T\d{2}\.\d{2}\.\d{2}.*$"#, with: "", options: .regularExpression)
    }
    static func when(_ d: Date?) -> String { d.map { "\(Logic.isoDay($0)) \(Logic.clock($0))" } ?? "—" }
}
