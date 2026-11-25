import SwiftUI

/// The five tabs of the iPhone.
enum HomeTab: String, CaseIterable, Hashable {
    case home, recipes, new, insights, settings
    var title: String {
        switch self {
        case .home: "Home"
        case .recipes: "Recipes"
        case .new: "New"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }
    var area: Area {
        switch self {
        case .home, .new: .jars
        case .recipes: .recipes
        case .insights: .insights
        case .settings: .settings
        }
    }
    var mark: MarkKind {
        switch self {
        case .home: .jar
        case .recipes: .book
        case .new: .plus
        case .insights: .chart
        case .settings: .gear
        }
    }
}

/// iPhone: five tabs, each its own NavigationStack. iPad and Mac: a sidebar and one stack for the area you picked.
struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var phase
    @State private var tab: HomeTab = .home
    @State private var area: Area? = .jars
    @State private var tabPaths: [HomeTab: NavigationPath] = [:]
    @State private var areaPaths: [Area: NavigationPath] = [:]
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    private var wide: Bool {
        #if os(macOS)
        true
        #else
        sizeClass != .compact || ProcessInfo.processInfo.arguments.contains("-macLike")
        #endif
    }
    private var scheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("-dark") ? .dark : store.device.appearance.scheme
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.needsUpdate { UpdateFirstBar() }
            if wide { split } else { tabs }
        }
        .preferredColorScheme(scheme)
        .overlay(alignment: .bottom) {
            if let t = store.toast {
                ToastView(toast: t)
                    .padding(.horizontal, 16).padding(.bottom, wide ? 16 : 70)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: phase) { _, now in if now == .active { store.syncNow() } }
        .onReceive(NotificationCenter.default.publisher(for: .openRoute)) { n in
            if let r = n.object as? Route { push(r) }
        }
        .onAppear(perform: applyLaunchArguments)
    }

    // MARK: iPhone

    private var tabs: some View {
        TabView(selection: $tab) {
            ForEach(HomeTab.allCases, id: \.self) { t in
                NavigationStack(path: tabBinding(t)) {
                    root(t).routes()
                }
                .tint(t.area.color)
                .tabItem {
                    Label { Text(t.title) } icon: { t == .new ? Mark.newButtonImage() : Mark.image(t.mark) }
                        .accessibilityIdentifier("tab-\(t.rawValue)")
                }
                .tag(t)
            }
        }
        .tint(tab.area.color)
    }

    @ViewBuilder private func root(_ t: HomeTab) -> some View {
        switch t {
        case .home: HomeScreen()
        case .recipes: RecipesScreen()
        case .new: NewScreen()
        case .insights: InsightsScreen()
        case .settings: SettingsScreen()
        }
    }

    // MARK: iPad and Mac

    private var split: some View {
        NavigationSplitView {
            List(Area.allCases, selection: $area) { a in
                Label { Text(a.title) } icon: { Mark(a.mark).frame(width: 20, height: 20).foregroundStyle(a.color) }
                    .tag(a)
                    .accessibilityIdentifier("sidebar-\(a.rawValue)")
            }
            .navigationTitle("FermentLog")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            #endif
        } detail: {
            let a = area ?? .jars
            NavigationStack(path: areaBinding(a)) {
                areaRoot(a).navigationTitle(a.title).routes()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("New jar") { push(.jarNew) }
                                Button("New bake") { push(.bakeNew) }
                                Button("New recipe") { push(.recipeNew) }
                            } label: {
                                HStack(spacing: 4) { Mark(.plus).frame(width: 16, height: 16); Text("New") }
                            }
                            .accessibilityIdentifier("new-menu")
                        }
                    }
            }
            .tint(a.color)
            .id(a)
        }
    }

    @ViewBuilder private func areaRoot(_ a: Area) -> some View {
        switch a {
        case .jars: JarsScreen()
        case .bakes: BakesScreen()
        case .recipes: RecipesScreen()
        case .insights: InsightsScreen()
        case .search: SearchScreen()
        case .settings: SettingsScreen()
        }
    }

    // MARK: Paths and routes

    private func tabBinding(_ t: HomeTab) -> Binding<NavigationPath> {
        Binding(get: { tabPaths[t] ?? NavigationPath() }, set: { tabPaths[t] = $0 })
    }
    private func areaBinding(_ a: Area) -> Binding<NavigationPath> {
        Binding(get: { areaPaths[a] ?? NavigationPath() }, set: { areaPaths[a] = $0 })
    }
    /// Pushes a page onto the stack you are looking at.
    private func push(_ r: Route) {
        if wide { let a = area ?? .jars; var p = areaPaths[a] ?? NavigationPath(); p.append(r); areaPaths[a] = p }
        else { var p = tabPaths[tab] ?? NavigationPath(); p.append(r); tabPaths[tab] = p }
    }

    /// Tests and pictures: "-part:recipes" opens on an area.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let a = args.first(where: { $0.hasPrefix("-part:") }) else { return }
        let part = String(a.dropFirst(6))
        // Pictures: "-insights:bakes" picks the Insights view. (A separate word after "-insightsView" reached the Mac as a file to open, and the app then showed no window.)
        if let v = PictureArgs.value("insights") { UserDefaults.standard.set(v, forKey: "insightsView") }
        if part != "bakes" { UserDefaults.standard.set("jars", forKey: "homeView") }   // the Home tab remembers its last view
        switch part {
        case "bakes": UserDefaults.standard.set("bakes", forKey: "homeView"); area = .bakes; tab = .home
        case "recipes": area = .recipes; tab = .recipes
        case "insights": area = .insights; tab = .insights
        case "settings": area = .settings; tab = .settings
        case "search": area = .search; tab = .home; if !wide { push(.search) }
        case "new": tab = .new
        default: area = .jars; tab = .home
        }
        // Pictures: "-openJar:<id>" lands on that jar's page.
        if let j = args.first(where: { $0.hasPrefix("-openJar:") }) { push(.jar(String(j.dropFirst(9)))) }
        // Pictures: "-open:<page>" lands on any page, e.g. -open:jarEdit:<id>, -open:guide (several = pushed in turn).
        for r in PictureArgs.values("open").compactMap(Route.init(argument:)) { push(r) }
        #if os(macOS)
        if PictureArgs.has("settingsWindow") { openSettings() }
        MacPictures.apply()
        #else
        PhonePictures.apply()
        #endif
    }
}

