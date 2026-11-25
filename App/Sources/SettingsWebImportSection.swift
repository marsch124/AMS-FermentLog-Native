import SwiftUI

struct SettingsWebImportSection: View {
    @ObservedObject var files: SettingsFiles
    @EnvironmentObject var store: Store
    var body: some View {
        SettingsSection(title: "Bring your jars over from the web app") {
            VStack(alignment: .leading, spacing: Theme.tight) {
                SettingsNote("1. Open the old FermentLog (the web app) on the iPhone.")
                SettingsNote("2. Settings › Export & backup › save the file to Files.")
                SettingsNote("3. Come back here and choose that file.")
            }
            .accessibilityElement(children: .combine)
            Button("Choose the backup file") { files.choose(.web) }
                .buttonStyle(PrimaryButtonStyle(area: .settings))
                .accessibilityIdentifier("settings-import-web")
        }
        .disabled(store.needsUpdate)
    }
}
