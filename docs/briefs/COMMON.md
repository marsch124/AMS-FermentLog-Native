# Common brief for every lane helper — AMS FermentLog native 6.0

You are one of six helpers, each filling ONE part of a new native SwiftUI app (iPhone + iPad + Mac, one target).
The app is a faithful native rebuild of a web app, plus a few new features named in your own brief.

- Web app (the reference for WHAT each screen shows and does — read the parts named in your brief; never edit):
  "/Users/martinschabbauer/Documents/01 Leisure/30 App Development/AMS FermentLog"  (js/app.js screens, js/model.js rules, styles.css look)
- Your working copy is a git worktree of the native repo (path in your brief). Work ONLY there. Never touch another worktree,
  ~/Developer/AMS-FermentLog-Native itself, any other app folder, any simulator, or the network (no git push, no Apple, no GitHub).

## Read first (in your worktree)
App/Sources/Model.swift (stored types) · Logic.swift (all rules — USE them, never re-implement a rule in a view) · Store.swift
(public API: `store.data`, `store.save(_:)`, `store.remove(batch:)`…, `store.restore(batch:)`…, `store.update`, `store.updateSettings`,
`store.addPhoto`, `store.photoURL`, `store.showToast(_:undo:)`, `store.device`) · Theme.swift (Area colours, PrimaryButtonStyle,
QuietButtonStyle, Pill, Tag, SectionHeading, Theme.gap) · Components.swift (StarRating, Stars, ChipPicker, FlowLayout, LoggedByPicker,
PhotoStrip, Fact, Block, `.cancelSave(...)`, `.page()`) · Marks.swift (`Mark(.jar)` hand-drawn marks) · Routes.swift (Route + how
screens are pushed) · RootView.swift · SampleData.swift · AI.swift and Alarms.swift (contracts; call them, another lane fills them).

## Files
Edit ONLY the files your brief lists, and new files whose names start with your lane's prefix. If you need something in a shared file,
write an `extension` in one of your own files instead. The screen names and initialisers in the stub files are a contract — keep them.
The Xcode project file is generated and not in git: run `xcodegen generate` after adding files.

## The owner's rules for how it looks and works (he is strict about these)
1. Compact: minimal padding and spacing (Theme.gap / Theme.tight), Apple's standard text styles only (.body, .subheadline, .caption…
   never a fixed font size), rows as tall as their words. No big empty cards.
2. Colourful: every heading, button and mark of your part uses YOUR Area's colour (Area.jars / .bakes / .recipes / .insights / .search /
   .settings). Must be pleasing by day AND by night — use Theme colours, never hard-coded black/white/grey.
3. The main button of a page is FULL colour (PrimaryButtonStyle(area:)) — never grey. Secondary buttons: QuietButtonStyle.
4. Every page where something is changed has Cancel and Save (use `.cancelSave(area:canSave:onCancel:onSave:)`); on the Mac Escape = Cancel.
   Nothing is saved before Save is pressed. Small one-tap actions on a detail page (tick, Burped, add a line) save at once.
5. Icons: only the hand-drawn `Mark(...)` drawings for the app's own marks. NO emoji anywhere, NO SF Symbols as decoration.
   (System-provided chevrons/controls inside standard SwiftUI controls are fine.) A button that would be only a symbol gets a WORD.
6. A mark or colour means ONE thing in the whole app: ✓ only ever means "this is in order"; never use ✕ — write "Delete" / "Remove".
   Status pills: Fermenting = Theme.brand, In the fridge = a blue (Color(day: 0x3A7CA5, night: 0x7DB7DC)), Done = Theme.ok.
   Timeline tags: "Did" = Theme.brand, "Taste" = Theme.ok. Problems = Theme.problem. Stars = a 1–5 rating.
7. A figure sits right beside its name, on the LEFT (use `Fact(name:value:)`) — never pushed to the far right edge.
8. A list the user puts in order is arranged by DRAG AND DROP (.onMove) — never up/down arrow buttons.
9. When a tap is not obvious, the screen itself says what it does in a short caption (e.g. "Tap a line to change it").
10. Deleting asks first (confirmationDialog) OR offers Undo (`store.showToast("Jar removed", undo: { store.restore(batch: id) })`).
11. Words: plain everyday English, British spelling, no computer talk. Dates as 2026-11-25, times as 10:30 (Logic.isoDay / Logic.clock).
12. iPhone, iPad and Mac from the same code: guard UIKit-only API with `#if os(iOS)`; lay out so a wide window (iPad/Mac) looks
    intended — content column max ~720 wide (`.page()`), forms as `Form` with `.formStyle(.grouped)`.
13. EVERY control a person can tap gets `.accessibilityIdentifier("…")` (kebab-case, stable, lane-prefixed, rows with their record id,
    e.g. "jar-row-<id>"). Screen tests will find things only by identifier.
14. Empty states: one short friendly sentence and the one full-colour button that fixes it.

## Build (both must succeed before you report) — no simulators, no signing
  cd <your worktree> && xcodegen generate
  xcodebuild build -project AMSFermentLog.xcodeproj -scheme AMSFermentLog -destination 'generic/platform=iOS Simulator' -derivedDataPath "$TMPDIR/aflog-dd-<lane>" -skipPackageUpdates CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
  xcodebuild build -project AMSFermentLog.xcodeproj -scheme AMSFermentLog -destination 'platform=macOS' -derivedDataPath "$TMPDIR/aflog-dd-<lane>" -skipPackageUpdates CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
Then `git add -A && git commit -m "<lane>: …"` on your branch. Do not merge, do not push.

## Report — ONCE, at most 25 lines
Files and line counts · both build results · every accessibility identifier you added (grouped by screen) · the exact words of the
main controls and headings on each screen (the guide is written from this) · anything from the web screen you did NOT carry over and why ·
anything you need from another lane.
