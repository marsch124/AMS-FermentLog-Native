import Foundation

/// The pure planner: which notifications should be waiting, from the data alone. No system calls, so it is tested.
enum AlarmPlan {
    struct Planned: Equatable {
        var id: String
        var fireAt: Date
        var title: String
        var body: String
        var category: String   // "BURP" or "TASTE"
        var batchID: String
    }

    static let burpPrefix = "burp."
    static let tastePrefix = "taste."

    /// 6.5: the short note that carries the burp sound after "Burped" was pressed on a reminder.
    struct BurpedNote: Equatable {
        var id: String
        var title: String
        var body: String
        var category: String
        var sound: String
    }
    static let burpedPrefix = "burped."
    static let burpedCategory = "BURPED"
    /// Seconds the note stays before it is taken away again.
    static let burpedNoteSeconds: Double = 8

    static func burpedNote(batchID: String, jarTitle: String, at: Date, sound: BurpSound) -> BurpedNote {
        BurpedNote(id: "\(burpedPrefix)\(batchID)", title: "Burped: \(jarTitle)",
                   body: "Written in the Timeline at \(Logic.clock(at)). Burp: \(sound.name).", category: burpedCategory, sound: sound.file)
    }

    static func plan(data: AppData, burpHere: Bool, tasteHere: Bool, now: Date, limit: Int = 60) -> [Planned] {
        var out: [Planned] = []
        let cal = Calendar.current
        for b in data.liveBatches {
            if burpHere {
                let morning = Logic.date(fromDay: Logic.isoDay(now), time: data.settings.burpMorning)
                for slot in Logic.burpSlots(for: b, settings: data.settings, from: now, days: 7) {
                    let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: slot)
                    let stamp = String(format: "%04d%02d%02d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
                    let isMorning = Logic.clock(slot) == (morning.map(Logic.clock) ?? data.settings.burpMorning)
                    let day = Logic.dayNumber(of: Logic.isoDay(slot), start: b.startDate) ?? 1
                    out.append(Planned(id: "\(burpPrefix)\(b.id).\(stamp)", fireAt: slot, title: "Burp: \(b.title)",
                                       body: "\(isMorning ? "Morning" : "Evening") burp \u{00B7} day \(day). Tap Burped when it is done.",
                                       category: "BURP", batchID: b.id))
                }
            }
            if tasteHere, let due = Logic.nextCheckDue(b), let at = Logic.date(fromDay: due, time: data.settings.burpMorning), at > now {
                let day = Logic.dayNumber(of: due, start: b.startDate) ?? 1
                out.append(Planned(id: "\(tastePrefix)\(b.id).\(due)", fireAt: at, title: "Taste test: \(b.title)",
                                   body: "Day \(day) \u{2014} time to taste and write a line.", category: "TASTE", batchID: b.id))
            }
        }
        out.sort { $0.fireAt == $1.fireAt ? $0.id < $1.id : $0.fireAt < $1.fireAt }
        return Array(out.prefix(max(0, limit)))
    }
}
