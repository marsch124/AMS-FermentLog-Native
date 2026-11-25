import SwiftUI

/// Every page a stack can push. One shared `routeDestination(_:)` turns a route into its screen, on iPhone and on iPad/Mac.
enum Route: Hashable {
    case jar(String), jarEdit(String), jarNew
    case recipe(String), recipeEdit(String), recipeNew
    case bake(String), bakeEdit(String), bakeNew
    case bakeInsights
    case search, guide, whatsNew, manageLists, safetyCopies
}

@MainActor @ViewBuilder
func routeDestination(_ route: Route) -> some View {
    switch route {
    case .jar(let id): JarDetailScreen(batchID: id)
    case .jarEdit(let id): JarFormScreen(batchID: id)
    case .jarNew: JarFormScreen(batchID: nil)
    case .recipe(let id): RecipeDetailScreen(recipeID: id)
    case .recipeEdit(let id): RecipeFormScreen(recipeID: id)
    case .recipeNew: RecipeFormScreen(recipeID: nil)
    case .bake(let id): BakeDetailScreen(bakeID: id)
    case .bakeEdit(let id): BakeFormScreen(bakeID: id)
    case .bakeNew: BakeFormScreen(bakeID: nil)
    case .bakeInsights: BakeInsightsScreen()
    case .search: SearchScreen()
    case .guide: GuideScreen()
    case .whatsNew: WhatsNewScreen()
    case .manageLists: ManageListsScreen()
    case .safetyCopies: SafetyCopiesScreen()
    }
}

extension View {
    /// Put this on the root of every NavigationStack so a `NavigationLink(value: Route…)` finds its page.
    func routes() -> some View {
        navigationDestination(for: Route.self) { routeDestination($0) }
    }
}

extension Notification.Name {
    /// Asks the visible stack to push a route (Mac menu commands, Help menu).
    static let openRoute = Notification.Name("openRoute")
}
