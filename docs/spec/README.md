# AMS FermentLog — specification, version 6.1, build 4 (25 Nov 2026)

This folder describes the app exactly as it is built in 6.0, written from the code. FermentLog 6.0 is a native app for iPhone, iPad and Mac that replaces the web app (last web version 5.25). The numbering simply continues: the native app starts at 6.0.

## The pages

| File | What it holds |
|---|---|
| `README.md` (this page) | What the app is, platforms, where the data lives, the version policy |
| `01-data.md` | Every stored record and field, the file and folders, how devices merge, tombstones, the format number, safety copies, pictures, per-device settings |
| `02-screens.md` | Every screen and sheet: what it shows, every control with its exact words and accessibility identifier |
| `03-rules.md` | Every rule in `Logic.swift`, `AlarmPlan.swift`, `Alarms.swift`, the web import, with numbers |
| `04-tests.md` | Every test file, what it proves, the UI-test launch arguments |

## What the app is

A private logbook for fermenting jars (vegetables in brine), for baking (bakes), for recipes and for the lessons learned. For each jar: the set-up (brine, temperature, spices, equipment), a Timeline of what was done and how it tasted, a burp alarm, a taste-test reminder, a verdict. Recipes can start a jar with a to-do list, and a jar's steps can become a recipe. Insights shows what makes the best jars and bakes. An optional AI assistant (the owner's own Anthropic key) fills in forms from a description.

## Platforms

One Xcode target builds iPhone, iPad and Mac (`project.yml`, XcodeGen). Minimums: iOS 17.0, macOS 14.0. Bundle identifier `com.schabbauer.AMSFermentLog`; display name `FermentLog`; App Store category Lifestyle (never Food & Drink: TestFlight refuses Mac installs with it). iPhone and iPad run in all four orientations. Permissions asked for: camera ("The camera takes pictures of your jars, bakes and recipes."), notifications (asked from Settings › Burp alarm, never at launch), iCloud Documents. Entitlements: iCloud container `iCloud.com.schabbauer.AMSFermentLog` (CloudDocuments), App Sandbox, network client (AI), camera, user-selected files read/write.

| | iPhone | iPad | Mac |
|---|---|---|---|
| Navigation | Five tabs: Home, Recipes, New, Insights, Settings | A list at the side: Jars, Bakes, Recipes, Insights, Search, Settings, plus a "New" menu (New jar, New bake, New recipe) at the top right | The same side list and New menu; default window 1040 × 720; menu commands ⌘N, ⌥⌘N, ⇧⌘N, ⌘F, Help menu; ⌘, opens Settings in its own window (at least 520 × 560) |
| Notification defaults | Burp alarm and taste reminder on for this device | Off | Off |
| Edit pages | Cancel left, Save right | Same | Same; Escape = Cancel |
| Camera | Take a picture and Add pictures | Same | Add pictures only |

The side list is used whenever the width is not compact (always on the Mac; the launch argument `-macLike` forces it for tests).

## Where the data lives

One file and two folders in iCloud Drive (container Documents, shown in Files as "FermentLog"): `fermentlog.json`, `Photos/`, `Safety copies/`. Without iCloud Drive the same layout is used in Application Support, `AMSFermentLog`. UI tests get a fresh temporary folder each run. Full detail in `01-data.md`.

## Version policy

- `Guide.appVersion` in `App/Sources/Guide.swift` is the single source of the version the app shows (Settings, last row: "Version 6.0 (1)"). The build settings carry the same `MARKETING_VERSION` 6.0 and `CURRENT_PROJECT_VERSION` 1; `tools/release.sh <build>` passes the build number.
- Every new version adds a What's new entry at the top of `Guide.releases` (what was there before, what is there now, with numbers), updates every How it works section that changed (and "Signs in this app"), and updates these pages.
- Every version that adds a stored field raises `AppData.currentFormat` (now 1) by one. A device on an older version then says "Update this device first" and writes nothing (see `01-data.md`).
- Releases: `tools/build.sh` generates the project and builds for the simulator; `tools/release.sh` archives iPhone/iPad and Mac and uploads to TestFlight.
- The repository is public: no real data is ever put in it. `SampleData.swift` holds invented sample jars used only by tests (`-sample`).
