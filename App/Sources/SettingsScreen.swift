import SwiftUI

/// Settings: a grouped Form. The same page is the Mac's detail pane and its ⌘, window (~520 wide).
struct SettingsScreen: View {
    @EnvironmentObject var store: Store
    @StateObject private var files = SettingsFiles()

    var body: some View {
        Form {
            SettingsPeopleSection()
            SettingsBurpSection()
            SettingsTasteSection()
            SettingsAppearanceSection()
            SettingsICloudSection()
            SettingsWebImportSection(files: files)
            SettingsExportSection(files: files)
            SettingsAISection()
            SettingsLinksSection()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Area.settings.color)
        .navigationTitle("Settings")
        .settingsFiles(files)
        .accessibilityIdentifier("settings-screen")
    }
}

/// A Form section with a heading in the Settings colour.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content
    var body: some View {
        Section {
            content
        } header: {
            Text(title).font(.headline).foregroundStyle(Area.settings.color).textCase(nil)
                .accessibilityAddTraits(.isHeader)
        } footer: {
            if let footer { Text(footer).font(.caption).foregroundStyle(Theme.muted) }
        }
    }
}

/// A short explaining line inside a section.
struct SettingsNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.subheadline).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
}

enum SettingsDevice {
    /// "iPhone", "iPad" or "Mac".
    static var name: String {
        #if os(macOS)
        "Mac"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
    static var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
}
