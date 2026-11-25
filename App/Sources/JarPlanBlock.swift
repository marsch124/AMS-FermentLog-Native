import SwiftUI

/// The tick-off list of a jar that was started from a recipe.
struct JarPlanBlock: View {
    @EnvironmentObject var store: Store
    let batch: Batch

    var body: some View {
        let p = Logic.planProgress(batch)
        Block(title: "To do — from \(batch.recipeTitle.isEmpty ? "a recipe" : batch.recipeTitle)", area: .jars) {
            Text("\(p.done) of \(p.total) done").font(.subheadline).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("jar-plan-progress")
            ForEach(batch.plan) { step in row(step) }
            Text("Tick a step when you have done it — it is written into the Timeline with the time.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private func row(_ s: PlanStep) -> some View {
        let done = s.doneAt != nil
        return Button {
            var n = batch
            if done { Logic.untick(s.id, in: &n) } else { Logic.tick(s.id, in: &n, at: Date()) }
            store.save(n)
        } label: {
            HStack(alignment: .top, spacing: Theme.gap) {
                TickBox(on: done).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.title).font(.subheadline.weight(.semibold)).foregroundStyle(done ? Theme.muted : Theme.ink)
                    if !s.detail.isEmpty { Text(s.detail).font(.caption).foregroundStyle(Theme.muted) }
                    if !s.time.isEmpty { Text(s.time).font(.caption).foregroundStyle(Theme.muted) }
                    if let at = s.doneAt { Text("done \(Logic.clock(at))").font(.caption).foregroundStyle(Theme.ok) }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("jar-plan-\(s.id)")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

/// A round box to tick; a hand-drawn tick inside when it is done.
struct TickBox: View {
    let on: Bool
    var body: some View {
        ZStack {
            Circle().stroke(on ? Theme.ok : Theme.muted, lineWidth: 1.9)
            if on {
                Circle().fill(Theme.ok.opacity(0.16))
                GeometryReader { g in
                    Path { p in
                        let w = g.size.width, h = g.size.height
                        p.move(to: CGPoint(x: w * 0.28, y: h * 0.52))
                        p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.68))
                        p.addLine(to: CGPoint(x: w * 0.74, y: h * 0.34))
                    }
                    .stroke(Theme.ok, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .padding(2)
    }
}
