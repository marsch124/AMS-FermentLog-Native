import SwiftUI

/// His own vegetables, cuts and spices, and his jar templates: rename and remove.
struct ManageListsScreen: View {
    @EnvironmentObject var store: Store
    typealias Kind = SettingsListEdit.Kind

    private struct Target: Identifiable { let kind: Kind?; let id: String; let name: String }   // kind nil = a template
    @State private var renaming: Target?
    @State private var draft = ""
    @State private var removing: Target?

    var body: some View {
        Form {
            Section {
                SettingsNote("Rename or remove the vegetables, cuts and spices you added. The built-in ones are not listed. Renaming changes every jar and template that uses the name. A vegetable or cut can only be removed when no jar uses it; a spice is also taken off the jars and templates that have it.")
            }
            ForEach(Kind.allCases, id: \.self) { kind in
                SettingsSection(title: kind.title) {
                    let names = SettingsListEdit.names(kind, in: store.data)
                    if names.isEmpty { SettingsNote("None of your own yet. They appear here once you add one to a jar.") }
                    ForEach(names, id: \.self) { n in
                        row(name: n, detail: SettingsListEdit.usage(kind, n, in: store.data),
                            key: "\(kind.rawValue)-\(n)", target: Target(kind: kind, id: "\(kind.rawValue)-\(n)", name: n))
                    }
                }
            }
            SettingsSection(title: "Jar templates") {
                let presets = store.data.livePresets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                if presets.isEmpty { SettingsNote("No jar templates yet. Save one from a jar to start the next one from it.") }
                ForEach(presets) { p in
                    row(name: p.name.isEmpty ? p.vegetable : p.name, detail: p.vegetable, key: "template-\(p.id)", target: Target(kind: nil, id: p.id, name: p.name))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Area.settings.color)
        .navigationTitle("Your lists")
        .disabled(store.needsUpdate)
        .alert("Rename “\(renaming?.name ?? "")”", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("New name", text: $draft).accessibilityIdentifier("settings-list-rename-field")
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Save") { applyRename() }
        } message: {
            Text(renaming?.kind == nil ? "" : "Every jar and template that uses it changes too.")
        }
        .confirmationDialog(removeTitle, isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            if let t = removing, t.kind != nil, !SettingsListEdit.canRemove(t.kind!, t.name, in: store.data) {
                Button("OK", role: .cancel) {}
            } else {
                Button("Remove", role: .destructive) { applyRemove() }
                Button("Cancel", role: .cancel) {}
            }
        } message: { Text(removeMessage) }
    }

    private func row(name: String, detail: String, key: String, target: Target) -> some View {
        HStack(spacing: Theme.gap) {
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Button("Rename") { draft = target.name; renaming = target }
                .buttonStyle(.borderless).foregroundStyle(Area.settings.color)
                .accessibilityIdentifier("settings-list-rename-\(key)")
            Button("Remove") { removing = target }
                .buttonStyle(.borderless).foregroundStyle(Theme.problem)
                .accessibilityIdentifier("settings-list-remove-\(key)")
        }
    }

    private var removeTitle: String {
        guard let t = removing else { return "Remove?" }
        if let k = t.kind, !SettingsListEdit.canRemove(k, t.name, in: store.data) { return "“\(t.name)” is still in use" }
        return "Remove “\(t.name)”?"
    }
    private var removeMessage: String {
        guard let t = removing else { return "" }
        guard let k = t.kind else { return "You can take it back for a moment with Undo." }
        let n = SettingsListEdit.jarCount(k, t.name, in: store.data)
        if !SettingsListEdit.canRemove(k, t.name, in: store.data) {
            return "\(ImportApply.plural(n, "jar")) use\(n == 1 ? "s" : "") it. Rename it, or change those jars first — a jar cannot be left without a \(k.one)."
        }
        if k == .spice, n > 0 || SettingsListEdit.templateCount(k, t.name, in: store.data) > 0 { return "It is also taken off every jar and template that has it." }
        return ""
    }

    private func applyRename() {
        guard let t = renaming else { return }
        let new = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = nil
        guard !new.isEmpty, new != t.name else { return }
        if let k = t.kind {
            store.update { SettingsListEdit.rename(k, from: t.name, to: new, in: &$0) }
        } else if var p = store.data.livePresets.first(where: { $0.id == t.id }) {
            p.name = new; store.save(p)
        }
        store.showToast("Renamed to “\(new)”")
    }

    private func applyRemove() {
        guard let t = removing else { return }
        removing = nil
        if let k = t.kind {
            var removed = false
            store.update { removed = SettingsListEdit.remove(k, t.name, in: &$0) }
            if removed { store.showToast("“\(t.name)” removed") }
        } else {
            store.remove(preset: t.id)
            store.showToast("Template removed", undo: { store.restore(preset: t.id) })
        }
    }
}
