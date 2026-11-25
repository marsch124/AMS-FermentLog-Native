import Foundation

/// How the Jars list orders each group (6.4); remembered per device.
enum JarSort: String {
    case startDate, name
    /// In the fridge and Done: newest start first (no taste test is due there), or A to Z.
    var fridgeAndDone: JarSort { self }
}

/// One day of a jar's Timeline: its heading (the day, and which day of the ferment it is) and its lines.
struct TimelineDay: Equatable, Identifiable {
    var date: String
    /// Which day of the ferment this is, counted as everywhere in the app (the start day is Day 1); nil for a line dated before the start.
    var day: Int?
    var lines: [TimelineLine]
    var id: String { date }
}

/// One line of the Timeline, and whether its time is written (only when it differs from the line above on the same day).
struct TimelineLine: Equatable, Identifiable {
    var entry: TimelineEntry
    var showTime: Bool
    var id: String { entry.id }
}

extension Logic {
    /// The jars whose name or vegetable contains `text` (big/small letters and accents ignored); all of them for empty text (6.4).
    static func jars(_ batches: [Batch], matching text: String) -> [Batch] {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return batches }
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return batches.filter { $0.title.range(of: t, options: opts) != nil || $0.vegetable.range(of: t, options: opts) != nil }
    }

    /// One group of the Jars list in the chosen order (6.4).
    /// Start date: jars due for a taste test first (the most overdue first), then the newest start.
    /// Name: A to Z the way the device's language sorts (Swedish puts Å Ä Ö after Z), big/small letters ignored, "2" before "10".
    static func sortJars(_ batches: [Batch], by sort: JarSort, today: Date = Date()) -> [Batch] {
        switch sort {
        case .name:
            return batches.sorted { a, b in
                let r = a.title.localizedStandardCompare(b.title)
                return r == .orderedSame ? a.startDate > b.startDate : r == .orderedAscending
            }
        case .startDate:
            return batches.sorted { a, b in
                let ad = isCheckDue(a, today: today), bd = isCheckDue(b, today: today)
                if ad != bd { return ad }
                if ad { return (nextCheckDue(a) ?? "") < (nextCheckDue(b) ?? "") }
                return a.startDate > b.startDate
            }
        }
    }

    /// The jars the Jars list shows: all of them, or only one state when a tile was tapped (6.3).
    static func jars(_ batches: [Batch], showing: JarStatus?) -> [Batch] {
        guard let showing else { return batches }
        return batches.filter { batchStatus($0) == showing }
    }

    /// Groups the Timeline by day, in order, so the day is written once as a heading and a shared time only once.
    static func timelineDays(_ entries: [TimelineEntry], start: String) -> [TimelineDay] {
        var out: [TimelineDay] = []
        for e in entries {
            if out.last?.date != e.date {
                out.append(TimelineDay(date: e.date, day: dayNumber(of: e.date, start: start), lines: []))
            }
            let above = out[out.count - 1].lines.last?.entry.time
            out[out.count - 1].lines.append(TimelineLine(entry: e, showTime: !e.time.isEmpty && e.time != above))
        }
        return out
    }

    /// How far a fermenting jar is from its last taste test (or its start) to the next one: 0…1; nil when no taste test is planned.
    static func tasteProgress(_ b: Batch, now: Date = Date()) -> Double? {
        guard nextCheckDue(b) != nil, b.remindEveryDays > 0 else { return nil }
        let base = b.checkIns.map(\.date).filter { !$0.isEmpty }.max() ?? b.startDate
        guard let gone = daysBetween(start: base, end: nil, now: now) else { return nil }
        return min(1, Double(gone) / Double(b.remindEveryDays))
    }
}
