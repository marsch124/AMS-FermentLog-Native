# 04 — Tests

Lean: every rule has one small data test (seconds); every main screen one short screen test that finds things by identifier; one flow on the sample Cabbage jar. Apple's run after each push is the safety net.

## Data tests (`Tests/`, XCTest, run on the simulator or the Mac)

| File | What it proves |
|---|---|
| `LogicTests.swift` | Brine (formula, range ends, missing input); days and status; ratings and stars; new-jar defaults; the taste-test reminder (only Taste lines move it; off at 0); statistics and the recommendation (needs two jars rated 4+); CSV and spreadsheet columns; templates and duplicates; own lists; recipes and bakes; bake statistics; search (every word must match); the Timeline (order, step parsing, "2% salt" kept); **burp alarm** (on by lid, own choice wins, off once in the fridge, 14 slots, a burp within 3 hours skips a slot, the "Burped the jar" line has kind "burp"); **steps → recipe** (ingredients, equipment, burps left out); **recipe → jar and the tick list** (name, vegetable, spices, plan, tick adds one Did line once, untick removes it); the web import (tolerant reading of the web backup, twice = no doubles and native edits win, other files refused). |
| `AlarmPlanTests.swift` | The pure alarm plan: a plain-lid jar gives 14 slots in 7 days with the right title, id and body; an airlock jar none unless switched on; a jar in the fridge none; none when this device does not ring; a burp an hour before a slot removes it (13 left); the limit cuts the farthest; the taste reminder lands on the due day at the morning time with its words, and not when this device's switch is off; a due day whose morning time has passed gets none. |
| `StoreTests.swift` | Save and reload on the same folder; two devices that saved different jars from the same start lose nothing; a removed jar stays removed after a merge. |
| `ImportTests.swift` | The same web file twice adds no doubles; wrong files are refused in plain words; an own backup round-trips and restoring joins; the counts line; renaming and removing own vegetables, cuts and spices everywhere. |
| `AITests.swift` | Finding the JSON in a reply (clean or inside prose); turning replies into a recipe, a jar, a taste line and a bake safely (bad date → today, ratings clamped); the request shape and the plain-words error sentences. |
| `XlsxTests.swift` | The workbook is a zip with the sheets and escaped text; the CRC of a known text; a real export builds. |

## Screen tests (`UITests/`, XCUITest)

Everything is found by accessibility identifier, never by words.

- `AppUITests.swift` — `launch(part:sample:extra:)` helper; `testLaunchShowsTheFirstArea`: the Home tab (`tab-home`) on iPhone or the Jars row (`sidebar-jars`) on iPad and Mac exists.
- `ScreenTests.swift` — one test per main screen on the sample data: jars list (`jars-stats`, `jars-start`, the Cabbage row); jar page (`jar-edit`, `jar-burped`, `jar-plan-progress`); jar form (`jar-name`, `cancel`, `save`); recipes (the sauerkraut row, `recipes-new`, then `recipe-edit`, `recipe-start-jar`); bakes (`bake-row-k_sample_1`, `bakes-log`, `bakes-insights`, then `bake-edit`, `bake-duplicate`); insights (`insights-switch`, `insights-total`, `insights-success`); search (`search-field`, typing "cab" finds the jar); settings (`settings-screen`, `settings-appearance`, `settings-guide`, `settings-whats-new`, `settings-version`); and `testCabbageJarFlow`: Burped adds one Timeline line; ticking a To-do step changes the progress and writes a line; two typed lines make two more lines.

These two files are being rewritten alongside the 6.0 texts; the list above is what they contain at the time of writing.

## Launch arguments (UI tests and pictures)

| Argument | Effect |
|---|---|
| `-uiTesting` | Fresh temporary data folder and a separate test `UserDefaults`; alarms and notification permission switched off; no live file watcher |
| `-sample` | Fill the data with the invented sample (Cabbage jar `b_sample_cabbage` with a To-do list, a recipe `r_sample_sauerkraut`, a bake `k_sample_1`, the person "Martin"); only with `-uiTesting` |
| `-part:<name>` | Open on an area: `bakes`, `recipes`, `insights`, `settings`, `search`, `new`; anything else opens Jars |
| `-macLike` | Use the side list even at a compact width |
| `-dark` | Night colours |
| `-needsUpdate` | Pretend a newer version saved the file (red bar, nothing saved) |
| `-saveProblem` | Pretend a save failed (red line in Settings › iCloud) |
