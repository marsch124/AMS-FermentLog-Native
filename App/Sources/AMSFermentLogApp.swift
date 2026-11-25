import SwiftUI

@main
struct AMSFermentLogApp: App {
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        // 🚨 Mac: NO modifiers on the view inside the WindowGroup that change its type between launches,
        // and a fixed id — otherwise the Mac app can start with no window.
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(store)
        }
        // Alarm hooks sit on the scene, never on the window's view (a Mac trap). `initial: true` = once at launch.
        .onChange(of: phase, initial: true) { _, now in
            Alarms.setUp(store: store)
            if now == .active { Alarms.reschedule(store: store); Task { try? await Task.sleep(nanoseconds: 500_000_000); Alarms.deliverPendingRoute() } }
        }
        .onChange(of: store.data) { _, _ in Alarms.reschedule(store: store) }
        .onChange(of: store.device) { _, _ in Alarms.reschedule(store: store) }
        #if os(macOS)
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New jar") { post(.jarNew) }.keyboardShortcut("n")
                Button("New bake") { post(.bakeNew) }.keyboardShortcut("n", modifiers: [.command, .option])
                Button("New recipe") { post(.recipeNew) }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .textEditing) {
                Button("Search") { post(.search) }.keyboardShortcut("f")
            }
            CommandGroup(replacing: .help) {
                Button("How it works") { post(.guide) }
                Button("What's new") { post(.whatsNew) }
            }
        }
        #endif
        #if os(macOS)
        // ⌘, opens Settings in its own window, as Mac apps do.
        Settings {
            NavigationStack { SettingsScreen().routes() }
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 560)
        }
        #endif
    }

    #if os(macOS)
    private func post(_ r: Route) { NotificationCenter.default.post(name: .openRoute, object: r) }
    #endif
}
