import SwiftUI

/// "text in a section": lines starting with "• " become bullets; everything else is a paragraph.
struct GuideText: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("• ") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundStyle(Area.settings.color)
                        Text(String(line.dropFirst(2))).fixedSize(horizontal: false, vertical: true)
                    }
                } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Color.clear.frame(height: 2)
                } else {
                    Text(line).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GuideScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap * 1.5) {
                ForEach(Guide.howItWorks) { s in
                    VStack(alignment: .leading, spacing: Theme.tight) {
                        SectionHeading(s.title, .settings)
                        GuideText(text: s.text)
                    }
                    .accessibilityIdentifier("guide-section-\(s.title)")
                }
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("How it works")
        .accessibilityIdentifier("guide-screen")
    }
}
