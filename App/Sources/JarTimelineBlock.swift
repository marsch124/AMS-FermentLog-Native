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
        Block(title: "Timeline", area: .jars) {
            if entries.isEmpty {
                Text("Nothing logged yet.").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                ForEach(entries) { e in
                    Button { editing = e } label: { line(e) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("jar-timeline-line-\(e.id)")
                }
                Text("Tap a line to change it").font(.caption).foregroundStyle(Theme.muted)
            }
            Divider()
            Picker("Add", selection: Binding(get: { store.device.timelineKind }, set: { store.device.timelineKind = $0 })) {
                Text("What I did").tag(TimelineKind.did)
                Text("Taste test").tag(TimelineKind.taste)
            }
            .pickerStyle(.segmented).labelsHidden()
            .accessibilityIdentifier("jar-timeline-kind")
            DatePicker("When", selection: $when).accessibilityIdentifier("jar-timeline-when")
            TextField(kind == .did ? "What did you do? One step per line…" : "How does it taste, smell and look?",
                      text: $text, axis: .vertical).lineLimit(3...8)
                .fieldBox()
                .accessibilityIdentifier("jar-timeline-text")
            Text(kind == .did
                 ? "One step per line. Paste a whole list and every line becomes its own step — list numbers are removed."
                 : "A taste test also moves the next taste-test reminder.")
                .font(.caption).foregroundStyle(Theme.muted)
            Button("Add") { add() }
                .buttonStyle(PrimaryButtonStyle(area: .jars))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("jar-timeline-add")
            if kind == .taste && AI.hasKey { voice }
        }
        .sheet(item: $editing) { e in JarLineEditor(batch: batch, entry: e) }
        .onAppear { if PictureArgs.has("sheetLine"), editing == nil { editing = Logic.timelineEntries(batch).first } }   // pictures
    }

    private func line(_ e: TimelineEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.gap) {
            VStack(alignment: .leading, spacing: 2) {
                Text([e.date, e.time].filter { !$0.isEmpty }.joined(separator: " ")).font(.caption).foregroundStyle(Theme.muted)
                Tag(text: e.kind == .did ? "Did" : "Taste", color: e.kind == .did ? Theme.brand : Theme.ok)
            }
            .frame(minWidth: 96, alignment: .leading)
            Text(e.text).font(.subheadline).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
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
