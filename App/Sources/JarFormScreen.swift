import SwiftUI

/// Add a jar (batchID nil; `draft` prefills it) or edit one.
struct JarFormScreen: View {
    let batchID: String?
    var draft: Batch? = nil
    init(batchID: String?, draft: Batch? = nil) { self.batchID = batchID; self.draft = draft }

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var batch = Logic.newBatch()
    @State private var loaded = false
    @State private var missing = false
    @State private var vegPick = ""
    @State private var vegCustom = ""
    @State private var formPick = ""
    @State private var formCustom = ""
    @State private var newSpice = ""
    @State private var templateName = ""
    @State private var askTemplate = false
    @State private var askDelete = false
    @State private var aiText = ""
    @State private var aiStatus = ""
    @State private var aiBusy = false

    private var isEdit: Bool { batchID != nil }
    private var settings: AppSettings { store.data.settings }
    private var vegetable: String { Logic.resolved(vegPick, vegCustom) }

    var body: some View {
        Group {
            if missing {
                Text("This jar is no longer here.").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
            }
        }
        .background(Theme.bg)
        .navigationTitle(isEdit ? "Edit jar" : "New jar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .cancelSave(area: .jars, canSave: !vegetable.isEmpty && !missing, onCancel: { dismiss() }, onSave: save)
        .onAppear(perform: load)
    }

    private var form: some View {
        Form {
            if !isEdit { startSection }
            Section { basics } header: { SectionHeading("Basics", .jars) }
            Section { conditions } header: { SectionHeading("Brine and conditions", .jars) }
            Section { spices } header: { SectionHeading("Spices", .jars) }
            Section { equipment } header: { SectionHeading("Equipment", .jars) }
            Section { reminders } header: { SectionHeading("Reminders", .jars) }
            Section {
                PhotoStrip(names: $batch.photos, editable: true, area: .jars)
                TextField("Notes — anything worth remembering", text: $batch.notes, axis: .vertical).lineLimit(2...8)
                    .accessibilityIdentifier("jar-notes")
            } header: { SectionHeading("Photos and notes", .jars) }
            Section {
                Button("Save as a template") { templateName = batch.name.isEmpty ? vegetable : batch.name; askTemplate = true }
                    .buttonStyle(QuietButtonStyle(area: .jars)).accessibilityIdentifier("jar-save-template")
                Text("A template keeps these settings so you can start the next jar from them.").font(.caption).foregroundStyle(Theme.muted)
                if isEdit {
                    Button("Delete this jar") { askDelete = true }
                        .foregroundStyle(Theme.problem).accessibilityIdentifier("jar-delete")
                }
            }
        }
        .formStyle(.grouped)
        .tint(Area.jars.color)
        .alert("Name this template", isPresented: $askTemplate) {
            TextField("e.g. Classic 2.5% carrots", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveTemplate() }
        }
        .confirmationDialog("Delete this jar?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete this jar", role: .destructive) { deleteJar() }
            Button("Keep it", role: .cancel) {}
        } message: { Text("You can undo it for a few seconds afterwards.") }
    }

    // MARK: Sections

