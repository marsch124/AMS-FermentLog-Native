# AMS FermentLog (native)

Jars, bakes and recipes for fermenting and baking. One SwiftUI app for iPhone, iPad and Mac;
the data lives in one file (`fermentlog.json`) in iCloud Drive and is merged per record on every save.

- `project.yml` — XcodeGen spec; run `tools/build.sh` (it generates the project).
- `App/Sources/Model.swift` — the stored records. `Store.swift` — the only thing that touches disk.
- Screens: one file each in `App/Sources`; navigation is `Route` in `Routes.swift`.
- Tests: `Tests/` (data), `UITests/` (screens, found by accessibility identifier).
- Release: `tools/release.sh` (TestFlight), `tools/release-to-testers.py`.
- Never put real data in this (public) repository.
