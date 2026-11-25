import Foundation

/// One day of a jar's Timeline: its heading (the day, and which day of the ferment it is) and its lines.
struct TimelineDay: Equatable, Identifiable {
    var date: String
    /// Days since the jar was started, counted as everywhere in the app (the start day is day 0); nil for a line dated before the start.
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
    /// Groups the Timeline by day, in order, so the day is written once as a heading and a shared time only once.
    static func timelineDays(_ entries: [TimelineEntry], start: String) -> [TimelineDay] {
        var out: [TimelineDay] = []
        for e in entries {
            if out.last?.date != e.date {
                let n: Int? = (!e.date.isEmpty && !start.isEmpty && e.date >= start) ? daysBetween(start: start, end: e.date) : nil
                out.append(TimelineDay(date: e.date, day: n, lines: []))
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
