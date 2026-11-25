import SwiftUI

/// The steps of a recipe in a form: each has a title, a time hint and a detail; dragged into order.
/// iPhone and iPad: the list's own handle. Mac: a grouped form cannot move its rows, so every step has its own
/// handle to drag (a plain drag gesture, no system drag and drop); let go over another step and it takes that
/// step's place (`Logic.moveStep`).
struct RecipeStepsSection: View {
    @Binding var steps: [RecipeStep]
    #if os(macOS)
    @State private var frames: [String: CGRect] = [:]   // where each step is on the screen
    @State private var dragging: String?                // the step being dragged
    @State private var over: String?                    // the step it is held over
    @State private var lift: CGFloat = 0                // how far it has been dragged
    #endif

    var body: some View {
        Section {
            #if os(macOS)
            ForEach($steps) { $s in
                let id = s.id
                HStack(alignment: .center, spacing: 8) {
                    fields($s)
                    Mark(.grip).frame(width: 18, height: 18).foregroundStyle(Area.recipes.color)
                        .padding(8)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                            .onChanged { v in
                                dragging = id
                                lift = v.translation.height
                                over = frames.first { $0.key != id && $0.value.minY <= v.location.y && v.location.y <= $0.value.maxY }?.key
                            }
                            .onEnded { _ in
                                if let target = over { steps = Logic.moveStep(steps, id: id, onto: target) }
                                dragging = nil; over = nil; lift = 0
                            })
                        .help("Drag to move this step")
                        .accessibilityIdentifier("recipe-step-grip-\(id)")
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                // the step the dragged one will replace is tinted
                .background(over == id ? Area.recipes.color.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { frames[id] = g.frame(in: .global) }
                        .onChange(of: g.frame(in: .global)) { _, f in frames[id] = f }
                })
                .offset(y: dragging == id ? lift : 0)
                .opacity(dragging == id ? 0.7 : 1)
                .zIndex(dragging == id ? 1 : 0)
            }
            #else
            ForEach($steps) { $s in fields($s) }
                .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            #endif
            Button("Add a step") { steps.append(RecipeStep()) }
                .buttonStyle(QuietButtonStyle(area: .recipes))
                .accessibilityIdentifier("recipe-add-step")
        } header: {
            SectionHeading("Method", area: .recipes)
        } footer: {
            #if os(macOS)
            Text("Drag a step by its handle (the three lines) onto another step — it takes that step’s place").font(.caption)
            #else
            Text("Drag a step to move it").font(.caption)
            #endif
        }
    }

    private func fields(_ s: Binding<RecipeStep>) -> some View {
        let id = s.wrappedValue.id
        return VStack(alignment: .leading, spacing: Theme.tight) {
            TextField("Step title", text: s.title).font(.body.weight(.semibold))
                .accessibilityIdentifier("recipe-step-title-\(id)")
            TextField("Time (for example 1 h)", text: s.time).font(.subheadline)
                .accessibilityIdentifier("recipe-step-time-\(id)")
            TextField("What to do", text: s.detail, axis: .vertical).font(.subheadline).lineLimit(1...6)
                .accessibilityIdentifier("recipe-step-detail-\(id)")
            Button("Remove") { steps.removeAll { $0.id == id } }
                .font(.caption).foregroundStyle(Theme.problem).buttonStyle(.borderless)
                .accessibilityIdentifier("recipe-step-remove-\(id)")
        }
    }
}
