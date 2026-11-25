import SwiftUI

/// The jar's diary: lines, and a form to add a "Did" step or a taste test.
struct JarTimelineBlock: View {
    @EnvironmentObject var store: Store
    let batch: Batch
    @State private var when = Date()
    @State private var text = ""
    @State private var editing: TimelineEntry?
    @State private var voiceText = ""
    @State private var voiceStatus = ""
    @State private var voiceBusy = false

    private var kind: TimelineKind { store.device.timelineKind }

    var body: some View {
        let entries = Logic.timelineEntries(batch)
        Block(title: "Timeline", area: .jars, note: entries.isEmpty ? nil : "\(entries.count) \(entries.count == 1 ? "line" : "lines") \u{00b7} tap a line to change it") {
            if entries.isEmpty {
                Text("Nothing logged yet.").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Logic.timelineDays(entries, start: batch.startDate)) { day in
                        DayHeading(day: day.day, date: day.date.isEmpty ? "No day" : Human.day(day.date), area: .jars)
                            .padding(.top, 6).padding(.bottom, 2)
                        ForEach(Array(day.lines.enumerated()), id: \.element.id) { i, l in
                            Button { editing = l.entry } label: {
                                line(l, first: i == 0, last: i == day.lines.count - 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("jar-timeline-line-\(l.entry.id)")
                        }
                    }
                }
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { kindSwitch; whenPicker; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: Theme.gap) { kindSwitch; whenPicker }
            }
            HStack(alignment: .bottom, spacing: Theme.gap) {
                TextField(kind == .did ? "What did you do? One step per line…" : "How does it taste, smell and look?",
                          text: $text, axis: .vertical).lineLimit(1...8)
                    .fieldBox()
                    .accessibilityIdentifier("jar-timeline-text")
                Button("Add") { add() }
                    .buttonStyle(PrimaryButtonStyle(area: .jars))
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("jar-timeline-add")
            }
            Text(kind == .did
                 ? "One step per line. Paste a whole list and every line becomes its own step — list numbers are removed."
                 : "A taste test also moves the next taste-test reminder.")
                .font(.caption).foregroundStyle(Theme.muted)
            if kind == .taste && AI.hasKey { voice }
        }
        .sheet(item: $editing) { e in JarLineEditor(batch: batch, entry: e) }
        .onAppear { if PictureArgs.has("sheetLine"), editing == nil { editing = Logic.timelineEntries(batch).first } }   // pictures
    }

    private var kindSwitch: some View {
        Segments(selection: Binding(get: { store.device.timelineKind }, set: { store.device.timelineKind = $0 }),
                 options: [(TimelineKind.did, "What I did"), (TimelineKind.taste, "Taste test")], area: .jars, id: "jar-timeline-kind")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("jar-timeline-kind")
    }

    private var whenPicker: some View {
        HStack(spacing: 6) {
            Text("When").font(.subheadline).foregroundStyle(Theme.muted)
            DatePicker("When", selection: $when).labelsHidden().fixedSize()
                .accessibilityIdentifier("jar-timeline-when")
        }
    }

    private static let timeWidth: CGFloat = 42
    private static let dotWidth: CGFloat = 22

    /// One line on the rail: its time (only when it differs from the line above), a dot on the thin line, the words.
    /// A filled dot is something you did; a green ring with the word "Taste" is a taste test.
    private func line(_ l: TimelineLine, first: Bool, last: Bool) -> some View {
        let e = l.entry
        return HStack(alignment: .top, spacing: 0) {
            Text(l.showTime ? e.time : " ").font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
                .frame(width: Self.timeWidth, alignment: .leading)
                .background(Text(" ").font(.subheadline).hidden())
            Text(" ").font(.subheadline).frame(width: Self.dotWidth)
                .overlay { dot(e.kind) }
            Group {
                if e.kind == .taste {
                    Text("Taste  ").fontWeight(.bold).foregroundColor(Theme.ok) + Text(e.text).foregroundColor(Theme.ink)
                } else {
                    Text(e.text).foregroundColor(Theme.ink)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
        .background(alignment: .topLeading) {
            if !(first && last) {
                Rectangle().fill(Area.jars.color.opacity(0.28)).frame(width: 2)
                    .frame(maxHeight: last ? 12 : .infinity, alignment: .top)
                    .padding(.top, first ? 10 : 0)
                    .padding(.leading, Self.timeWidth + Self.dotWidth / 2 - 1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func dot(_ kind: TimelineEntry.Kind) -> some View {
        ZStack {
            Circle().fill(Theme.surface).frame(width: 11, height: 11)
            if kind == .taste {
                Circle().stroke(Theme.ok, lineWidth: 2.5).frame(width: 9, height: 9)
            } else {
                Circle().fill(Area.jars.color).frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private var voice: some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            TextField("…or say it: “day 4, tangy and still crunchy”", text: $voiceText, axis: .vertical).lineLimit(2...4)
                .fieldBox().accessibilityIdentifier("jar-timeline-voice-text")
            Button(voiceBusy ? "Adding…" : "Add by voice") { addByVoice() }
                .buttonStyle(QuietButtonStyle(area: .jars))
                .disabled(voiceBusy || voiceText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("jar-timeline-voice")
            if !voiceStatus.isEmpty { Text(voiceStatus).font(.caption).foregroundStyle(Theme.muted) }
        }
    }

    private func add() {
        var n = batch
        let day = Logic.isoDay(when), time = Logic.clock(when)
        if kind == .did {
            let added = Logic.stepsFromText(text, date: day, time: time)
            guard !added.isEmpty else { return }
            n.steps += added
        } else {
            let note = text.replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !note.isEmpty else { return }
            n.checkIns.append(CheckIn(date: day, time: time, tasteNote: note))
        }
        store.save(n)
        Alarms.reschedule(store: store)
        text = ""; when = Date()
    }

    private func addByVoice() {
        voiceBusy = true; voiceStatus = "Adding…"
        let b = batch, said = voiceText
        Task {
            do {
                let ci = try await AI.buildCheckIn(from: said, startDate: b.startDate)
                var n = b; n.checkIns.append(ci); store.save(n)
                Alarms.reschedule(store: store)
                voiceText = ""; voiceStatus = ""
            } catch { voiceStatus = error.localizedDescription }
            voiceBusy = false
        }
    }
}
