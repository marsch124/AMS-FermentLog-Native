import SwiftUI
import AMSIcons

/// Hand-drawn marks in the AMS Icon Library style: a grid, one round-ended stroke, no fill, drawn as shapes —
/// no SF Symbols, no emoji. These are the web app's own drawings, ported path for path from index.html (the five tab
/// marks) and js/app.js (`IC` and `ILLUS`); the package AMS-Icons has no jar, no bread loaf, no chart of bars, so
/// they are drawn here. The package supplies the path reader (`SVGPath`) only.
///
/// `Mark(.jar)` is sized by `.frame` and coloured by `.foregroundStyle`.
enum MarkKind: String, CaseIterable, Hashable {
    // The five tab-bar marks (index.html)
    case jar, book, plus, chart, gear
    // The small inline icons (app.js IC)
    case jarBand, bread, search, up, down
    // Drawn for the native app: the handle a recipe step is dragged by (three short lines)
    case grip
    // The larger illustrations (app.js ILLUS), on a 64 grid, with a soft inner fill
    case jarBig, carrot, breadBig, bookBig

    struct Drawing {
        var grid: CGFloat = 24
        var stroke: CGFloat = 1.9      // in grid units, as the web wrote stroke-width
        var d: String
        /// Finer lines drawn inside (the jar's steam: stroke-width 1.4).
        var fine: String?
        var fineStroke: CGFloat = 1.4
        /// A part that is also filled with the mark's colour at 12 % (ILLUS).
        var fill: String?
    }

    var drawing: Drawing {
        switch self {
        case .jar:
            return Drawing(d: "M8 4h8 M8 4v1.4a3 3 0 0 1-.9 2.1A4 4 0 0 0 6 10.4V18a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3v-7.6a4 4 0 0 0-1.1-2.9A3 3 0 0 1 16 5.4V4",
                           fine: "M9.2 12.4c-.7 1.2.7 2.1 0 3.3c-.7 1.2.7 2 0 3.1 M12 12.4c.7 1.2-.7 2.1 0 3.3c.7 1.2-.7 2 0 3.1 M14.8 12.4c-.7 1.2.7 2.1 0 3.3c-.7 1.2.7 2 0 3.1")
        case .jarBand:
            return Drawing(d: "M8 4h8 M8 4v1.4a3 3 0 0 1-.9 2.1A4 4 0 0 0 6 10.4V18a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3v-7.6a4 4 0 0 0-1.1-2.9A3 3 0 0 1 16 5.4V4 M6.4 12h11.2")
        case .book:
            return Drawing(d: "M6 4.5h8.5a3 3 0 0 1 3 3V20H9a3 3 0 0 1-3-3Z M9.5 9h5 M9.5 12.5h5")
        case .plus:
            return Drawing(stroke: 2.4, d: "M12 6v12 M6 12h12")
        case .chart:
            return Drawing(stroke: 2.1, d: "M5 20h14 M7.5 20v-4.5 M12 20V8 M16.5 20v-7")
        case .gear:   // the web's "sun-gear": a ring with eight rays
            return Drawing(stroke: 1.85, d: "M8.9 12a3.1 3.1 0 1 0 6.2 0a3.1 3.1 0 1 0 -6.2 0 M12 3v2.4 M12 18.6V21 M3 12h2.4 M18.6 12H21 M5.6 5.6l1.7 1.7 M16.7 16.7l1.7 1.7 M18.4 5.6l-1.7 1.7 M7.3 16.7l-1.7 1.7")
        case .bread:
            return Drawing(d: "M5 14.5a4.5 4.5 0 0 1 2.6-4.1A4 4 0 0 1 9.2 6h5.6a4 4 0 0 1 1.6 4.4A4.5 4.5 0 0 1 19 14.5V17a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1Z M9.5 11.5 8 16 M12 11.5 10.5 16 M14.5 11.5 13 16")
        case .search:
            return Drawing(stroke: 2, d: "M4.8 11a6.2 6.2 0 1 0 12.4 0a6.2 6.2 0 1 0 -12.4 0 M20 20l-3.6-3.6")
        case .up:
            return Drawing(stroke: 2, d: "M12 20V6 M6 12l6-6 6 6")
        case .down:
            return Drawing(stroke: 2, d: "M12 4v14 M6 12l6 6 6-6")
        case .grip:
            return Drawing(d: "M7 8h10 M7 12h10 M7 16h10")
        case .jarBig:
            return Drawing(stroke: 1.6, d: "M8 4h8 M8 4v1.4a3 3 0 0 1-.9 2.1A4 4 0 0 0 6 10.4V18a3 3 0 0 0 3 3h6a3 3 0 0 0 3-3v-7.6a4 4 0 0 0-1.1-2.9A3 3 0 0 1 16 5.4V4 M6.4 12h11.2")
        case .carrot:
            return Drawing(grid: 64, stroke: 2.8,
                           d: "M25 26C26 39 28 50 31 56c.4.9 1.6.9 2 0 3-6 5-17 6-30Z M32 26V10 M32 16c-3-5-9-7-13-5 M32 16c3-5 9-7 13-5 M28 35l3 1.6 M37 35l-3 1.6 M30 43l2.4 1.4 M35 43l-2.4 1.4",
                           fill: "M25 26C26 39 28 50 31 56c.4.9 1.6.9 2 0 3-6 5-17 6-30Z")
        case .breadBig:
            return Drawing(grid: 64, stroke: 3,
                           d: "M11 40C11 26 21 19 32 19s21 7 21 21c0 4-4 7-8 7H19c-4 0-8-3-8-7Z M24 28l6 8 M33 27l6 8 M42 28l4 6",
                           fill: "M11 40C11 26 21 19 32 19s21 7 21 21c0 4-4 7-8 7H19c-4 0-8-3-8-7Z")
        case .bookBig:
            return Drawing(grid: 64, stroke: 3,
                           d: "M18 14h20a6 6 0 0 1 6 6v30H24a6 6 0 0 1-6-6Z M26 26h13 M26 33h13 M26 40h8",
                           fill: "M18 14h20a6 6 0 0 1 6 6v30H24a6 6 0 0 1-6-6Z")
        }
    }

