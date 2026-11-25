import SwiftUI

struct SettingsPeopleSection: View {
    @EnvironmentObject var store: Store
    @State private var newName = ""
    @State private var removing: String?

    private var people: [String] { store.data.settings.people }

    var body: some View {
        SettingsSection(title: "Who is logging") {
            SettingsNote("Add whoever logs jars, bakes and lessons. The one marked Logging is stamped on new entries as “Logged by”, and you can change it on any entry.")
            ForEach(people, id: \.self) { p in
                HStack(spacing: Theme.gap) {
                    Button { store.updateSettings { $0.activePerson = p } } label: {
                        HStack(spacing: Theme.gap) {
                            Text(p).foregroundStyle(Theme.ink)
                            if p == store.data.settings.activePerson { Pill(text: "Logging", color: Area.settings.color) }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(p == store.data.settings.activePerson ? "\(p), logging" : "Log as \(p)")
                    .accessibilityIdentifier("settings-person-\(p)")
                    Button("Remove") { removing = p }
                        .buttonStyle(.borderless).foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("settings-person-remove-\(p)")
                }
            }
            if people.count > 1 { SettingsNote("Tap a name to log as that person.") }
            HStack(spacing: Theme.gap) {
                TextField("Add a name", text: $newName)
                    .onSubmit(add)
                    .accessibilityIdentifier("settings-person-name")
                Button("Add", action: add)
                    .buttonStyle(QuietButtonStyle(area: .settings))
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("settings-person-add")
            }
        }
        .disabled(store.needsUpdate)
        .confirmationDialog("Remove \(removing ?? "this person")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let r = removing { remove(r) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Their name stays on the entries they logged.") }
    }

    private func add() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        store.updateSettings {
            if !$0.people.contains(n) { $0.people.append(n) }
            if $0.activePerson.isEmpty { $0.activePerson = n }
        }
        newName = ""
    }

    private func remove(_ name: String) {
        store.updateSettings {
            $0.people.removeAll { $0 == name }
            if $0.activePerson == name { $0.activePerson = $0.people.first ?? "" }
        }
        removing = nil
    }
}
