import SwiftUI
import UniformTypeIdentifiers

struct SettingsExportSection: View {
    @ObservedObject var files: SettingsFiles
    @EnvironmentObject var store: Store

    var body: some View {
        SettingsSection(title: "Export") {
            Button("Spreadsheet (.xlsx)") {
                files.export(Xlsx.workbook(Logic.exportSheets(store.data)), type: .xlsxSheet, name: "fermentlog-\(Logic.isoDay(Date()))")
            }
            .buttonStyle(QuietButtonStyle(area: .settings)).accessibilityIdentifier("settings-export-xlsx")
            Button("CSV") {
                files.export(Data(Logic.toFullCSV(store.data).utf8), type: .commaSeparatedText, name: "fermentlog-\(Logic.isoDay(Date()))")
            }
            .buttonStyle(QuietButtonStyle(area: .settings)).accessibilityIdentifier("settings-export-csv")
            Button("Backup file") {
                if let d = try? JSONEncoder.app.encode(store.data) {
                    files.export(d, type: .json, name: "fermentlog-backup-\(Logic.isoDay(Date()))")
                }
            }
            .buttonStyle(QuietButtonStyle(area: .settings)).accessibilityIdentifier("settings-export-backup")
            SettingsNote("The spreadsheet and the CSV are for reading. The backup file holds all your jars, bakes, recipes and lessons, but not the pictures — they stay in iCloud and in the safety copies.")
            Button("Restore from a backup file") { files.choose(.restore) }
                .buttonStyle(QuietButtonStyle(area: .settings))
                .disabled(store.needsUpdate)
                .accessibilityIdentifier("settings-restore-file")
            SettingsNote("Asks first. A safety copy is made, then the backup is joined with what is here.")
        }
    }
}
