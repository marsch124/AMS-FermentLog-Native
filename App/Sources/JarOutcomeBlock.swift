import SwiftUI

/// The verdict of a jar, and the form to record or change it.
struct JarOutcomeBlock: View {
    @EnvironmentObject var store: Store
    let batch: Batch
    @State private var showForm = PictureArgs.has("sheetOutcome")   // pictures: opens the form at once

    var body: some View {
        Block(title: "Outcome", area: .jars) {
            if let o = batch.outcome, o.recorded {
                Text(o.success ? "Success" : "Didn’t work out")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(o.success ? Theme.ok : Theme.problem)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((o.success ? Theme.ok : Theme.problem).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("jar-verdict")
                Fact(name: "Taste", value: stars(o.taste))
                Fact(name: "Sourness", value: stars(o.sourness))
                Fact(name: "Crunch", value: stars(o.crunch))
                Fact(name: "Overall", value: stars(o.overall))
                if !o.problems.isEmpty {
                    FlowLayout(spacing: 4) { ForEach(o.problems, id: \.self) { Tag(text: $0, color: Theme.problem) } }
                }
                Button("Edit outcome") { showForm = true }
                    .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-outcome-edit")
            } else {
                Text("No verdict recorded yet.").font(.subheadline).foregroundStyle(Theme.muted)
                Button("Record outcome") { showForm = true }
                    .buttonStyle(PrimaryButtonStyle(area: .jars)).accessibilityIdentifier("jar-outcome-record")
            }
        }
        .sheet(isPresented: $showForm) { JarOutcomeForm(batch: batch) }
    }

    private func stars(_ n: Int?) -> String { Logic.ratingStars(n.map(Double.init)) }
}

struct JarOutcomeForm: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let batch: Batch
    @State private var o = Outcome()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StarRating(label: "Taste", value: $o.taste, area: .jars, id: "outcome-taste")
                    StarRating(label: "Sourness", value: $o.sourness, area: .jars, id: "outcome-sourness")
                    StarRating(label: "Crunch", value: $o.crunch, area: .jars, id: "outcome-crunch")
                    StarRating(label: "Overall", value: $o.overall, area: .jars, id: "outcome-overall")
                    Toggle("Overall a success", isOn: $o.success).accessibilityIdentifier("outcome-success")
                } header: { SectionHeading("Verdict", .jars) }
                Section {
                    ChipPicker(options: Logic.PROBLEMS, selection: $o.problems, area: .jars, id: "outcome-problem")
                } header: { SectionHeading("Problems seen", .jars) }
            }
            .formStyle(.grouped)
            .tint(Area.jars.color)
            .navigationTitle("Outcome")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .cancelSave(area: .jars, onCancel: { dismiss() }, onSave: save)
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
        .onAppear { if let have = batch.outcome { o = have } }
    }

    private func save() {
        var n = batch
        o.recorded = true; o.recordedAt = Date()
        n.outcome = o
        store.save(n)
        Alarms.reschedule(store: store)
        dismiss()
    }
}