/// The New tab on the iPhone: what do you want to start?
struct NewScreen: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            row("New jar", "Start a jar of vegetables to ferment.", .jarNew, .jars, "new-jar")
            row("New bake", "Log a loaf or another bake.", .bakeNew, .bakes, "new-bake")
            row("New recipe", "Write one down, with its ingredients and timed steps.", .recipeNew, .recipes, "new-recipe")
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle("New")
    }

    private func row(_ title: String, _ note: String, _ route: Route, _ area: Area, _ id: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.tight) {
            NavigationLink(value: route) {
                HStack { Mark(area.mark).frame(width: 20, height: 20); Text(title); Spacer(minLength: 0) }
            }
            .buttonStyle(PrimaryButtonStyle(area: area))
            .accessibilityIdentifier(id)
            Text(note).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// The red bar of a device that is a version behind.
struct UpdateFirstBar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Update this device first").font(.subheadline.weight(.bold))
            Text("A newer version of the app saved your data. Changes made here are not saved until this device is updated in TestFlight.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(day: 0xC9271F, night: 0xA8201A))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("update-first-bar")
    }
}

/// The one-line message with Undo.
struct ToastView: View {
    @EnvironmentObject var store: Store
    let toast: Toast
    var body: some View {
        HStack(spacing: 12) {
            Text(toast.text).font(.subheadline)
            if let undo = toast.undo {
                Button("Undo") { undo(); store.hideToast() }
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("toast-undo")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .accessibilityIdentifier("toast")
    }
}
