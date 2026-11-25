import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let xlsxSheet = UTType(filenameExtension: "xlsx", conformingTo: .spreadsheet) ?? .data
}

/// The bytes of one exported file, for .fileExporter (works the same on iPhone, iPad and Mac).
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .xlsxSheet, .data] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

/// What the file pickers, the exporter and the "are you sure" sheet are doing right now. One object, so the
/// whole Settings page has exactly one importer and one exporter.
@MainActor
final class SettingsFiles: ObservableObject {
    enum Pick { case web, restore }
    enum Pending { case web(WebImport.Result), restore(AppData) }

    @Published var showImporter = false
    @Published var showExporter = false
    @Published var document = ExportDocument()
    @Published var exportType: UTType = .json
    @Published var exportName = "fermentlog"
    @Published var pending: Pending?
    @Published var problem: String?
    private var pick: Pick = .web

    func choose(_ p: Pick) { pick = p; showImporter = true }

    func export(_ data: Data, type: UTType, name: String) {
        document = ExportDocument(data: data); exportType = type; exportName = name; showExporter = true
    }

    func picked(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let raw = try? Data(contentsOf: url) else { problem = "This file could not be read."; return }
        do {
            switch pick {
            case .web: pending = .web(try WebImport.read(raw))
            case .restore: pending = .restore(try ImportApply.parseBackup(raw))
            }
        } catch {
            problem = (error as? LocalizedError)?.errorDescription ?? "This is not a FermentLog backup."
        }
    }

    func confirm(store: Store) {
        guard let p = pending else { return }
        pending = nil
        switch p {
        case .web(let r): store.showToast(ImportApply.bringInWebBackup(r, into: store))
        case .restore(let d): store.showToast(ImportApply.restoreBackup(d, into: store))
        }
        Alarms.reschedule(store: store)
    }
}

/// The small "this is what is inside — bring it in?" page.
struct ImportConfirmSheet: View {
    let pending: SettingsFiles.Pending
    let cancel: () -> Void
    let confirm: () -> Void
    private var title: String { if case .web = pending { "Bring in this backup?" } else { "Restore this backup?" } }
    private var line: String {
        switch pending {
        case .web(let r): ImportApply.countsLine(r)
        case .restore(let d): ImportApply.countsLine(d)
        }
    }
    private var button: String { if case .web = pending { "Bring them in" } else { "Restore" } }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            SectionHeading(title, .settings)
            Text(line.isEmpty ? "The file holds nothing yet." : line).font(.body.weight(.semibold))
                .accessibilityIdentifier("settings-import-counts")
            Text("A safety copy of what is here now is made first, and nothing is deleted. Anything already here stays; the newest change to each jar or recipe wins.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            HStack(spacing: Theme.gap) {
                Button("Cancel", action: cancel).buttonStyle(QuietButtonStyle(area: .settings))
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier("settings-import-cancel")
                Button(button, action: confirm).buttonStyle(PrimaryButtonStyle(area: .settings))
                    .accessibilityIdentifier("settings-import-confirm")
            }
        }
        .padding(16)
        .frame(minWidth: 300, maxWidth: 480)
        .presentationDetents([.height(260)])
        .background(Theme.bg)
    }
}

private struct SettingsFilesModifier: ViewModifier {
    @ObservedObject var files: SettingsFiles
    @EnvironmentObject var store: Store
    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $files.showImporter, allowedContentTypes: [.json]) { files.picked($0.map { [$0] }) }
            .fileExporter(isPresented: $files.showExporter, document: files.document, contentType: files.exportType, defaultFilename: files.exportName) { result in
                if case .success = result {
                    store.updateSettings { $0.lastBackupAt = Date() }
                    store.showToast("Saved")
                }
            }
            .sheet(isPresented: Binding(get: { files.pending != nil }, set: { if !$0 { files.pending = nil } })) {
                if let p = files.pending {
                    ImportConfirmSheet(pending: p, cancel: { files.pending = nil }, confirm: { files.confirm(store: store) })
                }
            }
            .alert("Cannot use this file", isPresented: Binding(get: { files.problem != nil }, set: { if !$0 { files.problem = nil } })) {
                Button("OK") { files.problem = nil }
            } message: { Text(files.problem ?? "") }
    }
}

extension View {
    func settingsFiles(_ files: SettingsFiles) -> some View { modifier(SettingsFilesModifier(files: files)) }
}
