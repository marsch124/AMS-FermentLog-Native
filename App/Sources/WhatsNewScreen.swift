import SwiftUI

struct WhatsNewScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap * 1.5) {
                ForEach(Guide.releases) { r in
                    VStack(alignment: .leading, spacing: Theme.tight) {
                        HStack(spacing: Theme.gap) {
                            Pill(text: r.version, color: Area.settings.color)
                            Text(r.date).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        ForEach(Array(r.lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").foregroundStyle(Area.settings.color)
                                Text(line).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.body)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("whatsnew-\(r.version)")
                }
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("What’s new")
        .accessibilityIdentifier("whatsnew-screen")
    }
}
