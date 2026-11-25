import SwiftUI

/// The Home tab: jars and bakes with a switch.
struct HomeScreen: View {
    @AppStorage("homeView") private var view = "jars"

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $view) {
                Text("Jars").tag("jars")
                Text("Bakes").tag("bakes")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, Theme.gap)
            .accessibilityIdentifier("home-switch")
            if view == "bakes" { BakesScreen() } else { JarsScreen() }
        }
        .navigationTitle(view == "bakes" ? "Bakes" : "Jars")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Route.search) {
                    HStack(spacing: 4) { Mark(.search).frame(width: 18, height: 18); Text("Search") }
                        .foregroundStyle(Area.search.color)
                }
                .accessibilityIdentifier("open-search")
            }
        }
    }
}
