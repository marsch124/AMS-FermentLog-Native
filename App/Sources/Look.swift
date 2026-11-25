import SwiftUI

// The "Full colour" look (his pick from one picture, 25 Nov 2026 — version 6.1).
// Every read page opens with a head card filled with its part's colour, facts sit in small tiles,
// the page behind is lightly tinted with the part's colour, and cards are round with a soft shadow.
// Screens must build from these pieces instead of drawing their own, so every part looks alike.

enum Look {
    static let radius: CGFloat = 14
    static let tileRadius: CGFloat = 11
    static let tileGap: CGFloat = 7
    static let shadow = Color.black.opacity(0.06)
    /// White words of second rank on a head card.
    static let heroSoft = Color.white.opacity(0.86)
}

private struct OnHeroKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True inside a head card: pieces draw themselves in white on the part's colour.
    var onHero: Bool {
        get { self[OnHeroKey.self] }
        set { self[OnHeroKey.self] = newValue }
    }
}

extension Area {
    /// The fill of a head card: the part's colour, deep enough for small white words.
    var hero: Color {
        switch self {
        case .jars: Color(day: 0xDC6520, night: 0xC65A1B)
        default: fill
        }
    }
}

/// The page behind the cards: the app's paper, lightly tinted with the part's colour.
struct AreaBackdrop: View {
    let area: Area
    var body: some View {
        ZStack { Theme.bg; area.color.opacity(0.07) }.ignoresSafeArea()
    }
}

extension View {
    /// Compact page padding for a tinted page. Put `.backdrop(area)` on the ScrollView around it.
    func page(_ area: Area) -> some View {
        self.padding(.horizontal, 12).padding(.vertical, Theme.gap)
            .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
    }
    func backdrop(_ area: Area) -> some View { background(AreaBackdrop(area: area)) }

    /// A white card: round corners and a soft shadow.
    func card(padding: CGFloat = 12) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Look.radius, style: .continuous))
            .shadow(color: Look.shadow, radius: 8, y: 3)
    }
}

/// The head card of a page, filled with the part's colour; everything inside is white.
/// Inside it use `Look.heroSoft` for second-rank words, and Tile / Pill / ProgressLine / the button styles as usual — they turn white by themselves.
struct Hero<Content: View>: View {
    let area: Area
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) { content }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(area.hero, in: RoundedRectangle(cornerRadius: Look.radius, style: .continuous))
            .shadow(color: Look.shadow, radius: 8, y: 3)
            .environment(\.onHero, true)
    }
}

/// A fact in a small tile: its name in small capitals, its value right under it, both at the left.
struct Tile: View {
    let label: String
    let value: String
    var area: Area = .jars
    var valueColor: Color?
    @Environment(\.onHero) private var onHero
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased()).font(.caption2.weight(.semibold)).kerning(0.3)
                .foregroundStyle(onHero ? Look.heroSoft : Theme.muted).lineLimit(1).minimumScaleFactor(0.75)
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(onHero ? Color.white : (valueColor ?? Theme.ink)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TileBack(area: area) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// The ground of a tile: the part's colour, pale, on the card colour (white veil on a head card).
struct TileBack: View {
    var area: Area = .jars
    var filled = false
    @Environment(\.onHero) private var onHero
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Look.tileRadius, style: .continuous)
        if filled { shape.fill(area.hero) }
        else if onHero { shape.fill(Color.white.opacity(0.17)) }
        else { shape.fill(Theme.surface).overlay(shape.fill(area.color.opacity(0.11))) }
    }
}

/// Tiles side by side: `columns` across, or `compact` across on a narrow iPhone.
struct TileGrid<Content: View>: View {
    var columns: Int
    var compact: Int?
    @ViewBuilder var content: Content
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Look.tileGap, alignment: .top), count: count),
                  alignment: .leading, spacing: Look.tileGap) { content }
    }
    private var count: Int {
        #if os(iOS)
        if sizeClass == .compact, let compact { return compact }
        #endif
        return columns
    }
}

/// A headline number in a tile: the figure large in the part's colour, its name under it.
/// `filled` paints the whole tile in the part's colour (the first one of a row). `ring` draws a share (0…1) beside the figure.
struct StatTile: View {
    let value: String
    let label: String
    var area: Area = .insights
    var filled = false
    var ring: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(value).font(.title2.weight(.heavy))
                    .foregroundStyle(filled ? Color.white : area.color).lineLimit(1).minimumScaleFactor(0.6)
                if let ring { Ring(share: ring, color: filled ? .white : area.color).frame(width: 18, height: 18) }
            }
            Text(label.uppercased()).font(.caption2.weight(.semibold)).kerning(0.3)
                .foregroundStyle(filled ? Look.heroSoft : Theme.muted).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { TileBack(area: area, filled: filled) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// A share drawn as a ring (success rate).
struct Ring: View {
    let share: Double
    var color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.22), lineWidth: 3.5)
            Circle().trim(from: 0, to: min(1, max(0, share)))
                .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
        .accessibilityHidden(true)
    }
}

