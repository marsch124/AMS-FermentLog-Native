import SwiftUI

struct SettingsTasteSection: View {
    @EnvironmentObject var store: Store
    var body: some View {
        SettingsSection(title: "Taste-test reminder") {
            Toggle("Remind on this \(SettingsDevice.name)", isOn: Binding(
                get: { store.device.tasteAlarmHere },
                set: { store.device.tasteAlarmHere = $0; Alarms.reschedule(store: store) }))
                .accessibilityIdentifier("settings-taste-here")
            SettingsNote("Each jar sets its own number of days between taste tests, when you make or change the jar.")
        }
    }
}

struct SettingsAppearanceSection: View {
    @EnvironmentObject var store: Store
    var body: some View {
        SettingsSection(title: "Appearance") {
            Picker("Appearance", selection: $store.device.appearance) {
                Text("System").tag(AppearanceChoice.system)
                Text("Light").tag(AppearanceChoice.light)
                Text("Dark").tag(AppearanceChoice.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("settings-appearance")
        }
    }
}

struct SettingsICloudSection: View {
    @EnvironmentObject var store: Store

    private var synced: String {
        guard let d = store.lastSynced else { return "not yet" }
        return "\(Logic.isoDay(d)) \(Logic.clock(d))"
    }

    var body: some View {
        SettingsSection(title: "iCloud") {
            if store.needsUpdate {
                Text("A newer FermentLog saved this data. Update this device first — until then nothing is changed here.")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.problem)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings-needs-update")
            }
            if let problem = store.saveProblem {
                Text("Could not save: \(problem)").font(.subheadline).foregroundStyle(Theme.problem)
                    .accessibilityIdentifier("settings-save-problem")
            }
            Text(store.inCloud ? "In iCloud — the same jars on your iPhone, iPad and Mac" : "Only on this device — iCloud Drive is off")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings-icloud-place")
            Fact(name: "State", value: store.cloudState.isEmpty ? "—" : store.cloudState)
            Fact(name: "Last synced", value: synced)
            if store.conflictsMerged > 0 {
                SettingsNote("\(ImportApply.plural(store.conflictsMerged, "clash")) between devices joined together since this app opened. Nothing was lost.")
            }
            Button(store.syncing ? "Syncing…" : "Sync now") { store.syncNow() }
                .buttonStyle(QuietButtonStyle(area: .settings))
                .disabled(store.syncing)
                .accessibilityIdentifier("settings-sync-now")
            NavigationLink(value: Route.safetyCopies) { Text("Safety copies").foregroundStyle(Area.settings.color) }
                .accessibilityIdentifier("settings-safety-copies")
        }
    }
}

struct SettingsLinksSection: View {
    var body: some View {
        Section {
            NavigationLink(value: Route.manageLists) { Text("Your lists") }.accessibilityIdentifier("settings-manage-lists")
            NavigationLink(value: Route.guide) { Text("How it works") }.accessibilityIdentifier("settings-guide")
            NavigationLink(value: Route.whatsNew) { Text("What’s new") }.accessibilityIdentifier("settings-whats-new")
            Fact(name: "Version", value: "\(Guide.appVersion) (\(SettingsDevice.buildNumber))").accessibilityIdentifier("settings-version")
        } footer: {
            Text("Your lists: your own vegetables, cuts and spices, and your jar templates.").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}
