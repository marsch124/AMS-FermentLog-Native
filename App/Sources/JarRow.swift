import SwiftUI

/// One jar in the list.
struct JarRow: View {
    @EnvironmentObject var store: Store
    let batch: Batch

    var body: some View {
        let s = Logic.batchStatus(batch)
        let days = Logic.dayNumber(batch)
        HStack(spacing: Theme.gap) {
            thumb
            VStack(alignment: .leading, spacing: 3) {
                Text(batch.title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                HStack(spacing: 6) {
                    Pill(text: Logic.statusLabel(s) + (days.map { " · day \($0)" } ?? ""), color: JarStyle.color(s))
                    Text(JarStyle.brineText(batch)).font(.caption).foregroundStyle(Theme.muted)
                    if let r = Logic.overallRating(batch) { Stars(value: r).font(.caption) }
                }
                if Logic.isCheckDue(batch) || Logic.burpAlarmOn(batch) {
                    HStack(spacing: 4) {
                        if Logic.isCheckDue(batch) { Tag(text: "Taste test due", color: Theme.brandInk) }
                        if Logic.burpAlarmOn(batch) { Tag(text: "Burp alarm on", color: Theme.muted) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var thumb: some View {
        if let p = Logic.headPhoto(batch) {     // 6.7: the newest Timeline picture, else the jar's own first
            PhotoImage(url: store.photoURL(p)).frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Mark(.jar).frame(width: 28, height: 28).foregroundStyle(Area.jars.color)
                .frame(width: 48, height: 48).background { TileBack(area: .jars) }
        }
    }
}
