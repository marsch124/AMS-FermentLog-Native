import Foundation
import SwiftUI

/// Everything the app knows, and the only thing allowed to touch disk.
/// One file in iCloud Drive (iPhone, iPad and Mac read the same one), merged per record before every
/// write, a safety copy each day (30 kept), and the pictures in a Photos folder next to it — the pattern
/// proven in AMS Subscriptions and AMS Shopping Companion, kept whole here.
@MainActor
final class Store: ObservableObject {
    @Published private(set) var data = AppData()
    @Published var syncPlace = "This device"
    /// When this device last read the shared file and merged it in.
    @Published private(set) var lastSynced: Date?
    @Published private(set) var safetyCopies: [URL] = []
    /// Copies iCloud had set aside (two devices wrote at the same moment) that this device merged in.
    @Published private(set) var conflictsMerged = 0
    /// The one short message at the bottom of the screen ("Jar removed · Undo"); gone by itself after four seconds.
    @Published var toast: Toast?
    private var toastWork: Task<Void, Never>?
    /// What iCloud says about the shared file right now: "Up to date", "Downloading…", "Uploading…", "Not in iCloud".
    @Published private(set) var cloudState = ""
    @Published private(set) var syncing = false
    /// Why the last save did not go through (iCloud not reachable, device full); nil once a save works again.
    @Published private(set) var saveProblem: String?
    /// This device's own settings (appearance, which alarms ring here). Never synced.
    @Published var device: DeviceSettings { didSet { if device != oldValue { device.save(to: defaults) } } }
    /// A newer version of the app saved the shared file. This older one does not write it — it would
    /// save it without the details it does not know — and says "Update this device first".
    var needsUpdate: Bool { data.format > AppData.currentFormat }

    let isTestRun: Bool
    let home: URL
    let photosURL: URL
    private let dataURL: URL
    private let copiesURL: URL
    private let defaults: UserDefaults
    private let coordinator = NSFileCoordinator()
    private var saveWork: Task<Void, Never>?
    private var watcher: FileWatcher?

    static let containerID = "iCloud.com.schabbauer.AMSFermentLog"
    static let fileName = "fermentlog.json"

    init(root: URL? = nil) {
        let args = ProcessInfo.processInfo.arguments
        isTestRun = args.contains("-uiTesting")
        let d = isTestRun ? (UserDefaults(suiteName: "AMSFermentLog-UITest") ?? .standard) : .standard
        if isTestRun { d.removePersistentDomain(forName: "AMSFermentLog-UITest") }
        defaults = d
        device = DeviceSettings.load(from: d)
        home = root ?? Store.defaultRoot(freshForTests: isTestRun)
        let fm = FileManager.default
        try? fm.createDirectory(at: home, withIntermediateDirectories: true)
        dataURL = home.appendingPathComponent(Store.fileName)
        copiesURL = home.appendingPathComponent("Safety copies")
        photosURL = home.appendingPathComponent("Photos")
        try? fm.createDirectory(at: copiesURL, withIntermediateDirectories: true)
        try? fm.createDirectory(at: photosURL, withIntermediateDirectories: true)
        load()
        if isTestRun && args.contains("-sample") { data = AppData.sample }
        // Pictures: "-samplePhoto" gives the sample Cabbage jar a made-up picture (drawn here, no real photo).
        if isTestRun && args.contains("-samplePhoto"), let jpeg = SamplePhoto.jpeg(),
           let i = data.batches.firstIndex(where: { $0.id == "b_sample_cabbage" }) {
            let name = addPhoto(jpeg)
            if !name.isEmpty { data.batches[i].photos.insert(name, at: 0) }
        }
        // Pictures on Timeline lines (6.7): "-lineSamplePhotos" gives the sample Cabbage jar's lines made-up pictures —
        // two on "Packed it into the jar", one on the taste test, and one line that is only a picture.
        if isTestRun && args.contains("-lineSamplePhotos"), let i = data.batches.firstIndex(where: { $0.id == "b_sample_cabbage" }) {
            func pic(_ shade: Double) -> String { SamplePhoto.jpeg(shade: shade).map { addPhoto($0) } ?? "" }
            var b = data.batches[i]
            if let j = b.steps.firstIndex(where: { $0.text.hasPrefix("Packed") }) { b.steps[j].photos = [pic(0), pic(0.3)] }
            if let d = b.checkIns.last?.date { b.steps.append(Step(date: d, time: "08:20", text: "", photos: [pic(0.9)])) }
            if !b.checkIns.isEmpty { b.checkIns[b.checkIns.count - 1].photos = [pic(0.6)] }
            data.batches[i] = b
        }
        // Tests and pictures: as if a newer version had saved the file / as if a save had failed.
        if isTestRun && args.contains("-needsUpdate") { data.format = AppData.currentFormat + 1 }
        if isTestRun && args.contains("-saveProblem") { saveProblem = "The file could not be written." }
        // Live updates: another device's save shows up here by itself. (Not for tests and not for a given root.)
        if !isTestRun && root == nil {
            watcher = FileWatcher(url: dataURL) { [weak self] in Task { @MainActor in self?.load() } }
        }
    }

