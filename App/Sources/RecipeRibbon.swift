import SwiftUI

/// The width maths of a recipe's time ribbon.
enum Ribbon {
    /// One width per step. Every piece is at least `minWidth`; the rest is shared in proportion to the minutes
    /// (a step without minutes stays at the minimum). Widths plus gaps add up to `total`.
    /// When even the minimum widths do not fit, all pieces are equal.
    static func widths(minutes: [Double?], total: CGFloat, minWidth: CGFloat, gap: CGFloat) -> [CGFloat] {
        let n = minutes.count
        guard n > 0 else { return [] }
        let avail = max(0, total - gap * CGFloat(n - 1))
        if minWidth * CGFloat(n) >= avail { return Array(repeating: avail / CGFloat(n), count: n) }
        var fixed = Set<Int>()   // pieces held at the minimum
        for (i, m) in minutes.enumerated() where (m ?? 0) <= 0 { fixed.insert(i) }
        var result = Array(repeating: minWidth, count: n)
        while true {
            let free = (0..<n).filter { !fixed.contains($0) }
            let room = avail - minWidth * CGFloat(fixed.count)
            let sum = free.reduce(0.0) { $0 + (minutes[$1] ?? 0) }
            guard !free.isEmpty, sum > 0 else { break }
            var changed = false
            for i in free {
                let w = room * CGFloat((minutes[i] ?? 0) / sum)
                if w < minWidth { fixed.insert(i); changed = true } else { result[i] = w }
            }
            if !changed { break }
        }
        for i in fixed { result[i] = minWidth }
        return result
    }
}

/// One rounded piece per step, as wide as the step takes; pale for a long wait.
struct RecipeRibbon: View {
    let steps: [RecipeStep]
    private let area = Area.recipes
    var body: some View {
        let minutes = steps.map { Human.minutes(from: $0.time) }
        VStack(alignment: .leading, spacing: Theme.tight) {
            GeometryReader { g in
                let w = Ribbon.widths(minutes: minutes, total: g.size.width, minWidth: 18, gap: 2)
                HStack(spacing: 2) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { i, _ in
                        let pale = minutes[i].map { Human.isLongWait($0) } ?? false
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(pale ? area.hero.opacity(0.5) : area.hero)
                            .overlay { Text("\(i + 1)").font(.caption2.weight(.bold)).foregroundStyle(.white).lineLimit(1) }
                            .frame(width: w[i], height: 22)
                    }
                }
            }
            .frame(height: 22)
            Text("Pale = a wait of 2 hours or more \u{00b7} full colour = a shorter step")
                .font(.caption).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recipe-ribbon")
    }
}
