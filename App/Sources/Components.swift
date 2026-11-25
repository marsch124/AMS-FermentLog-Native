import SwiftUI
import PhotosUI

// Small pieces every part of the app shares, so a star row, a chip picker or a photo strip looks and
// behaves the same on every screen. Screens must use these instead of drawing their own.

/// Five stars to tap (1–5). Tapping the star that is already the value clears it.
struct StarRating: View {
    let label: String
    @Binding var value: Int?
    var area: Area = .jars
    var id = "stars"
    var body: some View {
        HStack(spacing: Theme.gap) {
            Text(label).frame(minWidth: 72, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { n in
                    Button { value = (value == n) ? nil : n } label: {
                        Text((value ?? 0) >= n ? "★" : "☆").font(.title3).foregroundStyle((value ?? 0) >= n ? area.color : Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) \(n) of 5")
                    .accessibilityIdentifier("\(id)-\(n)")
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Read-only stars for a value (rounded), or a dash when there is none.
struct Stars: View {
    let value: Double?
    var area: Area = .jars
    var body: some View {
        if let value {
            let full = max(0, min(5, Int(value.rounded())))
            Text(String(repeating: "★", count: full) + String(repeating: "☆", count: 5 - full))
                .foregroundStyle(area.color)
                .accessibilityLabel("\(full) of 5 stars")
        } else {
            Text("—").foregroundStyle(Theme.muted)
        }
    }
}

/// Chips to tick, several at once (spices, problems). Wraps onto as many lines as it needs.
struct ChipPicker: View {
    let options: [String]
    @Binding var selection: [String]
    var area: Area = .jars
    var id = "chip"
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { o in
                let on = selection.contains(o)
                Button {
                    if on { selection.removeAll { $0 == o } } else { selection.append(o) }
                } label: {
                    Text(o).font(.subheadline)
                        .foregroundStyle(on ? area.color : Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(on ? area.color.opacity(0.16) : Theme.surface2, in: Capsule())
                        .overlay(Capsule().stroke(on ? area.color : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("\(id)-\(o)")
            }
        }
    }
}

/// Lays its children out left to right and wraps them.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing; row = max(row, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}

/// Who logged this: the people from Settings, the active one by default. Shows nothing when no people are set.
struct LoggedByPicker: View {
    @EnvironmentObject var store: Store
    @Binding var name: String
    var body: some View {
        let people = store.data.settings.people
        if !people.isEmpty || !name.isEmpty {
            Picker("Logged by", selection: $name) {
                Text("—").tag("")
                ForEach(Array(Set(people + (name.isEmpty ? [] : [name]))).sorted(), id: \.self) { Text($0).tag($0) }
            }
            .accessibilityIdentifier("logged-by")
        }
    }
}

/// Pictures of a record: small squares in a row, a word-button to add one, and "Remove" under each while editing.
/// `names` are file names in the Photos folder. Read-only when `editable` is false.
struct PhotoStrip: View {
    @EnvironmentObject var store: Store
    @Binding var names: [String]
    var editable = true
    var area: Area = .jars
    @State private var picked: [PhotosPickerItem] = []
    @State private var showCamera = false
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            if !names.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.gap) {
                        ForEach(names, id: \.self) { n in
                            VStack(spacing: 2) {
                                PhotoImage(url: store.photoURL(n))
                                    .frame(width: editable ? 88 : 120, height: editable ? 88 : 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                if editable {
                                    Button("Remove") { names.removeAll { $0 == n } }
                                        .font(.caption).foregroundStyle(Theme.problem).buttonStyle(.plain)
                                        .accessibilityIdentifier("photo-remove")
                                }
                            }
                        }
                    }
                }
            }
            if editable {
                HStack(spacing: Theme.gap) {
                    PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) { Text("Add pictures") }
                        .buttonStyle(QuietButtonStyle(area: area))
                        .accessibilityIdentifier("photo-add")
                    #if os(iOS)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take a picture") { showCamera = true }
                            .buttonStyle(QuietButtonStyle(area: area))
                            .accessibilityIdentifier("photo-camera")
                    }
                    #endif
                }
            }
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) { add(data) }
                }
                picked = []
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) { CameraPicker { add($0) }.ignoresSafeArea() }
        #endif
    }
    private func add(_ data: Data) {
        let name = store.addPhoto(data)
        if !name.isEmpty { names.append(name) }
    }
}

#if os(iOS)
/// The iPhone or iPad camera, for one picture.
struct CameraPicker: UIViewControllerRepresentable {
    let done: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage, let data = img.jpegData(compressionQuality: 0.9) { parent.done(data) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
#endif

/// A name with its value right beside it, on the left — never pushed to the far right edge.
struct Fact: View {
    let name: String
    let value: String
    var valueColor: Color = Theme.ink
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(name).foregroundStyle(Theme.muted)
            Text(value).fontWeight(.semibold).foregroundStyle(valueColor)
            Spacer(minLength: 0)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Every page where something is changed has Cancel and Save; on the Mac, Escape is Cancel and Return in a field does not save by accident.
    func cancelSave(area: Area, canSave: Bool = true, saveTitle: String = "Save", onCancel: @escaping () -> Void, onSave: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction).accessibilityIdentifier("cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle, action: onSave).fontWeight(.semibold).tint(area.color).disabled(!canSave).accessibilityIdentifier("save")
            }
        }
        .navigationBarBackButtonHiddenIfPossible()
    }
    @ViewBuilder func navigationBarBackButtonHiddenIfPossible() -> some View {
        #if os(iOS)
        self.navigationBarBackButtonHidden(true)
        #else
        self
        #endif
    }
    /// The app's page background and compact page padding.
    func page() -> some View {
        self.padding(.horizontal, 12).padding(.vertical, Theme.gap).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            .background(Theme.bg)
    }
}

/// A block on a page: an area-coloured heading and its content on a soft surface.
struct Block<Content: View>: View {
    let title: String
    var area: Area = .jars
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            SectionHeading(title, area)
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
