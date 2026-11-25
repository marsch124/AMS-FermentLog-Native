import SwiftUI

/// One search over jars, bakes and recipes, results as you type.
struct SearchScreen: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let r = Logic.searchAll(q, batches: store.data.liveBatches, bakes: store.data.liveBakes, recipes: store.data.liveRecipes)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                HStack(spacing: 8) {
                    Mark(.search).frame(width: 20, height: 20).foregroundStyle(Area.search.color)
                    TextField("Search", text: $query)
                        .focused($focused)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .accessibilityIdentifier("search-field")
                    if !query.isEmpty {
                        Button("Clear") { query = "" }
                            .font(.subheadline).foregroundStyle(Area.search.color)
                            .accessibilityIdentifier("search-clear")
                    }
                }
                .padding(10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                if q.isEmpty {
                    Text("Search looks through names, vegetables, spices, taste notes, the steps you did, bake problems, ingredients, equipment and recipe steps.")
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("search-hint")
                } else if r.total == 0 {
                    Text("Nothing found for “\(q)”.")
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("search-none")
                } else {
                    SearchResultsList(results: r)
                }
            }
            .page()
        }
        .background(Theme.bg)
        .navigationTitle("Search")
        .onAppear { focused = true }
    }
}
