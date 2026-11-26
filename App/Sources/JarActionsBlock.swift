import SwiftUI

/// Duplicate, Share, Save steps as a recipe, AI tips.
struct JarActionsBlock: View {
    @EnvironmentObject var store: Store
    let batch: Batch
    @State private var recipeDraft: Recipe?
    @State private var openRecipe = false
    @State private var tips = ""
    @State private var tipsStatus = ""
    @State private var tipsBusy = false

    private var hasDidLines: Bool { Logic.timelineEntries(batch).contains { $0.kind == .did && !$0.isBurp } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            FlowLayout(spacing: Theme.gap) {
                Button("Duplicate") { duplicate() }
                    .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-duplicate")
                ShareLink(item: JarSummary.text(batch), subject: Text("FermentLog jar")) { Text("Share") }
                    .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-share")
                if hasDidLines {
                    Button("Save steps as a recipe") {
                        recipeDraft = Logic.recipe(fromStepsOf: batch, now: Date()); openRecipe = true
                    }
                    .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-steps-to-recipe")
                }
                if AI.hasKey {
                    Button(tipsBusy ? "Thinking…" : "AI tips") { getTips() }.disabled(tipsBusy)
                        .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-ai-tips")
                }
            }
            if !tipsStatus.isEmpty { Text(tipsStatus).font(.caption).foregroundStyle(Theme.muted) }
            if !tips.isEmpty {
                Block(title: "Suggested tips", area: .jars) {
                    Text(tips).font(.subheadline)
                    HStack {
                        Button("Add to notes") { addToNotes() }
                            .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-tips-add")
                        Button("Dismiss") { tips = "" }
                            .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-tips-dismiss")
                    }
                }
            }
        }
        .navigationDestination(isPresented: $openRecipe) {
            if let d = recipeDraft { RecipeFormScreen(recipeID: nil, draft: d) }
        }
    }

    private func duplicate() {
        let dup = Logic.duplicateBatch(batch)
        store.save(dup)
        NotificationCenter.default.post(name: .openRoute, object: Route.jar(dup.id))
    }

    private func getTips() {
        tipsBusy = true; tipsStatus = ""
        let b = batch
        Task {
            do {
                let t = try await AI.batchTips(b)
                if t.isEmpty { tipsStatus = "No tips this time — try again." } else { tips = t }
            } catch { tipsStatus = error.localizedDescription }
            tipsBusy = false
        }
    }

    private func addToNotes() {
        var n = batch
        n.notes = n.notes.isEmpty ? tips : "\(n.notes)\n\n\(tips)"
        store.save(n)
        tips = ""
    }
}

/// The plain-words summary of a jar that Share sends (same lines as the web's).
enum JarSummary {
    static func text(_ b: Batch) -> String {
        func g(_ d: Double?) -> String { d.map { String(format: "%g", $0) } ?? "—" }
        var lines = [
            "\(b.title) — \(Logic.statusLabel(Logic.batchStatus(b)))",
            "Vegetable: \(b.vegetable)",
            "Brine: \(JarStyle.brineText(b)) (\(g(b.saltGrams))g salt / \(g(b.waterMl))ml water)",
            "Room temp: \(b.roomTempC.map { String(format: "%g", $0) } ?? "—")°C",
            "Equipment: \(b.vesselType.isEmpty ? "—" : b.vesselType), \(b.weightType.isEmpty ? "—" : b.weightType) weight, \(b.lidType.isEmpty ? "—" : b.lidType)",
            "Started: \(b.startDate)" + (b.movedToFridgeDate.isEmpty ? "" : " · fridge: \(b.movedToFridgeDate)"),
        ]
        if let r = Logic.overallRating(b) { lines.append("Result: \(Logic.ratingStars(r))" + (b.outcome?.success == true ? " (success)" : "")) }
        if !b.notes.isEmpty { lines.append("Notes: \(b.notes)") }
        let tl = Logic.timelineEntries(b)
        if !tl.isEmpty {
            lines += ["", "Timeline:"]
            lines += tl.map { "\([$0.date, $0.time].filter { !$0.isEmpty }.joined(separator: " ")) · \($0.kind == .did ? "Did" : "Taste") · \(Logic.lineWords($0))" }
        }
        return lines.joined(separator: "\n")
    }
}
