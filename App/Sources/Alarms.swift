import Foundation
import UserNotifications
#if os(iOS)
import UIKit
#endif

// The burp alarm (morning and evening, with a "Burped" button on the notification) and the taste-test
// reminder. The plan itself is AlarmPlan (pure, tested); this file talks to the system.
@MainActor
enum Alarms {
    enum Permission { case notAsked, allowed, refused }

    /// A jar route that arrived (notification tap) before any screen was listening; the app picks it up on becoming active.
    static var pendingRoute: Route?
    fileprivate static weak var store: Store?
    private static let delegate = AlarmDelegate()
    private static var didSetUp = false
    private static var work: Task<Void, Never>?

    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }
    private static var quiet: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    /// Called once at launch: sets the notification delegate and the "Burped" action.
    static func setUp(store: Store) {
        self.store = store
        guard !quiet, !didSetUp else { return }
        didSetUp = true
        let burped = UNNotificationAction(identifier: "BURPED", title: "Burped", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "BURP", actions: [burped], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: "TASTE", actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: AlarmPlan.burpedCategory, actions: [], intentIdentifiers: [], options: []),
        ])
        center.delegate = delegate
    }

    static func permission() async -> Permission {
        guard !quiet else { return .notAsked }
        let s = await center.notificationSettings().authorizationStatus
        switch s {
        case .notDetermined: return .notAsked
        case .denied: return .refused
        default: return .allowed
        }
    }

    /// Asks iOS/macOS for permission to notify (only when not asked yet). Returns true when allowed.
    @discardableResult static func askPermission() async -> Bool {
        guard !quiet else { return false }
        switch await permission() {
        case .allowed: return true
        case .refused: return false
        case .notAsked:
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if ok, let s = store { reschedule(store: s) }
            return ok
        }
    }

    /// Plans the coming notifications afresh from the data and this device's switches. Cheap; call after any change.
    static func reschedule(store: Store) {
        guard !quiet, !store.isTestRun else { return }
        work?.cancel()
        work = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await apply(store: store)
        }
    }

    private static func apply(store: Store) async {
        let plan = AlarmPlan.plan(data: store.data, burpHere: store.device.burpAlarmHere, tasteHere: store.device.tasteAlarmHere, now: Date())
        // The first time something should ring on this device, the system asks once whether it may.
        // (An alarm that is "on" but may never ring would be a silent failure.)
        if !plan.isEmpty, await permission() == .notAsked { await askPermission() }
        guard await permission() == .allowed else { return }
        let wanted = Set(plan.map(\.id))
        let pending = await center.pendingNotificationRequests()
        let have = Set(pending.map(\.identifier))
        let stale = pending.map(\.identifier).filter { ($0.hasPrefix(AlarmPlan.burpPrefix) || $0.hasPrefix(AlarmPlan.tastePrefix)) && !wanted.contains($0) }
        if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stale) }
        for p in plan where !have.contains(p.id) {
            let content = UNMutableNotificationContent()
            content.title = p.title; content.body = p.body
            content.sound = .default
            content.categoryIdentifier = p.category
            content.userInfo = ["batchID": p.batchID]
            content.threadIdentifier = p.batchID
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: p.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: p.id, content: content, trigger: trigger))
        }
        // A burp already logged for a jar: its ringing burp notifications are no longer needed.
        let delivered = await center.deliveredNotifications()
        var clear: [String] = []
        for n in delivered where n.request.identifier.hasPrefix(AlarmPlan.burpPrefix) {
            guard let id = n.request.content.userInfo["batchID"] as? String, let b = store.data.batch(id), let last = Logic.lastBurp(b) else { continue }
            if last >= n.date { clear.append(n.request.identifier) }
        }
        // A "Burped" note (the one that carries the burp sound) left over from an earlier burp.
        let oldNotes = delivered.filter { $0.request.identifier.hasPrefix(AlarmPlan.burpedPrefix) && $0.date < Date().addingTimeInterval(-AlarmPlan.burpedNoteSeconds) }
        clear += oldNotes.map(\.request.identifier)
        if !clear.isEmpty { center.removeDeliveredNotifications(withIdentifiers: clear) }
    }

    /// 6.5: "Burped" on a reminder plays a burp (one of the ten that are on, at random). The sound rides on a short note, because a notification's own
    /// sound is the one thing that plays reliably while the app stays closed. The note goes away again by itself;
    /// while the app is open it is sound only (see the delegate).
    private static func playBurp(batchID: String, jarTitle: String) async {
        guard let sound = BurpSounds.next() else { return }      // all burps off: quiet, as before 6.5
        let note = AlarmPlan.burpedNote(batchID: batchID, jarTitle: jarTitle, at: Date(), sound: sound)
        let content = UNMutableNotificationContent()
        content.title = note.title; content.body = note.body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(note.sound))
        content.categoryIdentifier = note.category
        content.threadIdentifier = batchID
        content.userInfo = ["batchID": batchID]
        holdOn()
        try? await center.add(UNNotificationRequest(identifier: note.id, content: content, trigger: nil))
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AlarmPlan.burpedNoteSeconds * 1_000_000_000))
            center.removeDeliveredNotifications(withIdentifiers: [note.id])
            letGo()
        }
    }

    #if os(iOS)
    /// Keeps the app awake in the background for the few seconds until the note is taken away.
    private static var noteTask: UIBackgroundTaskIdentifier = .invalid
    private static func holdOn() {
        guard noteTask == .invalid else { return }
        noteTask = UIApplication.shared.beginBackgroundTask(withName: "burped-note") {
            MainActor.assumeIsolated { Alarms.letGo() }
        }
    }
    private static func letGo() {
        guard noteTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(noteTask)
        noteTask = .invalid
    }
    #else
    private static func holdOn() {}
    private static func letGo() {}
    #endif

    /// Hands a waiting route to whichever screen is listening, then forgets it.
    static func deliverPendingRoute() {
        guard let r = pendingRoute else { return }
        pendingRoute = nil
        NotificationCenter.default.post(name: .openRoute, object: r)
    }

    fileprivate static func handle(action: String, batchID: String) async {
        guard let store else { return }
        if action == "BURPED" {
            guard var b = store.data.batch(batchID) else { return }
            Logic.burped(&b, at: Date())
            store.save(b)
            store.saveNow()          // on disk before the system suspends the app
            await apply(store: store)
            await playBurp(batchID: b.id, jarTitle: b.title)
        } else if action == UNNotificationDefaultActionIdentifier, !batchID.isEmpty {
            pendingRoute = .jar(batchID)
            // Give a window that is still starting a moment to begin listening, then offer it.
            try? await Task.sleep(nanoseconds: 600_000_000)
            deliverPendingRoute()
        }
    }
}

/// Receives the taps and the "Burped" button; kept alive by `Alarms`.
final class AlarmDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The burp after "Burped" needs no banner while the app is on the screen: just the sound.
        notification.request.content.categoryIdentifier == AlarmPlan.burpedCategory ? [.sound] : [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let id = response.notification.request.content.userInfo["batchID"] as? String ?? ""
        await Alarms.handle(action: action, batchID: id)
    }
}
