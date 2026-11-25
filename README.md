# AMS FermentLog (native)

A logbook for fermenting jars, baking and recipes: brine and conditions, a Timeline of what you did and how it
tasted, a burp alarm with a Burped button on the notification, taste-test reminders, recipes with a to-do list,
bakes, lessons and Insights. One SwiftUI app for iPhone, iPad and Mac; it replaces the web app (last version 5.25),
so the numbering continues at 6.0. The data is one file (`fermentlog.json`) with a Photos folder and daily safety
copies in iCloud Drive, merged record by record on every save.

- Build (generates the Xcode project, builds for the iPhone simulator): `tools/build.sh` (`tools/build.sh test` runs the tests).
- Release to TestFlight (iPhone/iPad and Mac): `tools/release.sh <build number> [ios|mac|both]`, then `tools/release-to-testers.py`.
- The written specification is in `docs/spec/` (data, screens, rules, tests); what to try on each TestFlight build is in `docs/what-to-test/`.
- The texts inside the app (How it works, What's new) are in `App/Sources/Guide.swift`; every release updates them and the spec.
- Code: `App/Sources/` (`Model.swift` the stored records, `Logic.swift` and `AlarmPlan.swift` the rules, `Store.swift` the only thing that touches disk, one file per screen), tests in `Tests/` and `UITests/`.
- This repository is public: never put real data in it (the sample data in `SampleData.swift` is invented).