    private static func defaultRoot(freshForTests: Bool) -> URL {
        let fm = FileManager.default
        if freshForTests {
            return fm.temporaryDirectory.appendingPathComponent("AMSFermentLog-UITest-\(UUID().uuidString)")
        }
        if let cloud = fm.url(forUbiquityContainerIdentifier: containerID) {
            let docs = cloud.appendingPathComponent("Documents")
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
            return docs
        }
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AMSFermentLog")
    }

    // MARK: Load & save

    func load() {
        // iCloud keeps a new version of the file on its servers until someone asks for it — ask every time.
        if inCloud { try? FileManager.default.startDownloadingUbiquitousItem(at: dataURL) }
        var loaded: AppData?
        var err: NSError?
        coordinator.coordinate(readingItemAt: dataURL, options: [], error: &err) { url in
            if let raw = try? Data(contentsOf: url) { loaded = try? JSONDecoder.app.decode(AppData.self, from: raw) }
        }
        // Merge, never a blind replace: anything this device changed that is not saved yet stays
        // (newest change per record wins).
        if let loaded { data = AppData.merged(data, loaded); lastSynced = Date() }
        mergeConflictCopies()
        syncPlace = inCloud ? "iCloud Drive" : "This device"
        purgeRemoved()
        refreshCopies()
        refreshCloudState()
    }

    var inCloud: Bool { dataURL.path.contains("Mobile Documents") }

