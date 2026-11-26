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
    /// Pictures picked or taken for the line being written (already in the Photos folder), until Add (6.7).
    @State private var pending: [String] = []
    /// The photo story opened large at this picture (6.7).
    @State private var viewing: Int?

    private var kind: TimelineKind { store.device.timelineKind }
    private var canAdd: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pending.isEmpty }

    var body: some View {
        let entries = Logic.timelineEntries(batch)
        let story = Logic.photoStory(batch)
        let hasPictures = !story.isEmpty
        Block(title: "Timeline", area: .jars, note: entries.isEmpty ? nil : "\(entries.count) \(entries.count == 1 ? "line" : "lines") \u{00b7} tap a line to change it\(hasPictures ? ", a picture to see it large" : "")") {
            if entries.isEmpty {
                Text("Nothing logged yet.").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Logic.timelineDays(entries, start: batch.startDate)) { day in
                        DayHeading(day: day.day, date: day.date.isEmpty ? "No day" : Human.day(day.date), area: .jars)
                            .padding(.top, 6).padding(.bottom, 2)
                        ForEach(Array(day.lines.enumerated()), id: \.element.id) { i, l in
                            line(l, first: i == 0, last: i == day.lines.count - 1, story: story)
                        }
                    }
                }
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { kindSwitch; whenPicker; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: Theme.gap) { kindSwitch; whenPicker }
            }
            TextField(kind == .did ? "What did you do? One step per line…" : "How does it taste, smell and look?",
                      text: $text, axis: .vertical).lineLimit(1...8)
                .fieldBox()
                .accessibilityIdentifier("jar-timeline-text")
            PhotoStrip(names: $pending, editable: true, area: .jars, accessory: AnyView(addButton))
            Text(kind == .did
                 ? "One step per line — list numbers are removed. Pictures go with the last line; a picture alone is fine too."
                 : "A taste test also moves the next taste-test reminder. A picture alone is fine too.")
                .font(.caption).foregroundStyle(Theme.muted)
            if kind == .taste && AI.hasKey { voice }
        }
        .sheet(item: $editing) { e in JarLineEditor(batch: batch, entry: e) }
        .photoViewer(story.map { store.photoURL($0.name) }, start: $viewing, captions: story.map(\.caption))
        .onAppear {   // pictures
            if PictureArgs.has("sheetLine"), editing == nil { editing = Logic.timelineEntries(batch).first }
            if PictureArgs.has("sheetPhotoLine"), editing == nil { editing = Logic.timelineEntries(batch).first { !$0.photos.isEmpty } }
            if PictureArgs.has("openStory"), viewing == nil, !Logic.photoStory(batch).isEmpty { viewing = 1 }
        }
    }

    private var addButton: some View {
        Button("Add") { add() }
            .buttonStyle(PrimaryButtonStyle(area: .jars))
            .disabled(!canAdd)
            .accessibilityIdentifier("jar-timeline-add")
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

    /// One line on the rail: its time (only when it differs from the line above), a dot on the thin line, the words —
    /// and under them the line's pictures (6.7). A filled dot is something you did; a green ring with the word "Taste" is a taste test.
    /// Tap the words to change the line; tap a picture to open the jar's photo story there.
    private func line(_ l: TimelineLine, first: Bool, last: Bool, story: [StoryPhoto]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { editing = l.entry } label: { words(l) }
                .buttonStyle(.plain)
                .accessibilityIdentifier("jar-timeline-line-\(l.entry.id)")
            if !l.entry.photos.isEmpty { pictures(l.entry, story: story) }
        }
        .background(alignment: .topLeading) {
            if !(first && last) {
                Rectangle().fill(Area.jars.color.opacity(0.28)).frame(width: 2)
                    .frame(maxHeight: last ? 12 : .infinity, alignment: .top)
                    .padding(.top, first ? 10 : 0)
                    .padding(.leading, Self.timeWidth + Self.dotWidth / 2 - 1)
            }
        }
    }

    /// The line's pictures as small squares on the rail, under its words.
    private func pictures(_ e: TimelineEntry, story: [StoryPhoto]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.tight) {
                ForEach(Array(e.photos.enumerated()), id: \.offset) { i, name in
                    Button { viewing = story.firstIndex { $0.entryID == e.id && $0.name == name } } label: {
                        PhotoImage(url: store.photoURL(name))
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Picture \(i + 1) of this line — see it large")
                    .accessibilityIdentifier("jar-timeline-photo-\(e.id)-\(i)")
                }
            }
        }
        .padding(.leading, Self.timeWidth + Self.dotWidth)
        .padding(.bottom, 4)
    }

    private func words(_ l: TimelineLine) -> some View {
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
                } else if e.text.isEmpty {
                    Text("Picture").foregroundColor(Theme.muted)     // a line that is only pictures
                } else {
                    Text(e.text).foregroundColor(Theme.ink)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
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
        guard let n = Logic.addingLine(to: batch, kind: kind, text: text, photos: pending, date: Logic.isoDay(when), time: Logic.clock(when)) else { return }
        store.save(n)
        Alarms.reschedule(store: store)
        text = ""; pending = []; when = Date()
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
