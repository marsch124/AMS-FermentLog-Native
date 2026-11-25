import SwiftUI

/// The three groups of results, each under a heading with its count.
struct SearchResultsList: View {
    let results: SearchResults
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            if !results.batches.isEmpty {
                group("Jars", results.batches.count, "search-group-jars") {
                    ForEach(results.batches) { b in
                        SearchRow(kind: .jar, title: b.title, context: jarContext(b), route: .jar(b.id), id: "search-row-\(b.id)")
                    }
                }
            }
            if !results.bakes.isEmpty {
                group("Bakes", results.bakes.count, "search-group-bakes") {
                    ForEach(results.bakes) { k in
                        SearchRow(kind: .bread, title: k.name.isEmpty ? k.category : k.name,
                                  context: [Human.day(k.bakeDate), k.category].filter { !$0.isEmpty }.joined(separator: " · "),
                                  route: .bake(k.id), id: "search-row-\(k.id)")
                    }
                }
            }
            if !results.recipes.isEmpty {
                group("Recipes", results.recipes.count, "search-group-recipes") {
                    ForEach(results.recipes) { r in
                        SearchRow(kind: .book, title: r.title.isEmpty ? "Untitled recipe" : r.title, context: r.category,
                                  route: .recipe(r.id), id: "search-row-\(r.id)")
                    }
                }
            }
        }
    }

    private func jarContext(_ b: Batch) -> String {
        [Logic.statusLabel(Logic.batchStatus(b)), b.vegetable].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func group<C: View>(_ title: String, _ count: Int, _ id: String, @ViewBuilder _ rows: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            SectionHeading("\(title) \(count)", .search).accessibilityIdentifier(id)
            rows()
        }
    }
}

struct SearchRow: View {
    let kind: MarkKind, title: String, context: String, route: Route, id: String
    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 8) {
                Mark(kind).frame(width: 22, height: 22).foregroundStyle(Area.search.color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).foregroundStyle(Theme.ink)
                    if !context.isEmpty { Text(context).font(.subheadline).foregroundStyle(Theme.muted) }
                }
                Spacer(minLength: 0)
            }
            .card(padding: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
