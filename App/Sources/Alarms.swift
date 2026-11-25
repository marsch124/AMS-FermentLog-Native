import Foundation

// The burp alarm (morning and evening, with a "Burped" button on the notification) and the taste-test
// reminder. LANE "alarms-ai" fills the bodies; the signatures are a contract.
@MainActor
enum Alarms {
    enum Permission { case notAsked, allowed, refused }
    /// Called once at launch: sets the notification delegate and the "Burped" action.
    static func setUp(store: Store) {}
    static func permission() async -> Permission { .notAsked }
    /// Asks iOS/macOS for permission to notify (only when not asked yet). Returns true when allowed.
    @discardableResult static func askPermission() async -> Bool { false }
    /// Plans the coming notifications afresh from the data and this device's switches. Cheap; call after any change.
    static func reschedule(store: Store) {}
}
