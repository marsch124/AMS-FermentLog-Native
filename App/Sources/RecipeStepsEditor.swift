import SwiftUI

/// The steps of a recipe in a form: each has a title, a time hint and a detail; dragged into order.
struct RecipeStepsSection: View {
    @Binding var steps: [RecipeStep]
    var body: some View {
        Section {
            ForEach($steps) { $s in
                VStack(alignment: .leading, spacing: Theme.tight) {
                    TextField("Step title", text: $s.title).font(.body.weight(.semibold))
                        .accessibilityIdentifier("recipe-step-title-\(s.id)")
                    TextField("Time (for example 1 h)", text: $s.time).font(.subheadline)
                        .accessibilityIdentifier("recipe-step-time-\(s.id)")
                    TextField("What to do", text: $s.detail, axis: .vertical).font(.subheadline).lineLimit(1...6)
                        .accessibilityIdentifier("recipe-step-detail-\(s.id)")
                    let id = s.id
                    Button("Remove") { steps.removeAll { $0.id == id } }
                        .font(.caption).foregroundStyle(Theme.problem).buttonStyle(.borderless)
                        .accessibilityIdentifier("recipe-step-remove-\(s.id)")
                }
            }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            Button("Add a step") { steps.append(RecipeStep()) }
                .buttonStyle(QuietButtonStyle(area: .recipes))
                .accessibilityIdentifier("recipe-add-step")
        } header: {
            SectionHeading("Method", area: .recipes)
        } footer: {
            Text("Drag a step to move it").font(.caption)
        }
    }
}
