import SwiftUI

/// "HH:mm" text (as stored) <-> a Date for the time picker.
enum SettingsClock {
    static func date(_ hhmm: String) -> Date {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        let h = p.first ?? 8, m = p.count > 1 ? p[1] : 0
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }
    static func text(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

struct SettingsBurpSection: View {
    @EnvironmentObject var store: Store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @State private var permission: Alarms.Permission = .notAsked

    private func time(_ path: WritableKeyPath<AppSettings, String>) -> Binding<Date> {
        Binding(get: { SettingsClock.date(store.data.settings[keyPath: path]) },
                set: { d in store.updateSettings { $0[keyPath: path] = SettingsClock.text(d) }; Alarms.reschedule(store: store) })
    }

    var body: some View {
        SettingsSection(title: "Burp alarm") {
            DatePicker("Morning", selection: time(\.burpMorning), displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("settings-burp-morning")
            DatePicker("Evening", selection: time(\.burpEvening), displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("settings-burp-evening")
            Toggle("Ring on this \(SettingsDevice.name)", isOn: Binding(
                get: { store.device.burpAlarmHere },
                set: { on in
                    store.device.burpAlarmHere = on
                    if on, permission == .notAsked { Task { _ = await Alarms.askPermission(); permission = await Alarms.permission(); Alarms.reschedule(store: store) } }
                    else { Alarms.reschedule(store: store) }
                }))
                .accessibilityIdentifier("settings-burp-here")
            SettingsNote("Rings for every fermenting jar with a plain lid. Each jar has its own switch. The notification has a Burped button — one tap writes the burp into the jar’s Timeline and plays a burp.")
            permissionLine
        }
        .task { permission = await Alarms.permission() }
        .onChange(of: phase) { _, p in if p == .active { Task { permission = await Alarms.permission() } } }
    }

    @ViewBuilder private var permissionLine: some View {
        switch permission {
        case .allowed:
            HStack(spacing: 6) {
                Text("✓").foregroundStyle(Theme.ok).fontWeight(.bold)
                Text("Notifications are allowed").foregroundStyle(Theme.ok)
            }
            .font(.subheadline).accessibilityElement(children: .combine).accessibilityIdentifier("settings-notify-state")
        case .notAsked:
            VStack(alignment: .leading, spacing: Theme.tight) {
                SettingsNote("Not asked yet")
                Button("Allow notifications") {
                    Task { _ = await Alarms.askPermission(); permission = await Alarms.permission(); Alarms.reschedule(store: store) }
                }
                .buttonStyle(PrimaryButtonStyle(area: .settings)).accessibilityIdentifier("settings-notify-allow")
            }
        case .refused:
            VStack(alignment: .leading, spacing: Theme.tight) {
                Text("Notifications are switched off for FermentLog — turn them on in the system’s Settings")
                    .font(.subheadline).foregroundStyle(Theme.problem).fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") { openSystemSettings() }
                    .buttonStyle(QuietButtonStyle(area: .settings)).accessibilityIdentifier("settings-notify-open")
            }
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) }
        #else
        if let u = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { openURL(u) }
        #endif
    }
}

/// 6.5: the ten burps — Play to hear one, a switch to keep it in the random mix. Kept on this device.
struct SettingsBurpSoundsSection: View {
    @AppStorage(BurpSounds.offKey) private var offStored = ""

    private func isOn(_ n: Int) -> Binding<Bool> {
        Binding(get: { !BurpSounds.offNumbers(offStored).contains(n) },
                set: { on in
                    var off = BurpSounds.offNumbers(offStored)
                    if on { off.remove(n) } else { off.insert(n) }
                    offStored = BurpSounds.stored(off: off)
                })
    }

    var body: some View {
        SettingsSection(title: "Burp sounds") {
            SettingsNote("Every Burped plays one of the burps that are on, picked at random — never the same one twice in a row.")
            ForEach(BurpSounds.all) { s in
                HStack(spacing: 10) {
                    Button("Play") { BurpPlayer.play(s, listen: true) }
                        .buttonStyle(QuietButtonStyle(area: .settings))
                        .accessibilityLabel("Play \(s.name)")
                        .accessibilityIdentifier("settings-burp-play-\(s.number)")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.name)
                        Text(s.line).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 8)
                    Toggle(s.name, isOn: isOn(s.number))
                        .labelsHidden()
                        .accessibilityIdentifier("settings-burp-on-\(s.number)")
                }
            }
            SettingsNote("All off: Burped makes no sound. Your choice is kept on this \(SettingsDevice.name); the iPhone, the iPad and the Mac each keep their own.")
        }
        .accessibilityIdentifier("settings-burp-sounds")
    }
}
