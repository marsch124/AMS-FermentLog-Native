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
        TileGrid(columns: 3, compact: 3) {
            StatTile(value: "\(fermenting.count)", label: "Fermenting", area: .jars, filled: true)
            StatTile(value: "\(fridge.count)", label: "In the fridge", area: .jars, tint: JarStyle.fridge)
            StatTile(value: "\(done.count)", label: "Done", area: .jars, tint: Theme.ok)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("jars-stats")
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
        group("Fermenting", fermenting, .fermenting)
        group("In the fridge", fridge, .fridge)
        group("Done", done, .done)
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