    /// Reads iCloud's own flags on the file. "Up to date" means this device has the newest version and its own
    /// writes have gone up; anything else explains what is still moving.
    func refreshCloudState() {
        guard inCloud else { cloudState = "Not in iCloud — turn on iCloud Drive for this app on every device"; return }
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey, .ubiquitousItemIsUploadingKey,
                                         .ubiquitousItemIsUploadedKey, .ubiquitousItemDownloadingErrorKey, .ubiquitousItemUploadingErrorKey]
        guard let v = try? dataURL.resourceValues(forKeys: keys) else { cloudState = "No shared file yet"; return }
        if let e = v.ubiquitousItemUploadingError { cloudState = "Upload failed: \(e.localizedDescription)"; return }
        if let e = v.ubiquitousItemDownloadingError { cloudState = "Download failed: \(e.localizedDescription)"; return }
        if v.ubiquitousItemIsDownloading == true { cloudState = "Downloading…"; return }
        if v.ubiquitousItemIsUploading == true { cloudState = "Uploading…"; return }
        if let s = v.ubiquitousItemDownloadingStatus, s != .current { cloudState = "A newer version is waiting in iCloud"; return }
        if v.ubiquitousItemIsUploaded == false { cloudState = "Waiting to upload"; return }
        cloudState = "Up to date"
    }

    /// True once iCloud says this device has the newest version of the file (or we are not in iCloud at all).
    private var hasNewestVersion: Bool {
        guard inCloud, let v = try? dataURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsDownloadingKey]) else { return true }
        return v.ubiquitousItemIsDownloading != true && (v.ubiquitousItemDownloadingStatus ?? .current) == .current
    }

    /// When two devices write at the same moment, iCloud keeps one write as the file and sets the other
    /// aside as a "conflict copy" nobody sees — that is how a morning of edits vanished once in AMS
    /// Subscriptions. Every copy set aside is merged in here (newest change per record wins), then cleared.
    private func mergeConflictCopies() {
        guard !isTestRun, dataURL.path.contains("Mobile Documents") else { return }
        let copies = NSFileVersion.unresolvedConflictVersionsOfItem(at: dataURL) ?? []
        guard !copies.isEmpty else { return }
        var merged = 0
        for v in copies {
            if let raw = try? Data(contentsOf: v.url), let other = try? JSONDecoder.app.decode(AppData.self, from: raw) {
                data = AppData.merged(data, other)
                merged += 1
            }
            v.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: dataURL)
        if merged > 0 { conflictsMerged += merged; scheduleSave() }
    }

    /// Settings › Sync now (and every return to the app): ask iCloud for the newest version, wait for it
    /// (up to ten seconds), merge it in, and write the result back so the other devices get this one's changes.
    func syncNow() {
        guard !syncing else { return }
        syncing = true
        Task { [weak self] in
            guard let self else { return }
            if inCloud {
                try? FileManager.default.startDownloadingUbiquitousItem(at: dataURL)
                for _ in 0..<20 where !hasNewestVersion {
                    refreshCloudState()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            saveWork?.cancel()
            load()
            saveNow()
            lastSynced = Date()
            refreshCloudState()
            syncing = false
        }
    }

    /// Debounced, so typing a name does not write the file on every letter.
    func scheduleSave() {
        saveWork?.cancel()
        saveWork = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow(merge: Bool = true) {
        data.savedAt = Date()
        var toWrite = data
        var err: NSError?
        var problem: String?
        var held = false
        coordinator.coordinate(writingItemAt: dataURL, options: .forMerging, error: &err) { url in
            if merge, let raw = try? Data(contentsOf: url) {
                if let onDisk = try? JSONDecoder.app.decode(AppData.self, from: raw) {
                    toWrite = AppData.merged(onDisk, toWrite)
                } else if !raw.isEmpty {
                    // A file this app cannot read is never written over blind — its bytes are parked in
                    // Safety copies first ("Could not read …"), so nothing another device wrote is lost.
                    try? raw.write(to: copiesURL.appendingPathComponent("Could not read " + Store.stamp() + ".json"), options: .atomic)
                }
            }
            // A file a newer version saved is never written by this older one.
            guard toWrite.format <= AppData.currentFormat else { held = true; return }
            do { try JSONEncoder.app.encode(toWrite).write(to: url, options: .atomic) } catch { problem = error.localizedDescription }
        }
        if let err { problem = err.localizedDescription }
        data = toWrite
        if held { refreshCloudState(); return }
        noteSave(problem)
        dailySafetyCopy()
        refreshCloudState()
    }

    /// A failed save is said once (toast) and stays as a red line in Settings until a save works again.
    private func noteSave(_ problem: String?) {
        if isTestRun && ProcessInfo.processInfo.arguments.contains("-saveProblem") { return }
        if problem != nil, saveProblem == nil { showToast("Could not save. Your changes are not stored yet.") }
        if saveProblem != problem { saveProblem = problem }
    }

    // MARK: Safety copies — each one is read back before it counts

    private static let dayKey: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    private func dailySafetyCopy() {
        let url = copiesURL.appendingPathComponent("Daily " + Store.dayKey.string(from: Date()) + ".json")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        writeCopy(to: url)
    }

    @discardableResult
    func writeCopy(named: String? = nil, to target: URL? = nil) -> Bool {
        let url = target ?? copiesURL.appendingPathComponent((named ?? "Copy") + " " + Store.stamp() + ".json")
        // An older version makes no copies of a newer file — they would lack what it does not know.
        guard !needsUpdate else { return false }
        guard let payload = try? JSONEncoder.app.encode(data) else { return false }
        try? payload.write(to: url, options: .atomic)
        // Proved: read back, decoded, and the same number of jars, recipes, bakes and lessons.
        guard let back = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.app.decode(AppData.self, from: back),
              decoded.batches.count == data.batches.count,
              decoded.recipes.count == data.recipes.count,
              decoded.bakes.count == data.bakes.count,
              decoded.lessons.count == data.lessons.count else {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        pruneCopies()
        refreshCopies()
        mirrorPhotos()
        return true
    }

    /// The pictures belong to the copies too: every picture file is copied once into "Safety copies/Photos"
    /// and never pruned there, so any copy can be restored with its pictures. Runs in the background.
    private var photoMirrorURL: URL { copiesURL.appendingPathComponent("Photos") }
    func mirrorPhotos() {
        let from = photosURL, to = photoMirrorURL
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            try? fm.createDirectory(at: to, withIntermediateDirectories: true)
            let have = Set((try? fm.contentsOfDirectory(atPath: to.path)) ?? [])
            for name in (try? fm.contentsOfDirectory(atPath: from.path)) ?? [] where !have.contains(name) && !name.hasPrefix(".") {
                try? fm.copyItem(at: from.appendingPathComponent(name), to: to.appendingPathComponent(name))
            }
        }
    }

    /// One line per copy ("4 jars · 2 bakes · 2 recipes"), read once in the background — a page that reads every
    /// copy on every redraw freezes the app (Shopping 0.5).
    @Published private(set) var copySummaries: [URL: String] = [:]
    func loadCopySummaries() async {
        let todo = safetyCopies.filter { copySummaries[$0] == nil }
        guard !todo.isEmpty else { return }
        let found: [URL: String] = await Task.detached(priority: .userInitiated) {
            var out: [URL: String] = [:]
            for u in todo {
                guard let raw = try? Data(contentsOf: u), let d = try? JSONDecoder.app.decode(AppData.self, from: raw) else {
                    out[u] = "Not readable on this device yet"; continue
                }
                out[u] = "\(d.liveBatches.count) jars · \(d.liveBakes.count) bakes · \(d.liveRecipes.count) recipes"
            }
            return out
        }.value
        copySummaries.merge(found) { _, new in new }
    }

    /// "2026-11-09T13.07.08" — a moment that is safe in a file name.
    static func stamp() -> String {
        Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: ".")
    }

    /// Daily copies: keep 30. Named copies ("Before restore"): keep all.
    private func pruneCopies() {
        let all = (try? FileManager.default.contentsOfDirectory(at: copiesURL, includingPropertiesForKeys: nil)) ?? []
        let old = all.filter { $0.lastPathComponent.hasPrefix("Daily ") }.sorted { $0.lastPathComponent > $1.lastPathComponent }.dropFirst(30)
        for u in old { try? FileManager.default.removeItem(at: u) }
    }

    func refreshCopies() {
        safetyCopies = ((try? FileManager.default.contentsOfDirectory(at: copiesURL, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { (mod($0) ?? .distantPast) > (mod($1) ?? .distantPast) }
    }
    func mod(_ u: URL) -> Date? { (try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate }

    func peek(_ url: URL) -> AppData? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder.app.decode(AppData.self, from: $0) }
    }

    /// Puts everything back as it was in the copy — after keeping a copy of now.
    func restore(from url: URL) -> Bool {
        guard !needsUpdate, let incoming = peek(url) else { return false }
        writeCopy(named: "Before restore")
        data = incoming
        saveNow(merge: false)
        // Pictures the copy needs but the Photos folder lost come back from the copies' picture folder.
        let fm = FileManager.default
        for name in Store.photoFiles(in: incoming) where !fm.fileExists(atPath: photosURL.appendingPathComponent(name).path) {
            try? fm.copyItem(at: photoMirrorURL.appendingPathComponent(name), to: photosURL.appendingPathComponent(name))
        }
        return true
    }

    /// Removed things leave for good after 30 days; picture files nobody refers to any more go with them.
    private func purgeRemoved() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        func keep<T: Record>(_ list: inout [T]) { list.removeAll { ($0.deletedAt ?? .distantFuture) < cutoff } }
        let before = data
        keep(&data.batches); keep(&data.presets); keep(&data.recipes); keep(&data.bakes); keep(&data.lessons)
        guard data != before else { return }
        let still = Store.photoFiles(in: data)
        for name in Store.photoFiles(in: before).subtracting(still) {
            try? FileManager.default.removeItem(at: photosURL.appendingPathComponent(name))
        }
        saveNow()
    }

    /// Every picture file the data still points at.
    static func photoFiles(in d: AppData) -> Set<String> {
        var names = Set<String>()
        for b in d.batches {
            names.formUnion(b.photos)
            for s in b.steps { names.formUnion(s.photos) }      // 6.7: pictures on Timeline lines
            for c in b.checkIns { names.formUnion(c.photos) }
        }
        for r in d.recipes { names.formUnion(r.photos) }
        for k in d.bakes { names.formUnion(k.photos) }
        names.remove("")
        return names
    }

    // MARK: Records — one way in for every kind

    /// For changes that span several records. The caller sets modifiedAt on what it touches.
    func update(_ change: (inout AppData) -> Void) {
        change(&data)
        data.savedAt = Date()
        scheduleSave()
    }

    /// Saves a record: modifiedAt = now, replaced by id or appended.
    private func upsert<T: Record>(_ record: T, in path: WritableKeyPath<AppData, [T]>) {
        var r = record
        r.modifiedAt = Date()
        if let i = data[keyPath: path].firstIndex(where: { $0.id == r.id }) {
            data[keyPath: path][i] = r
        } else {
            data[keyPath: path].append(r)
        }
        data.savedAt = Date()
        scheduleSave()
    }

    /// Removes a record with a tombstone, so the removal reaches the other devices too.
    private func tombstone<T: Record>(_ id: T.ID, in path: WritableKeyPath<AppData, [T]>) {
        guard let i = data[keyPath: path].firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        data[keyPath: path][i].deletedAt = now
        data[keyPath: path][i].modifiedAt = now
        data.savedAt = now
        scheduleSave()
    }

    private func untombstone<T: Record>(_ id: T.ID, in path: WritableKeyPath<AppData, [T]>) {
        guard let i = data[keyPath: path].firstIndex(where: { $0.id == id }) else { return }
        data[keyPath: path][i].deletedAt = nil
        data[keyPath: path][i].modifiedAt = Date()
        scheduleSave()
    }

    func save(_ b: Batch) { upsert(b, in: \.batches) }
    func save(_ r: Recipe) { upsert(r, in: \.recipes) }
    func save(_ k: Bake) { upsert(k, in: \.bakes) }
    func save(_ l: Lesson) { upsert(l, in: \.lessons) }
    func save(_ p: Preset) { upsert(p, in: \.presets) }

    func remove(batch id: String) { tombstone(id, in: \.batches) }
    func remove(recipe id: String) { tombstone(id, in: \.recipes) }
    func remove(bake id: String) { tombstone(id, in: \.bakes) }
    func remove(lesson id: String) { tombstone(id, in: \.lessons) }
    func remove(preset id: String) { tombstone(id, in: \.presets) }
    /// Takes a removal back (the Undo of a toast), while the tombstone is still there.
    func restore(batch id: String) { untombstone(id, in: \.batches) }
    func restore(recipe id: String) { untombstone(id, in: \.recipes) }
    func restore(bake id: String) { untombstone(id, in: \.bakes) }
    func restore(lesson id: String) { untombstone(id, in: \.lessons) }
    func restore(preset id: String) { untombstone(id, in: \.presets) }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&data.settings)
        data.settings.modifiedAt = Date()
        data.savedAt = Date()
        scheduleSave()
    }

    // MARK: Photos — files in the Photos folder next to the data, so they sync with it

    /// Writes the picture as "<uuid>.jpg" in the Photos folder (shrunk to 1600 px on the long side when it can be read as
    /// a picture) and returns the file name to store in a record's `photos`. Empty = it could not be written.
    @discardableResult
    func addPhoto(_ jpeg: Data) -> String {
        let name = UUID().uuidString.lowercased() + ".jpg"
        let bytes = PhotoFile.shrink(jpeg) ?? jpeg
        guard (try? bytes.write(to: photosURL.appendingPathComponent(name), options: .atomic)) != nil else { return "" }
        return name
    }

    /// Where a picture lives. In iCloud a picture another device added may still be on the server: asking for it
    /// here starts its download, so it is there a moment later (the picture views look again by themselves).
    func photoURL(_ name: String) -> URL {
        let url = photosURL.appendingPathComponent(name)
        if inCloud, !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        return url
    }

    func removePhoto(_ name: String) {
        let url = photosURL.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        Task { await PhotoCache.shared.forget(url) }
    }

    // MARK: The toast — one line at the bottom, with Undo

    func showToast(_ text: String, undo: (() -> Void)? = nil) {
        toastWork?.cancel()
        withAnimation { toast = Toast(text: text, undo: undo) }
        toastWork = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.hideToast()
        }
    }
    func hideToast() { toastWork?.cancel(); withAnimation { toast = nil } }
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    let text: String
    let undo: (() -> Void)?
    static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
}

