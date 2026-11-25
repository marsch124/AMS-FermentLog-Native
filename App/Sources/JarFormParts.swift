import SwiftUI

/// A name with a number box right beside it (left aligned, never at the far edge).
struct JarNumberField: View {
    let title: String
    @Binding var value: Double?
    var id: String
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            TextField("", value: $value, format: .number)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(maxWidth: 90)
                .fieldBox()
                .accessibilityIdentifier(id)
            Spacer(minLength: 0)
        }
    }
}

/// A picker of choices that ends with "Add your own…", which shows a text box for a new word.
struct JarChoicePicker: View {
    static let addOwn = "\u{1}add-own"
    let title: String
    let options: [String]
    var allowNone = false
    @Binding var pick: String
    @Binding var custom: String
    var id: String
    var body: some View {
        Picker(title, selection: $pick) {
            if allowNone { Text("None").tag("") }
            ForEach(options, id: \.self) { Text($0).tag($0) }
            Text("Add your own…").tag(Self.addOwn)
        }
        .accessibilityIdentifier(id)
        if pick == Self.addOwn {
            TextField("New \(title.lowercased())", text: $custom)
                .accessibilityIdentifier("\(id)-custom")
        }
    }
}

extension Logic {
    /// The value to store for a picker that may hold "Add your own…".
    static func resolved(_ pick: String, _ custom: String) -> String {
        pick == JarChoicePicker.addOwn ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : pick
    }
}
