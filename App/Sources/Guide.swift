import Foundation

/// The single source for the version the app shows, "What's new" and "How it works".
/// (A texts helper fills the placeholders; keep the shape.)
enum Guide {
    static let appVersion = "6.0"

    struct Release: Identifiable {
        let version: String
        let date: String
        let lines: [String]
        var id: String { version }
    }

    static let releases: [Release] = [
        Release(version: "6.0 (build 1)", date: "25 Nov 2026", lines: [
            "New: FermentLog is now a native app for iPhone, iPad and Mac. (Placeholder — the texts are written later.)",
        ]),
    ]

    struct Section: Identifiable {
        let title: String
        let text: String
        var id: String { title }
    }

    static let howItWorks: [Section] = [
        Section(title: "The idea", text: "Placeholder — How it works is written later."),
    ]
}
