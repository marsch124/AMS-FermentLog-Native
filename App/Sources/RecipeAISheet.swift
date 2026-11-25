import SwiftUI

/// A small sheet: write what you want, the AI answers, the caller uses the result. Nothing is saved here.
struct RecipeAISheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let prompt: String
    let button: String
    let id: String
    let run: (String) async throws -> Void
    @State private var text = ""
    @State private var working = false
    @State private var problem = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Text(prompt).font(.subheadline).foregroundStyle(Theme.muted)
                TextEditor(text: $text).frame(minHeight: 120).padding(4)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("\(id)-text")
                if !problem.isEmpty { Text(problem).font(.caption).foregroundStyle(Theme.problem) }
                Button(working ? "Working\u{2026}" : button) {
                    working = true; problem = ""
                    Task {
                        do { try await run(text); dismiss() } catch { problem = error.localizedDescription }
                        working = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle(area: .recipes))
                .disabled(working || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("\(id)-go")
                Spacer(minLength: 0)
            }
            .padding(12).background(Theme.bg)
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("\(id)-cancel") } }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}
