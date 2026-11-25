import Foundation
import UserNotifications

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
        if !clear.isEmpty { center.removeDeliveredNotifications(withIdentifiers: clear) }
    }

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
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let id = response.notification.request.content.userInfo["batchID"] as? String ?? ""
        await Alarms.handle(action: action, batchID: id)
    }
}
