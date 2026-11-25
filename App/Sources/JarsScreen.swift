import SwiftUI

/// Colour of a jar's status: Fermenting = brand, In the fridge = blue, Done = ok.
enum JarStyle {
    static let fridge = Color(day: 0x3A7CA5, night: 0x7DB7DC)
    static func color(_ s: JarStatus) -> Color {
        switch s { case .fermenting: Theme.brand; case .fridge: fridge; case .done: Theme.ok }
    }
    static func brineText(_ b: Batch) -> String {
        guard let v = Logic.computeBrinePercent(salt: b.saltGrams, water: b.waterMl) else { return "—" }
        return String(format: "%.1f%%", v)
    }
}

/// The list of jars: fermenting first, then in the fridge, then done.
struct JarsScreen: View {
    @EnvironmentObject var store: Store
    /// The tile he tapped: only those jars are shown. Not remembered — the list opens with all jars.
    @State private var showing: JarStatus? = PictureArgs.value("jarsShowing").flatMap(JarStatus.init(rawValue:))   // pictures: "-jarsShowing:fridge"

    var body: some View {
        let all = store.data.liveBatches
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                if all.isEmpty { empty } else { content(all) }
            }
            .page(.jars)
        }
        .backdrop(.jars)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !all.isEmpty && !DeviceSettings.onPhone {
                    NavigationLink(value: Route.jarNew) { Text("New jar") }.accessibilityIdentifier("jars-new")
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: Theme.gap) {
            Mark(.jarBig).frame(width: 64, height: 64).foregroundStyle(Area.jars.color)
            Text("No jars yet").font(.headline).foregroundStyle(Area.jars.color)
            Text("Start your first jar and begin learning what makes a great one.").font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            NavigationLink(value: Route.jarNew) { Text("Start a jar") }
                .buttonStyle(PrimaryButtonStyle(area: .jars))
                .accessibilityIdentifier("jars-start")
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }

    @ViewBuilder private func content(_ all: [Batch]) -> some View {
        let fermenting = sorted(all.filter { Logic.batchStatus($0) == .fermenting })
        let fridge = all.filter { Logic.batchStatus($0) == .fridge }.sorted { $0.startDate > $1.startDate }
        let done = all.filter { Logic.batchStatus($0) == .done }.sorted { $0.startDate > $1.startDate }
        let due = Logic.dueBatches(all)

        // Three tiles in the colours of the jar states (the same as the pills): Fermenting filled orange, In the fridge blue, Done green.
        // Each is a button: tap one and only those jars stay; a coloured outline marks the chosen one (like a chosen chip).
        TileGrid(columns: 3, compact: 3) {
            tile(fermenting.count, .fermenting, filled: true, tint: nil, id: "jars-filter-fermenting")
            tile(fridge.count, .fridge, filled: false, tint: JarStyle.fridge, id: "jars-filter-fridge")
            tile(done.count, .done, filled: false, tint: Theme.ok, id: "jars-filter-done")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("jars-stats")
        if let s = showing {
            HStack(spacing: Theme.gap) {
                Text("Showing only: \(Self.name(s))").font(.subheadline.weight(.semibold)).foregroundStyle(JarStyle.color(s))
                Button("Show all") { showing = nil }
                    .buttonStyle(QuietButtonStyle(area: .jars))
                    .accessibilityIdentifier("jars-filter-showall")
                Spacer(minLength: 0)
            }
        } else {
            Text("Tap a tile to show only those jars").font(.caption).foregroundStyle(Theme.muted)
                .accessibilityIdentifier("jars-filter-hint")
        }
        NavigationLink(value: Route.jarNew) { Text("Start a jar") }
            .buttonStyle(PrimaryButtonStyle(area: .jars))
            .accessibilityIdentifier("jars-start")
        if !due.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(due.count) \(due.count == 1 ? "jar is" : "jars are") due for a taste test").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.brandInk)
                Text(due.map(\.title).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted)
            }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("jars-due")
        }
        if showing == nil || showing == .fermenting { group("Fermenting", fermenting, .fermenting) }
        if showing == nil || showing == .fridge { group("In the fridge", fridge, .fridge) }
        if showing == nil || showing == .done { group("Done", done, .done) }
        if let s = showing, Logic.jars(all, showing: s).isEmpty {
            Text(Self.empty(s)).font(.subheadline).foregroundStyle(Theme.muted).padding(.top, Theme.tight)
                .accessibilityIdentifier("jars-filter-empty")
        }
    }

    private static func name(_ s: JarStatus) -> String {
        switch s { case .fermenting: "Fermenting"; case .fridge: "In the fridge"; case .done: "Done" }
    }
    private static func empty(_ s: JarStatus) -> String {
        switch s { case .fermenting: "No jars fermenting."; case .fridge: "No jars in the fridge."; case .done: "No jars done yet." }
    }

    /// One tile as a button: tap to show only those jars, tap again for all.
    private func tile(_ n: Int, _ s: JarStatus, filled: Bool, tint: Color?, id: String) -> some View {
        let on = showing == s
        let edge = s == .fermenting ? Theme.brandInk : (tint ?? Area.jars.color)
        return Button { showing = on ? nil : s } label: {
            StatTile(value: "\(n)", label: Self.name(s), area: .jars, filled: filled, tint: tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: Look.tileRadius + 3, style: .continuous)
                .stroke(on ? edge : Color.clear, lineWidth: 2)
                .padding(-3)
        }
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    /// Jars due for a taste test first (most overdue first), then newest first.
    private func sorted(_ list: [Batch]) -> [Batch] {
        list.sorted { a, b in
            let ad = Logic.isCheckDue(a), bd = Logic.isCheckDue(b)
            if ad != bd { return ad }
            if ad { return (Logic.nextCheckDue(a) ?? "") < (Logic.nextCheckDue(b) ?? "") }
            return a.startDate > b.startDate
        }
    }

    @ViewBuilder private func group(_ title: String, _ items: [Batch], _ s: JarStatus) -> some View {
        if !items.isEmpty {
            HStack(spacing: 6) {
                SectionHeading(title, .jars)
                Text("\(items.count)").font(.subheadline).foregroundStyle(Theme.muted)
            }
            .padding(.top, Theme.tight)
            ForEach(items) { b in
                NavigationLink(value: Route.jar(b.id)) { JarRow(batch: b) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("jar-row-\(b.id)")
            }
        }
    }
}
