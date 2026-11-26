import SwiftUI

/// Change one Timeline line: its day, time, words and pictures — or delete it.
struct JarLineEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let batch: Batch
    let entry: TimelineEntry
    @State private var day = Date()
    @State private var time = Date()
    @State private var hasTime = true
    @State private var words = ""
    @State private var photos: [String] = []
    @State private var askDelete = false
    /// A line needs words or at least one picture (6.7).
    private var canSave: Bool { !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Tag(text: entry.kind == .did ? "Did" : "Taste", color: entry.kind == .did ? Theme.brand : Theme.ok); Spacer() }
                    DatePicker("Day", selection: $day, displayedComponents: .date).accessibilityIdentifier("jar-line-day")
                    Toggle("Has a time", isOn: $hasTime).accessibilityIdentifier("jar-line-has-time")
                    if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute).accessibilityIdentifier("jar-line-time") }
                    TextField("Words", text: $words, axis: .vertical).lineLimit(2...8).accessibilityIdentifier("jar-line-text")
                }
                Section {
                    PhotoStrip(names: $photos, editable: true, area: .jars)
                } header: { SectionHeading("Pictures", area: .jars) }
                Section {
                    Button("Delete this line") { askDelete = true }.foregroundStyle(Theme.problem).accessibilityIdentifier("jar-line-delete")
                }
            }
            .formStyle(.grouped)
            .tint(Area.jars.color)
            .navigationTitle("Change this line")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .cancelSave(area: .jars, canSave: canSave, onCancel: { dismiss() }, onSave: save)
            .confirmationDialog("Delete this line?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Delete this line", role: .destructive) { delete() }
                Button("Keep it", role: .cancel) {}
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
        .onAppear {
            day = Logic.date(fromDay: entry.date) ?? Date()
            if let t = Logic.date(fromDay: entry.date, time: entry.time), !entry.time.isEmpty { time = t } else { hasTime = entry.time.isEmpty ? false : true }
            words = entry.text
            photos = entry.photos
        }
    }

    private func save() {
        var n = batch
        let d = Logic.isoDay(day), t = hasTime ? Logic.clock(time) : ""
        let w = words.replacingOccurrences(of: "\\s*\\n\\s*", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty || !photos.isEmpty else { return }
        if entry.kind == .did, let i = n.steps.firstIndex(where: { $0.id == entry.id }) {
            n.steps[i].date = d; n.steps[i].time = t; n.steps[i].text = w; n.steps[i].photos = photos
        } else if let i = n.checkIns.firstIndex(where: { $0.id == entry.id }) {
            n.checkIns[i].date = d; n.checkIns[i].time = t; n.checkIns[i].tasteNote = w; n.checkIns[i].photos = photos
        }
        store.save(n)
        Alarms.reschedule(store: store)
        dismiss()
    }

    private func delete() {
        var n = batch
        n.steps.removeAll { $0.id == entry.id }
        n.checkIns.removeAll { $0.id == entry.id }
        store.save(n)
        Alarms.reschedule(store: store)
        dismiss()
    }
}