    /// What VoiceOver says when the mark stands alone.
    var label: String {
        switch self {
        case .jar, .jarBand, .jarBig: "Jar"
        case .book, .bookBig: "Recipe book"
        case .plus: "New"
        case .chart: "Insights"
        case .gear: "Settings"
        case .bread, .breadBig: "Bread"
        case .search: "Search"
        case .up: "Up"
        case .down: "Down"
        case .grip: "Drag handle"
        case .carrot: "Carrot"
        }
    }
}

/// A mark's drawing, centred in whatever square it is framed in.
struct MarkShape: Shape {
    let d: String
    var grid: CGFloat = 24
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / grid
        let move = CGAffineTransform(translationX: rect.midX - grid / 2 * k, y: rect.midY - grid / 2 * k).scaledBy(x: k, y: k)
        return SVGPath.path(d).applying(move)
    }
}

struct Mark: View {
    let kind: MarkKind
    init(_ kind: MarkKind) { self.kind = kind }

    var body: some View {
        let g = kind.drawing
        GeometryReader { geo in
            let k = min(geo.size.width, geo.size.height) / g.grid
            ZStack {
                if let f = g.fill { MarkShape(d: f, grid: g.grid).fill(.foreground.opacity(0.12)) }
                MarkShape(d: g.d, grid: g.grid)
                    .stroke(style: StrokeStyle(lineWidth: g.stroke * k, lineCap: .round, lineJoin: .round))
                if let fine = g.fine {
                    MarkShape(d: fine, grid: g.grid)
                        .stroke(style: StrokeStyle(lineWidth: g.fineStroke * k, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.label)
        .accessibilityAddTraits(.isImage)
    }
}

extension Mark {
    /// The mark as a template picture — a tab bar only takes pictures, not shapes.
    @MainActor static func image(_ kind: MarkKind, size: CGFloat = 26) -> Image {
        let r = ImageRenderer(content: Mark(kind).foregroundStyle(.black).frame(width: size, height: size))
        r.scale = 3
        #if canImport(UIKit)
        if let ui = r.uiImage { return Image(uiImage: ui.withRenderingMode(.alwaysTemplate)) }
        #else
        if let ns = r.nsImage { ns.isTemplate = true; ns.size = NSSize(width: size, height: size); return Image(nsImage: ns) }
        #endif
        return Image(systemName: "circle")
    }

    /// The New tab: a full-colour round button with a white plus (not a template, so the bar keeps its colour).
    @MainActor static func newButtonImage(size: CGFloat = 30) -> Image {
        let view = ZStack {
            Circle().fill(Area.jars.fill)
            Mark(.plus).foregroundStyle(.white).frame(width: size * 0.62, height: size * 0.62)
        }.frame(width: size, height: size)
        let r = ImageRenderer(content: view)
        r.scale = 3
        #if canImport(UIKit)
        if let ui = r.uiImage { return Image(uiImage: ui.withRenderingMode(.alwaysOriginal)) }
        #else
        if let ns = r.nsImage { ns.isTemplate = false; return Image(nsImage: ns) }
        #endif
        return Image(systemName: "plus.circle.fill")
    }
}
