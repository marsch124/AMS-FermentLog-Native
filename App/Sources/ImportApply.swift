import Foundation

/// What happens after a backup file has been read and he said "Bring them in" / "Restore": kept apart from the
/// screens so it can be tested. A safety copy is always written first.
enum ImportApply {

    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String { "\(n) \(n == 1 ? one : (many ?? one + "s"))" }

    /// "7 jars, 2 bakes, 3 recipes, 4 lessons, 1 template, 12 pictures" (nothing for a kind with none).
    static func countsLine(jars: Int, bakes: Int, recipes: Int, lessons: Int, presets: Int, photos: Int) -> String {
        [(jars, "jar", "jars"), (bakes, "bake", "bakes"), (recipes, "recipe", "recipes"), (lessons, "lesson", "lessons"),
         (presets, "template", "templates"), (photos, "picture", "pictures")]
            .filter { $0.0 > 0 }.map { plural($0.0, $0.1, $0.2) }.joined(separator: ", ")
    }

    static func countsLine(_ r: WebImport.Result) -> String {
        let c = r.counts
        return countsLine(jars: c.jars, bakes: c.bakes, recipes: c.recipes, lessons: c.lessons, presets: c.presets, photos: c.photos)
    }

    static func countsLine(_ d: AppData) -> String {
        countsLine(jars: d.liveBatches.count, bakes: d.liveBakes.count, recipes: d.liveRecipes.count, lessons: d.liveLessons.count, presets: d.livePresets.count, photos: 0)
    }

    /// Brings a web backup in: safety copy "Before import", the pictures (never over one that exists), then the merge.
    /// Importing the same file twice changes nothing (stable ids, stable picture names). Returns the toast text.
    @MainActor @discardableResult
    static func bringInWebBackup(_ result: WebImport.Result, into store: Store) -> String {
        store.writeCopy(named: "Before import")
        let fm = FileManager.default
        for (name, bytes) in result.photos where !fm.fileExists(atPath: store.photosURL.appendingPathComponent(name).path) {
            try? bytes.write(to: store.photosURL.appendingPathComponent(name), options: .atomic)
        }
        store.update { $0 = WebImport.merge(result.data, into: $0) }
        let line = countsLine(result)
        return line.isEmpty ? "Nothing to bring in" : "Brought in " + line
    }

    enum BackupProblem: Error, LocalizedError, Equatable {
        case notABackup, fromTheWebApp, tooNew
        var errorDescription: String? {
            switch self {
            case .notABackup: "This is not a FermentLog backup."
            case .fromTheWebApp: "This backup comes from the old web app. Use “Bring your jars over from the web app” for it."
            case .tooNew: "A newer FermentLog made this backup. Update this device first."
            }
        }
    }

    /// Reads one of this app's own backup files.
    static func parseBackup(_ raw: Data) throws -> AppData {
        guard let obj = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any] else { throw BackupProblem.notABackup }
        if (obj["app"] as? String) == "fermentlog" { throw BackupProblem.fromTheWebApp }
        guard obj["format"] != nil, obj["batches"] != nil, let data = try? JSONDecoder.app.decode(AppData.self, from: raw) else { throw BackupProblem.notABackup }
        guard data.format <= AppData.currentFormat else { throw BackupProblem.tooNew }
        return data
    }

    /// Puts a backup file's records in with what is here (newest change per record wins), after a safety copy.
    @MainActor @discardableResult
    static func restoreBackup(_ incoming: AppData, into store: Store) -> String {
        store.writeCopy(named: "Before restore")
        store.update { $0 = AppData.merged($0, incoming) }
        let line = countsLine(incoming)
        return line.isEmpty ? "Backup restored" : "Restored " + line
    }
}
