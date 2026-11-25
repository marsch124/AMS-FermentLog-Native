import SwiftUI

/// The Home tab: jars and bakes with a switch.
struct HomeScreen: View {
    @AppStorage("homeView") private var view = "jars"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Segments(selection: $view, options: [("jars", "Jars"), ("bakes", "Bakes")], area: view == "bakes" ? .bakes : .jars, id: "home-switch")
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home-switch")
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.top, Theme.gap)
            if view == "bakes" { BakesScreen() } else { JarsScreen() }
        }
        .background(AreaBackdrop(area: view == "bakes" ? .bakes : .jars))
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
