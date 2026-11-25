import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Launch arguments for pictures and screen tests. They act only together with "-uiTesting" (sample data in a
/// throw-away folder), so they can never touch real jars. `tools/mac-pictures.sh` uses them to photograph every
/// Mac page without a click (Mac screen tests need a fingerprint each run).
enum PictureArgs {
    private static let args = ProcessInfo.processInfo.arguments
    static var on: Bool { args.contains("-uiTesting") }
    /// "-open:guide" → "guide"; nil when absent.
    static func value(_ name: String) -> String? { values(name).first }
    static func values(_ name: String) -> [String] {
        guard on else { return [] }
        let p = "-\(name):"
        return args.filter { $0.hasPrefix(p) }.map { String($0.dropFirst(p.count)) }
    }
    static func has(_ flag: String) -> Bool { on && args.contains("-\(flag)") }
}

extension Route {
    /// "jarEdit:b_sample_cabbage", "recipeNew", "guide" … (pictures only).
    init?(argument a: String) {
        let p = a.split(separator: ":", maxSplits: 1).map(String.init)
        let id = p.count > 1 ? p[1] : ""
        switch p.first ?? "" {
        case "jar": self = .jar(id)
        case "jarEdit": self = .jarEdit(id)
        case "jarNew": self = .jarNew
        case "recipe": self = .recipe(id)
        case "recipeEdit": self = .recipeEdit(id)
        case "recipeNew": self = .recipeNew
        case "bake": self = .bake(id)
        case "bakeEdit": self = .bakeEdit(id)
        case "bakeNew": self = .bakeNew
        case "bakeInsights": self = .bakeInsights
        case "search": self = .search
        case "guide": self = .guide
        case "whatsNew": self = .whatsNew
        case "manageLists": self = .manageLists
        case "safetyCopies": self = .safetyCopies
        default: return nil
        }
    }
}

#if os(macOS)
/// Mac pictures: "-tall" makes the window as tall as the screen, "-scrollDown:600" moves the page down by 600 points.
@MainActor
enum MacPictures {
    static func apply() {
        guard PictureArgs.on else { return }
        if PictureArgs.has("dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }   // as if the Mac itself were in dark mode
        if PictureArgs.has("tall") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for w in NSApp.windows where w.isVisible && w.styleMask.contains(.titled) && !w.isSheet {   // never a pop-up form: it keeps its own size
                    guard let v = (w.screen ?? NSScreen.main)?.visibleFrame else { continue }
                    var f = w.frame
                    f.size.height = v.height; f.origin.y = v.minY
                    w.setFrame(f, display: true)
                }
            }
        }
        if let p = PictureArgs.value("scrollDown").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { scrollDown(CGFloat(p)) }
        }
    }

    /// Moves the page of every window (its widest scroll area; the sidebar is narrow) down by `points`.
    private static func scrollDown(_ points: CGFloat) {
        for w in NSApp.windows where w.isVisible {
            guard let root = w.contentView else { continue }
            var found: [NSScrollView] = []
            func walk(_ v: NSView) { if let s = v as? NSScrollView { found.append(s) }; v.subviews.forEach(walk) }
            walk(root)
            guard let page = found.max(by: { $0.frame.width < $1.frame.width }), let doc = page.documentView else { continue }
            let clip = page.contentView
            let room = max(0, doc.frame.height - clip.bounds.height)
            var o = clip.bounds.origin
            o.y = doc.isFlipped ? min(room, o.y + points) : max(0, o.y - points)
            clip.scroll(to: o)
            page.reflectScrolledClipView(clip)
        }
    }
}
#endif

#if os(iOS)
/// iPhone and iPad pictures: "-scrollDown:600" moves the page down by 600 points (tools/phone-pictures.sh),
/// so every part of a long page can be photographed in the simulator without a screen test.
@MainActor
enum PhonePictures {
    static func apply() {
        guard PictureArgs.on, let p = PictureArgs.value("scrollDown").flatMap(Double.init) else { return }
        tryScroll(CGFloat(p), left: 12)
    }

    /// The page may not be laid out yet right after launch: look for it every 0.4 s (up to 12 times), scroll once.
    private static func tryScroll(_ points: CGFloat, left: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (left == 12 ? 1.4 : 0.4)) {
            if !scrollDown(points), left > 1 { tryScroll(points, left: left - 1) }
        }
    }

    /// Moves the page on show (the tallest scrolling page that is in a window and visible) down by `points`, never past its end.
    private static func scrollDown(_ points: CGFloat) -> Bool {
        var done = false
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for w in scene.windows {
                var found: [UIScrollView] = []
                func walk(_ v: UIView) {
                    if v.isHidden || v.alpha < 0.01 { return }
                    if let s = v as? UIScrollView, s.window != nil, s.bounds.height > 200 { found.append(s) }
                    v.subviews.forEach(walk)
                }
                walk(w)
                // The page on top of the stack is the last one found; an earlier page of the stack can still be in the window.
                guard let page = found.last(where: { $0.contentSize.height > $0.bounds.height + 20 }) else { continue }
                let room = max(0, page.contentSize.height + page.adjustedContentInset.bottom - page.bounds.height)
                page.setContentOffset(CGPoint(x: page.contentOffset.x, y: min(room, page.contentOffset.y + points)), animated: false)
                done = true
            }
        }
        return done
    }
}
#endif
