import Foundation

/// Renaming and removing his own vegetables, cuts and spices everywhere they are used (port of the web app's
/// renameVegetable / renameSpice / removeSpice). Pure functions on the data, so they can be tested.
enum SettingsListEdit {
    enum Kind: String, CaseIterable {
        case vegetable, form, spice
        var title: String { switch self { case .vegetable: "Vegetables"; case .form: "Cuts"; case .spice: "Spices" } }
        var one: String { switch self { case .vegetable: "vegetable"; case .form: "cut"; case .spice: "spice" } }
        var builtin: [String] { switch self { case .vegetable: Logic.VEGETABLES; case .form: Logic.FORMS; case .spice: Logic.COMMON_SPICES } }
        var custom: WritableKeyPath<AppSettings, [String]> {
            switch self { case .vegetable: \.customVegetables; case .form: \.customForms; case .spice: \.customSpices }
        }
    }

    private static func values(_ b: Batch, _ kind: Kind) -> [String] {
        switch kind { case .vegetable: [b.vegetable]; case .form: [b.form]; case .spice: b.additions }
    }

    /// His own names: remembered ones plus those used by jars, not built in, sorted.
    static func names(_ kind: Kind, in data: AppData) -> [String] {
        let builtin = Set(kind.builtin)
        let used = data.liveBatches.flatMap { values($0, kind) }
        return Set((data.settings[keyPath: kind.custom] + used).filter { !$0.isEmpty && !builtin.contains($0) })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func jarCount(_ kind: Kind, _ name: String, in data: AppData) -> Int {
        data.liveBatches.filter { values($0, kind).contains(name) }.count
    }

    static func templateCount(_ kind: Kind, _ name: String, in data: AppData) -> Int {
        data.livePresets.filter { p in
            switch kind { case .vegetable: p.vegetable == name; case .form: p.form == name; case .spice: p.additions.contains(name) }
        }.count
    }

    /// "used in 3 jars" / "used in 2 jars and 1 template" / "not used yet"
    static func usage(_ kind: Kind, _ name: String, in data: AppData) -> String {
        let j = jarCount(kind, name, in: data), t = templateCount(kind, name, in: data)
        if j == 0, t == 0 { return "not used yet" }
        var parts: [String] = []
        if j > 0 { parts.append(ImportApply.plural(j, "jar")) }
        if t > 0 { parts.append(ImportApply.plural(t, "template")) }
        return "used in " + parts.joined(separator: " and ")
    }

    /// Rename in his remembered list, in every jar and in every template.
    static func rename(_ kind: Kind, from old: String, to new: String, in data: inout AppData, now: Date = Date()) {
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, new != old else { return }
        var list = Logic.renamedList(data.settings[keyPath: kind.custom], old, new)
        if !kind.builtin.contains(new), !list.contains(new) { list.append(new) }
        data.settings[keyPath: kind.custom] = list
        data.settings.modifiedAt = now
        for i in data.batches.indices where !data.batches[i].isRemoved && values(data.batches[i], kind).contains(old) {
            switch kind {
            case .vegetable: data.batches[i].vegetable = new
            case .form: data.batches[i].form = new
            case .spice: data.batches[i].additions = Logic.renamedList(data.batches[i].additions, old, new)
            }
            data.batches[i].modifiedAt = now
        }
        for i in data.presets.indices where !data.presets[i].isRemoved {
            switch kind {
            case .vegetable where data.presets[i].vegetable == old: data.presets[i].vegetable = new
            case .form where data.presets[i].form == old: data.presets[i].form = new
            case .spice where data.presets[i].additions.contains(old): data.presets[i].additions = Logic.renamedList(data.presets[i].additions, old, new)
            default: continue
            }
            data.presets[i].modifiedAt = now
        }
    }

    /// A vegetable or cut can only go when no jar uses it; a spice goes and is taken off every jar and template.
    static func canRemove(_ kind: Kind, _ name: String, in data: AppData) -> Bool {
        kind == .spice || jarCount(kind, name, in: data) == 0
    }

    @discardableResult
    static func remove(_ kind: Kind, _ name: String, in data: inout AppData, now: Date = Date()) -> Bool {
        guard canRemove(kind, name, in: data) else { return false }
        data.settings[keyPath: kind.custom] = Logic.withoutItem(data.settings[keyPath: kind.custom], name)
        data.settings.modifiedAt = now
        if kind == .spice {
            for i in data.batches.indices where data.batches[i].additions.contains(name) {
                data.batches[i].additions = Logic.withoutItem(data.batches[i].additions, name); data.batches[i].modifiedAt = now
            }
            for i in data.presets.indices where data.presets[i].additions.contains(name) {
                data.presets[i].additions = Logic.withoutItem(data.presets[i].additions, name); data.presets[i].modifiedAt = now
            }
        }
        return true
    }
}