/// Tells the store when the shared file changes — written by another device through iCloud Drive, or by
/// the Mac/iPhone next to it. Also asks iCloud to fetch new versions.
final class FileWatcher: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    let presentedItemOperationQueue = OperationQueue()
    private let changed: () -> Void
    private let query = NSMetadataQuery()

    init(url: URL, changed: @escaping () -> Void) {
        presentedItemURL = url
        self.changed = changed
        super.init()
        presentedItemOperationQueue.maxConcurrentOperationCount = 1
        NSFileCoordinator.addFilePresenter(self)
        if url.path.contains("Mobile Documents") {
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, url.lastPathComponent)
            NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated), name: .NSMetadataQueryDidUpdate, object: query)
            NotificationCenter.default.addObserver(self, selector: #selector(queryUpdated), name: .NSMetadataQueryDidFinishGathering, object: query)
            DispatchQueue.main.async { self.query.start() }
        }
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
        query.stop()
    }

    func presentedItemDidChange() { changed() }

    /// iCloud's list changed (another device wrote, or a download finished): fetch the new version, then reload.
    /// The reload runs again a moment later, when the download has had time to land.
    @objc private func queryUpdated() {
        if let url = presentedItemURL { try? FileManager.default.startDownloadingUbiquitousItem(at: url) }
        changed()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.changed() }
    }
}

