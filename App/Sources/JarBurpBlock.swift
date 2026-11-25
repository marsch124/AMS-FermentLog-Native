import SwiftUI

/// The burp button, when it last happened, and the jar's burp alarm switch.
struct JarBurpBlock: View {
    @EnvironmentObject var store: Store
    let batch: Batch

    var body: some View {
        Block(title: "Burp", area: .jars) {
            // One row when it fits (Mac, iPad), two on a narrow iPhone.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    burpRow
                    Spacer(minLength: 12)
                    Rectangle().fill(Theme.line).frame(width: 1, height: 34)
                    alarm
                }
                VStack(alignment: .leading, spacing: Theme.gap) { burpRow; alarm }
            }
        }
    }

    private var burpRow: some View {
        HStack(alignment: .center, spacing: Theme.gap) {
            Button("Burped") { burped() }
                .buttonStyle(PrimaryButtonStyle(area: .jars))
                .accessibilityIdentifier("jar-burped")
            Text(readout).font(.subheadline).foregroundStyle(Theme.muted)
                .fixedSize().accessibilityIdentifier("jar-burp-last")
        }
    }

    private var alarm: some View {
        VStack(alignment: .leading, spacing: 1) {
            Toggle("Burp alarm", isOn: Binding(get: { Logic.burpAlarmOn(batch) }, set: setAlarm))
                .toggleStyle(.switch).tint(Area.jars.color).fixedSize()
                .accessibilityIdentifier("jar-burp-alarm")
            Text(caption).font(.caption).foregroundStyle(Theme.muted).fixedSize()
        }
    }

    private var readout: String {
        guard let last = Logic.lastBurp(batch) else { return "Not burped yet" }
        let day = Logic.isoDay(last) == Logic.isoDay(Date()) ? "today" : Human.day(Logic.isoDay(last))
        return "Last burp: \(day) \(Logic.clock(last)) · \(Logic.burpsToday(batch, now: Date())) today"
    }

    private var caption: String {
        let s = store.data.settings
        var t = "Rings at \(s.burpMorning) and \(s.burpEvening)"
        if !store.device.burpAlarmHere { t += " \u{00b7} off for this device in Settings" }
        return t
    }

    private func burped() {
        let old = batch
        var n = batch
        let now = Date()
        Logic.burped(&n, at: now)
        store.save(n)
        if let sound = BurpSounds.next() { BurpPlayer.play(sound) }
        Alarms.reschedule(store: store)
        store.showToast("Burp logged \(Logic.clock(now))", undo: { store.save(old); Alarms.reschedule(store: store) })
    }

    private func setAlarm(_ on: Bool) {
        Task {
            if on { await Alarms.askPermission() }
            var n = batch
            n.burpAlarm = on
            store.save(n)
            Alarms.reschedule(store: store)
        }
    }
}
