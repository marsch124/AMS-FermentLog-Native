import Foundation

// The optional AI helper (his own key). LANE "alarms-ai" fills the bodies; the signatures are a contract.
enum AI {
    struct Problem: LocalizedError { let text: String; var errorDescription: String? { text } }
    /// The key lives in the Keychain of this device (never in the synced file).
    static var hasKey: Bool { !key.isEmpty }
    static var key: String { get { "" } set { _ = newValue } }
    static func buildRecipe(from text: String) async throws -> Recipe { throw Problem(text: "Not built yet.") }
    static func improveRecipe(_ recipe: Recipe, request: String) async throws -> Recipe { throw Problem(text: "Not built yet.") }
    static func buildBatch(from text: String) async throws -> Batch { throw Problem(text: "Not built yet.") }
    static func buildCheckIn(from text: String, startDate: String) async throws -> CheckIn { throw Problem(text: "Not built yet.") }
    static func batchTips(_ batch: Batch) async throws -> String { throw Problem(text: "Not built yet.") }
    static func buildBake(from text: String, recipes: [Recipe]) async throws -> Bake { throw Problem(text: "Not built yet.") }
}
