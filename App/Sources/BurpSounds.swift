import Foundation
import AVFoundation

/// 6.5: the ten burps. Every Burped (on a reminder and on a jar's page) plays one of the burps that are on,
/// picked at random, never the same one twice in a row. Kept per device: the iPhone, iPad and Mac each choose.
struct BurpSound: Identifiable, Equatable {
    let number: Int
    let name: String
    let line: String
    var id: Int { number }
    /// The file in the app (made by tools/make-burp.py).
    var file: String { String(format: "burp-%02d.caf", number) }
}

enum BurpSounds {
    static let all: [BurpSound] = [
        BurpSound(number: 1, name: "Classic", line: "A plain, honest burp"),
        BurpSound(number: 2, name: "Short pop", line: "Quick and done"),
        BurpSound(number: 3, name: "Deep rumble", line: "Low, from the cellar"),
        BurpSound(number: 4, name: "Long one", line: "Takes its time"),
        BurpSound(number: 5, name: "Squeaky", line: "High and small"),
        BurpSound(number: 6, name: "Double", line: "Two in a row"),
        BurpSound(number: 7, name: "Gurgle", line: "Wet and wobbly"),
        BurpSound(number: 8, name: "Rising", line: "Ends going up, like a question"),
        BurpSound(number: 9, name: "Tiny", line: "A polite little one"),
        BurpSound(number: 10, name: "Big one", line: "Loud and rough"),
    ]

    /// UserDefaults: the numbers switched OFF ("3,7"); missing or empty = all on, so a burp added later starts on.
    static let offKey = "burpSoundsOff"
    /// UserDefaults: the number played last.
    static let lastKey = "burpSoundLast"

    static func sound(_ number: Int) -> BurpSound? { all.first { $0.number == number } }

    // MARK: Pure (tested)

    static func offNumbers(_ stored: String?) -> Set<Int> {
        Set((stored ?? "").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
    }

    static func stored(off: Set<Int>) -> String { off.sorted().map(String.init).joined(separator: ",") }

    /// The burps that are on, in list order.
    static func on(off stored: String?) -> [BurpSound] {
        let off = offNumbers(stored)
        return all.filter { !off.contains($0.number) }
    }

    /// One of the burps that are on; never `last` when two or more are on; nil when none is on.
    /// `roll` is any whole number (random in the app, fixed in tests).
    static func pick(on: [BurpSound], last: Int?, roll: Int) -> BurpSound? {
        let choices = on.count > 1 ? on.filter { $0.number != last } : on
        guard !choices.isEmpty else { return nil }
        return choices[abs(roll) % choices.count]
    }

    // MARK: This device

    static func isOn(_ number: Int, defaults: UserDefaults = .standard) -> Bool {
        !offNumbers(defaults.string(forKey: offKey)).contains(number)
    }

    static func set(_ number: Int, on: Bool, defaults: UserDefaults = .standard) {
        var off = offNumbers(defaults.string(forKey: offKey))
        if on { off.remove(number) } else { off.insert(number) }
        defaults.set(stored(off: off), forKey: offKey)
    }

    /// Picks the next burp for this device and remembers it (nil when all are off).
    static func next(defaults: UserDefaults = .standard) -> BurpSound? {
        let last = defaults.object(forKey: lastKey) as? Int
        let s = pick(on: on(off: defaults.string(forKey: offKey)), last: last, roll: Int.random(in: 0..<1_000_000))
        if let s { defaults.set(s.number, forKey: lastKey) }
        return s
    }
}

/// Plays a burp inside the app. `listen` (Play in Settings) sounds even with the iPhone on silent;
/// the jar page's Burped follows the silent switch, like the reminder does.
@MainActor
enum BurpPlayer {
    private static var player: AVAudioPlayer?

    static func play(_ sound: BurpSound, listen: Bool = false) {
        guard let url = Bundle.main.url(forResource: (sound.file as NSString).deletingPathExtension, withExtension: "caf") else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(listen ? .playback : .ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