/// A slim round line that fills from the left (how far along, or how much of the most).
struct ProgressLine: View {
    let share: Double
    var area: Area = .jars
    var color: Color?
    var height: CGFloat = 6
    @Environment(\.onHero) private var onHero
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(onHero ? Color.white.opacity(0.28) : (color ?? area.color).opacity(0.14))
                Capsule().fill(onHero ? Color.white : (color ?? area.color))
                    .frame(width: max(height, g.size.width * min(1, max(0, share))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// One line of a bar list: the name, its figure right beside it, and a slim round bar under both.
/// Replaces the thick square chart bars. `share` is 0…1 of the full length.
struct BarRow: View {
    let name: String
    let figure: String
    let share: Double
    var area: Area = .insights
    var color: Color?
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(figure).font(.subheadline.weight(.bold)).foregroundStyle(color ?? area.color)
                Spacer(minLength: 0)
            }
            ProgressLine(share: share, area: area, color: color, height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(figure)")
    }
}

/// A two-or-three-way switch in the part's colour (the system one takes the Mac's accent colour).
/// Each choice is a button with the identifier "<id>-<title>".
struct Segments<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, title: String)]
    var area: Area = .jars
    var id = "segments"
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { o in
                let on = o.value == selection
                Button { selection = o.value } label: {
                    Text(o.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? area.color : Theme.muted)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .frame(minHeight: 26)
                        .background(on ? Theme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: on ? Color.black.opacity(0.10) : .clear, radius: 1, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("\(id)-\(o.title)")
            }
        }
        .padding(2)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A step number in a full-colour circle (recipe method, plans).
struct StepDot: View {
    let number: Int
    var area: Area = .recipes
    var body: some View {
        Text("\(number)").font(.caption.weight(.bold)).foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(area.hero, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The heading of one day in a diary: "DAY 1" in the part's colour, then the day in plain words.
struct DayHeading: View {
    let day: Int?
    let date: String
    var area: Area = .jars
    var body: some View {
        HStack(spacing: 6) {
            if let day {
                Text("DAY \(day)").font(.caption2.weight(.bold)).foregroundStyle(area.color)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(area.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(date.uppercased()).font(.caption2.weight(.bold)).kerning(0.4).foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Plain words for dates, times and amounts

enum Human {
    private static let iso: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static func out(_ format: String) -> DateFormatter {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_GB"); f.dateFormat = format; return f
    }
    private static let short = out("EEE d MMM")
    private static let long = out("EEE d MMM yyyy")

    /// "2026-11-25" → "Wed 25 Nov" (with the year when it is not this year). Anything else comes back unchanged.
    static func day(_ isoDay: String, now: Date = Date()) -> String {
        guard let d = iso.date(from: isoDay) else { return isoDay }
        let cal = Calendar(identifier: .gregorian)
        return (cal.component(.year, from: d) == cal.component(.year, from: now) ? short : long).string(from: d)
    }

    /// "today", "tomorrow", "in 3 days", "yesterday", "3 days ago" — nil when the day cannot be read.
    static func fromNow(_ isoDay: String, now: Date = Date()) -> String? {
        guard let d = iso.date(from: isoDay) else { return nil }
        let cal = Calendar(identifier: .gregorian)
        guard let n = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: d)).day else { return nil }
        switch n {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2...: return "in \(n) days"
        default: return "\(-n) days ago"
        }
    }

    /// Whole days from one ISO day to another (nil when either cannot be read).
    static func days(from a: String, to b: String) -> Int? {
        guard let x = iso.date(from: a), let y = iso.date(from: b) else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: x, to: y).day
    }

    /// How long a step takes, in minutes, read from its words: "4–6 h (or overnight)" → 300, "15 min" → 15,
    /// "1 h 30 min" → 90, "2 days" → 2880. A range counts as its middle. nil when no time is written.
    static func minutes(from text: String) -> Double? {
        let pattern = #"(\d+(?:[.,]\d+)?)(?:\s*[–—-]\s*(\d+(?:[.,]\d+)?))?\s*(days?|d|hours?|hrs?|h|minutes?|mins?|m)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        var total = 0.0, found = false
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            func num(_ i: Int) -> Double? {
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : Double(ns.substring(with: r).replacingOccurrences(of: ",", with: "."))
            }
            guard let a = num(1) else { continue }
            let amount = num(2).map { (a + $0) / 2 } ?? a
            let unit = ns.substring(with: m.range(at: 3)).lowercased()
            let per: Double = unit.hasPrefix("d") ? 1440 : (unit.hasPrefix("h") ? 60 : 1)
            total += amount * per; found = true
        }
        return found ? total : nil
    }

    /// A wait of two hours or more (drawn pale in a recipe's time ribbon).
    static func isLongWait(_ minutes: Double) -> Bool { minutes >= 120 }

    /// Splits an ingredient into its amount and the rest: "100 g active starter" → ("100 g", "active starter").
    /// nil when the line does not start with a number.
    static func amount(_ line: String) -> (amount: String, rest: String)? {
        let pattern = #"^\s*((?:\d+(?:[.,/]\d+)?(?:\s*[–-]\s*\d+(?:[.,/]\d+)?)?|½|¼|¾)(?:\s*(?:kg|g|ml|dl|cl|l|tbsp|tsp|cups?|pinch(?:es)?|cloves?|pcs?|%))?)\s+(\S.*)$"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces), ns.substring(with: m.range(at: 2)))
    }
}
