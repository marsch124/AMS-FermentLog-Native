import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Color {
    /// One colour for day, another for night (0xRRGGBB).
    init(day: UInt32, night: UInt32) {
        func rgb(_ v: UInt32) -> (Double, Double, Double) {
            (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        }
        let d = rgb(day), n = rgb(night)
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: n.0, green: n.1, blue: n.2, alpha: 1)
            : UIColor(red: d.0, green: d.1, blue: d.2, alpha: 1) })
        #else
        self.init(nsColor: NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(red: n.0, green: n.1, blue: n.2, alpha: 1)
                : NSColor(red: d.0, green: d.1, blue: d.2, alpha: 1) })
        #endif
    }
}

/// The parts of the app. Each has its own colour for its headings, buttons and marks (day and night values),
/// and a fill tone for its one full-colour button (white words stay readable on it).
enum Area: String, CaseIterable, Identifiable {
    case jars, bakes, recipes, insights, search, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .jars: "Jars"
        case .bakes: "Bakes"
        case .recipes: "Recipes"
        case .insights: "Insights"
        case .search: "Search"
        case .settings: "Settings"
        }
    }
    var mark: MarkKind {
        switch self {
        case .jars: .jar
        case .bakes: .bread
        case .recipes: .book
        case .insights: .chart
        case .search: .search
        case .settings: .gear
        }
    }
    /// Headings, marks, row accents.
    var color: Color {
        switch self {
        case .jars: Theme.brand                                   // the web app's carrot orange
        case .bakes: Color(day: 0xA9751C, night: 0xE0AE4F)         // warm brown-gold
        case .recipes: Color(day: 0x6B46A8, night: 0xC7AEF0)       // the web's recipe-pill purple
        case .insights: Color(day: 0x1E7F8F, night: 0x55BCCB)      // teal-blue
        case .search: Color(day: 0x4F6490, night: 0x9DB1DD)        // calm slate-blue
        case .settings: Color(day: 0x66788C, night: 0xA4B3C4)      // grey-blue
        }
    }
    /// The one full-colour button of the area (never grey).
    var fill: Color {
        switch self {
        case .jars: Color(day: 0xE8722C, night: 0xD9651F)
        case .bakes: Color(day: 0x9A6816, night: 0xA97B22)
        case .recipes: Color(day: 0x6B46A8, night: 0x7A56BA)
        case .insights: Color(day: 0x1E7F8F, night: 0x238FA0)
        case .search: Color(day: 0x4F6490, night: 0x5B72A3)
        case .settings: Color(day: 0x5A6C80, night: 0x6B7D91)
        }
    }
}

/// Colours of the web app (styles.css :root, light and dark).
enum Theme {
    static let brand = Color(day: 0xE8722C, night: 0xF0873E)
    static let brandInk = Color(day: 0xB8551A, night: 0xF5A367)
    static let ok = Color(day: 0x4A9D5B, night: 0x5FB470)
    static let problem = Color(day: 0xD1495B, night: 0xE5677A)
    static let bg = Color(day: 0xFAF6F0, night: 0x1A1713)
    static let surface = Color(day: 0xFFFFFF, night: 0x241F1A)
    static let surface2 = Color(day: 0xF4EDE3, night: 0x2E2822)
    static let ink = Color(day: 0x2C2620, night: 0xF0E9DF)
    static let muted = Color(day: 0x8A7F72, night: 0xA89B8C)
    static let line = Color(day: 0xECE3D6, night: 0x38302A)
    /// Compact: the one spacing the app uses between things in a column / inside a row.
    static let gap: CGFloat = 8
    static let tight: CGFloat = 4
}

// MARK: - Styles

/// The main button: full colour with white words, never grey.
struct PrimaryButtonStyle: ButtonStyle {
    var area: Area = .jars
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(area.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : (enabled ? 1 : 0.55))
    }
}

/// The second button: the area's colour as words on a soft tint.
struct QuietButtonStyle: ButtonStyle {
    var area: Area = .jars
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(area.color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(area.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// A small round-ended label for a state (Fermenting, In the fridge, Done).
struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
    }
}

/// A small square-cornered label for a fact (Cabbage, Chopped, Plain lid).
struct Tag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A heading in the area's colour.
struct SectionHeading: View {
    let text: String
    let area: Area
    init(_ text: String, _ area: Area) { self.text = text; self.area = area }
    init(_ text: String, area: Area) { self.text = text; self.area = area }
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(area.color)
            .accessibilityAddTraits(.isHeader)
    }
}
