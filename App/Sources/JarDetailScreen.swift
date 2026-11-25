import SwiftUI

/// One jar: facts, burp block, plan, Timeline, outcome and actions.
struct JarDetailScreen: View {
    let batchID: String
    @EnvironmentObject var store: Store
    /// The head card's picture opened large.
    @State private var viewing: Int?

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
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                hero(b, status)
                if !b.photos.isEmpty { PhotoStrip(names: .constant(b.photos), editable: false, area: .jars) }
                facts(b)
                if status == .fermenting { JarBurpBlock(batch: b) }
                if !b.plan.isEmpty { JarPlanBlock(batch: b) }
                JarTimelineBlock(batch: b)
                if status == .fermenting { fridgeButton(b) }
                JarOutcomeBlock(batch: b)
                JarActionsBlock(batch: b)
            }
            .page(.jars)
        }
        .backdrop(.jars)
        .photoViewer(b.photos.map { store.photoURL($0) }, start: $viewing)
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

    /// The head card: the jar, its name, which day it is on, and how far it is to the next taste test.
    private func hero(_ b: Batch, _ status: JarStatus) -> some View {
        let days = Logic.dayNumber(b)
        return Hero(area: .jars) {
            HStack(alignment: .center, spacing: 12) {
                headPicture(b)
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.title).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let days { Text("Day \(days)").font(.title.weight(.heavy)).accessibilityIdentifier("jar-day") }
                        Pill(text: Logic.statusLabel(status), color: JarStyle.color(status))
                            .accessibilityIdentifier("jar-status")
                    }
                    Text(sinceLine(b)).font(.caption).foregroundStyle(Look.heroSoft)
                    if let due = Logic.nextCheckDue(b) {
                        ProgressLine(share: Logic.tasteProgress(b) ?? 0, area: .jars).padding(.top, 2)
                        Text(dueLine(b, due)).font(.caption.weight(.semibold))
                            .foregroundStyle(Logic.isCheckDue(b) ? Color.white : Look.heroSoft)
                            .accessibilityIdentifier("jar-due")
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// The jar's own first picture on the head card; the drawn jar when it has none.
    @ViewBuilder private func headPicture(_ b: Batch) -> some View {
        let frame = RoundedRectangle(cornerRadius: Look.tileRadius, style: .continuous)
        if let p = b.photos.first {
            Button { viewing = 0 } label: {
                PhotoImage(url: store.photoURL(p))
                    .frame(width: 60, height: 76)
                    .clipShape(frame)
                    .overlay(frame.stroke(Color.white.opacity(0.45), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Picture of the jar — see it large")
            .accessibilityIdentifier("jar-head-photo")
        } else {
            Mark(.jarBig).frame(width: 40, height: 40)
                .frame(width: 60, height: 76)
                .background(Color.white.opacity(0.17), in: frame)
                .accessibilityHidden(true)
        }
    }

    private func sinceLine(_ b: Batch) -> String {
        var t = b.startDate.isEmpty ? "" : "started \(Human.day(b.startDate))"
        if !b.movedToFridgeDate.isEmpty { t += (t.isEmpty ? "" : " \u{00b7} ") + "in the fridge since \(Human.day(b.movedToFridgeDate))" }
        return t
    }

    private func dueLine(_ b: Batch, _ due: String) -> String {
        if Logic.isCheckDue(b) {
            return due == Logic.isoDay(Date()) ? "Taste test due today" : "Taste test due since \(Human.day(due))"
        }
        return "Taste test \(Human.day(due))" + (Human.fromNow(due).map { " \u{00b7} \($0)" } ?? "")
    }

    /// The facts as small tiles (only those that are filled in), then the spices and the notes.
    @ViewBuilder private func facts(_ b: Batch) -> some View {
        let brine = Logic.computeBrinePercent(salt: b.saltGrams, water: b.waterMl)
        let count = [!b.vegetable.isEmpty, !b.form.isEmpty, brine != nil, b.roomTempC != nil, !b.lidType.isEmpty, !b.weightType.isEmpty, !b.loggedBy.isEmpty].filter { $0 }.count
        // Seven tiles stand 4 + 3 on a wide page, so none is left alone on a third row; an iPhone keeps three across.
        TileGrid(columns: count > 6 ? 4 : 3, compact: 3) {
            if !b.vegetable.isEmpty { Tile(label: "Vegetable", value: b.vegetable) }
            if !b.form.isEmpty { Tile(label: "Form", value: b.form) }
            if brine != nil { Tile(label: "Brine", value: JarStyle.brineText(b), valueColor: Logic.isBrineInRange(brine) ? Theme.ok : nil) }
            if let t = b.roomTempC { Tile(label: "Room", value: String(format: "%g °C", t)) }
            if !b.lidType.isEmpty { Tile(label: "Lid", value: b.lidType) }
            if !b.weightType.isEmpty { Tile(label: "Weight", value: b.weightType) }
            if !b.loggedBy.isEmpty { Tile(label: "Logged by", value: b.loggedBy) }
        }
        if !b.additions.isEmpty {
            FlowLayout(spacing: 4) { ForEach(b.additions, id: \.self) { Tag(text: $0, color: Theme.muted) } }
        }
        if !b.notes.isEmpty {
            Block(title: "Notes", area: .jars) {
                Text(b.notes).font(.subheadline).accessibilityIdentifier("jar-notes")
            }
        }
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
