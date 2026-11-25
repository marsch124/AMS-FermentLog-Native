import SwiftUI

/// One jar: facts, burp block, plan, Timeline, outcome and actions.
struct JarDetailScreen: View {
    let batchID: String
    @EnvironmentObject var store: Store

    var body: some View {
        if let b = store.data.batch(batchID) {
            content(b)
        } else {
            Text("This jar is no longer here.").foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg)
                .accessibilityIdentifier("jar-missing")
        }
    }

    private func content(_ b: Batch) -> some View {
        let status = Logic.batchStatus(b)
        let days = Logic.fermentDays(b)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                Pill(text: Logic.statusLabel(status) + (days.map { " · day \($0)" } ?? ""), color: JarStyle.color(status))
                    .accessibilityIdentifier("jar-status")
                if let due = Logic.nextCheckDue(b) {
                    Text("Taste test due \(due)").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Logic.isCheckDue(b) ? Theme.brandInk : Theme.muted)
                        .accessibilityIdentifier("jar-due")
                }
                if !b.photos.isEmpty { PhotoStrip(names: .constant(b.photos), editable: false, area: .jars) }
                facts(b)
                if status == .fermenting { JarBurpBlock(batch: b) }
                if !b.plan.isEmpty { JarPlanBlock(batch: b) }
                JarTimelineBlock(batch: b)
                if status == .fermenting { fridgeButton(b) }
                JarOutcomeBlock(batch: b)
                JarActionsBlock(batch: b)
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle(b.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Route.jarEdit(b.id)) { Text("Edit") }.accessibilityIdentifier("jar-edit")
            }
        }
    }

    private func facts(_ b: Batch) -> some View {
        let brine = Logic.computeBrinePercent(salt: b.saltGrams, water: b.waterMl)
        return VStack(alignment: .leading, spacing: 3) {
            Fact(name: "Vegetable", value: b.vegetable)
            Fact(name: "Form", value: b.form.isEmpty ? "—" : b.form)
            Fact(name: "Brine", value: JarStyle.brineText(b), valueColor: Logic.isBrineInRange(brine) ? Theme.ok : Theme.ink)
            Fact(name: "Room temp", value: b.roomTempC.map { String(format: "%g °C", $0) } ?? "—")
            Fact(name: "Started", value: b.startDate)
            Fact(name: "Lid", value: b.lidType.isEmpty ? "—" : b.lidType)
            Fact(name: "Weight", value: b.weightType.isEmpty ? "—" : b.weightType)
            if !b.loggedBy.isEmpty { Fact(name: "Logged by", value: b.loggedBy) }
            if !b.additions.isEmpty {
                FlowLayout(spacing: 4) { ForEach(b.additions, id: \.self) { Tag(text: $0, color: Theme.brandInk) } }
                    .padding(.top, 2)
            }
            if !b.notes.isEmpty {
                Text(b.notes).font(.subheadline).padding(.top, 2).accessibilityIdentifier("jar-notes")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fridgeButton(_ b: Batch) -> some View {
        Button("Move to the fridge") {
            var n = b; n.movedToFridgeDate = Logic.isoDay(Date()); store.save(n)
            Alarms.reschedule(store: store)
        }
        .buttonStyle(QuietButtonStyle(area: .jars))
        .accessibilityIdentifier("jar-to-fridge")
    }
}