// MARK: - Settings of this device only (never synced)

enum AppearanceChoice: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { switch self { case .system: "Same as the device"; case .light: "Day"; case .dark: "Night" } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

/// What a jar's Timeline shows: the things you did, or the taste checks.
enum TimelineKind: String, Codable, CaseIterable, Identifiable {
    case did, taste
    var id: String { rawValue }
}

struct DeviceSettings: Codable, Equatable {
    var appearance: AppearanceChoice
    /// The burp alarm rings on this device. On by default on the iPhone (it is in the pocket), off on iPad and Mac.
    var burpAlarmHere: Bool
    /// The taste-test reminder rings on this device. Same defaults.
    var tasteAlarmHere: Bool
    var timelineKind: TimelineKind

    static var onPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
    static var standard: DeviceSettings {
        DeviceSettings(appearance: .system, burpAlarmHere: onPhone, tasteAlarmHere: onPhone, timelineKind: .did)
    }
    private static let key = "deviceSettings"
    static func load(from defaults: UserDefaults = .standard) -> DeviceSettings {
        guard let raw = defaults.data(forKey: key), let s = try? JSONDecoder().decode(DeviceSettings.self, from: raw) else { return .standard }
        return s
    }
    func save(to defaults: UserDefaults = .standard) {
        if let raw = try? JSONEncoder().encode(self) { defaults.set(raw, forKey: DeviceSettings.key) }
    }
}