    @ViewBuilder private var startSection: some View {
        let presets = store.data.livePresets
        if !presets.isEmpty || AI.hasKey {
            Section {
                if !presets.isEmpty {
                    Picker("Start from a template", selection: Binding(get: { "" }, set: { applyPreset($0) })) {
                        Text("None").tag("")
                        ForEach(presets) { Text($0.name.isEmpty ? $0.vegetable : $0.name).tag($0.id) }
                    }
                    .accessibilityIdentifier("jar-template-pick")
                }
                if AI.hasKey {
                    TextField("Describe it and let AI fill this in", text: $aiText, axis: .vertical).lineLimit(2...5)
                        .accessibilityIdentifier("jar-ai-text")
                    Text("e.g. Carrot sticks in a 2.5% brine, about 20°C, glass weight, burping lid, garlic and dill, taste every 3 days.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Button(aiBusy ? "Building…" : "Build jar with AI") { buildWithAI() }
                        .buttonStyle(QuietButtonStyle(area: .jars)).disabled(aiBusy || aiText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("jar-ai-build")
                    if !aiStatus.isEmpty { Text(aiStatus).font(.caption).foregroundStyle(Theme.muted) }
                }
            } header: { SectionHeading("Start", .jars) }
        }
    }

    @ViewBuilder private var basics: some View {
        TextField("Name, e.g. Spicy carrot #1", text: $batch.name).accessibilityIdentifier("jar-name")
        JarChoicePicker(title: "Vegetable", options: vegOptions, pick: $vegPick, custom: $vegCustom, id: "jar-vegetable")
        JarChoicePicker(title: "Form", options: formOptions, allowNone: true, pick: $formPick, custom: $formCustom, id: "jar-form")
        DatePicker("Start date", selection: Binding(
            get: { Logic.date(fromDay: batch.startDate) ?? Date() },
            set: { batch.startDate = Logic.isoDay($0) }), displayedComponents: .date)
            .accessibilityIdentifier("jar-start-date")
        LoggedByPicker(name: $batch.loggedBy)
    }

    @ViewBuilder private var conditions: some View {
        JarNumberField(title: "Salt (g)", value: $batch.saltGrams, id: "jar-salt")
        JarNumberField(title: "Water (ml)", value: $batch.waterMl, id: "jar-water")
        if let v = Logic.computeBrinePercent(salt: batch.saltGrams, water: batch.waterMl) {
            let ok = Logic.isBrineInRange(v)
            HStack(spacing: 6) {
                Text("Brine").foregroundStyle(Theme.muted)
                Text(String(format: "%.1f%%", v)).fontWeight(.semibold)
                Text(ok ? "✓ in the 2–3% sweet spot" : "typical range is 2–3%").foregroundStyle(ok ? Theme.ok : Theme.muted)
                Spacer(minLength: 0)
            }
            .font(.subheadline).accessibilityIdentifier("jar-brine-line")
        }
        JarNumberField(title: "Room temperature (°C)", value: $batch.roomTempC, id: "jar-room-temp")
        JarNumberField(title: "Jar size (ml)", value: $batch.jarSizeMl, id: "jar-size")
    }

    @ViewBuilder private var spices: some View {
        ChipPicker(options: spiceOptions, selection: $batch.additions, area: .jars, id: "jar-spice")
        HStack {
            TextField("Add your own spice", text: $newSpice).onSubmit(addSpice).accessibilityIdentifier("jar-spice-new")
            Button("Add", action: addSpice).buttonStyle(QuietButtonStyle(area: .jars))
                .disabled(newSpice.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("jar-spice-add")
        }
    }

    @ViewBuilder private var equipment: some View {
        TextField("Vessel, e.g. Glass jar, crock", text: $batch.vesselType).accessibilityIdentifier("jar-vessel")
        Picker("Weight", selection: $batch.weightType) {
            ForEach(Logic.WEIGHT_TYPES + (Logic.WEIGHT_TYPES.contains(batch.weightType) ? [] : [batch.weightType]), id: \.self) { Text($0).tag($0) }
        }.accessibilityIdentifier("jar-weight")
        Picker("Lid", selection: $batch.lidType) {
            ForEach(Logic.LID_TYPES + (Logic.LID_TYPES.contains(batch.lidType) ? [] : [batch.lidType]), id: \.self) { Text($0).tag($0) }
        }.accessibilityIdentifier("jar-lid")
    }

    @ViewBuilder private var reminders: some View {
        Stepper(value: $batch.remindEveryDays, in: 0...60) {
            Text(batch.remindEveryDays == 0 ? "Taste-test reminder: off" : "Remind me to taste every \(batch.remindEveryDays) \(batch.remindEveryDays == 1 ? "day" : "days")")
        }
        .accessibilityIdentifier("jar-remind-days")
        Text("0 turns the taste-test reminder off for this jar.").font(.caption).foregroundStyle(Theme.muted)
        Toggle("Burp alarm", isOn: Binding(
            get: { batch.burpAlarm ?? (batch.lidType == "Plain lid") },
            set: { batch.burpAlarm = $0 }))
            .accessibilityIdentifier("jar-burp-alarm")
        Text(batch.burpAlarm != nil
             ? (batch.burpAlarm == true ? "On for this jar" : "Off for this jar")
             : (batch.lidType == "Plain lid" ? "On by itself for a plain lid" : "Off: this lid lets the gas out by itself"))
            .font(.caption).foregroundStyle(Theme.muted)
            .accessibilityIdentifier("jar-burp-caption")
    }

    // MARK: Lists

    private var vegOptions: [String] {
        var l = Logic.mergeVegetables(settings.customVegetables)
        if !vegPick.isEmpty, vegPick != JarChoicePicker.addOwn, !l.contains(vegPick) { l.append(vegPick) }
        return l
    }
    private var formOptions: [String] {
        var l = Logic.FORMS + settings.customForms.filter { !Logic.FORMS.contains($0) }
        if !formPick.isEmpty, formPick != JarChoicePicker.addOwn, !l.contains(formPick) { l.append(formPick) }
        return l
    }
    private var spiceOptions: [String] {
        var l = Logic.mergeSpices(settings.customSpices)
        for a in batch.additions where !l.contains(a) { l.append(a) }
        return l
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id = batchID {
            guard let b = store.data.batch(id) else { missing = true; return }
            batch = b
        } else if let draft {
            batch = draft
        }
        vegPick = batch.vegetable; formPick = batch.form
    }

    private func addSpice() {
        let n = newSpice.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if let have = spiceOptions.first(where: { $0.lowercased() == n.lowercased() }) {
            if !batch.additions.contains(have) { batch.additions.append(have) }
        } else { batch.additions.append(n) }
        newSpice = ""
    }

    private func applyPreset(_ id: String) {
        guard let p = store.data.livePresets.first(where: { $0.id == id }) else { return }
        var b = Logic.batchFromPreset(p)
        b.id = batch.id; b.createdAt = batch.createdAt; b.photos = batch.photos; b.notes = batch.notes
        b.loggedBy = batch.loggedBy; b.name = batch.name; b.startDate = batch.startDate
        batch = b; vegPick = b.vegetable; formPick = b.form
    }

    private func buildWithAI() {
        aiBusy = true; aiStatus = "Building your jar…"
        Task {
            do {
                var built = try await AI.buildBatch(from: aiText)
                built.id = batch.id; built.createdAt = batch.createdAt
                batch = built; vegPick = built.vegetable; formPick = built.form
                aiStatus = "Filled in — look it over, then press Save."
            } catch { aiStatus = error.localizedDescription }
            aiBusy = false
        }
    }

    private func saveTemplate() {
        let n = templateName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        var b = batch; b.vegetable = vegetable; b.form = Logic.resolved(formPick, formCustom)
        store.save(Logic.presetFromBatch(b, name: n))
        store.showToast("Template saved")
    }

    private func deleteJar() {
        let id = batch.id
        store.remove(batch: id)
        store.showToast("Jar removed", undo: { store.restore(batch: id) })
        Alarms.reschedule(store: store)
        dismiss()
    }

    private func save() {
        var b = batch
        b.vegetable = vegetable
        b.form = Logic.resolved(formPick, formCustom)
        b.name = b.name.trimmingCharacters(in: .whitespacesAndNewlines)
        b.vesselType = b.vesselType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b.vegetable.isEmpty else { return }
        let s = settings
        let newVeg = !Logic.VEGETABLES.contains(b.vegetable) && !s.customVegetables.contains(b.vegetable)
        let newForm = !b.form.isEmpty && !Logic.FORMS.contains(b.form) && !s.customForms.contains(b.form)
        let newSpices = b.additions.filter { !Logic.COMMON_SPICES.contains($0) && !s.customSpices.contains($0) }
        if newVeg || newForm || !newSpices.isEmpty {
            store.updateSettings {
                if newVeg { $0.customVegetables.append(b.vegetable) }
                if newForm { $0.customForms.append(b.form) }
                $0.customSpices += newSpices
            }
        }
        store.save(b)
        Alarms.reschedule(store: store)
        dismiss()
        if !isEdit {
            let id = b.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .openRoute, object: Route.jar(id))
            }
        }
    }
}
