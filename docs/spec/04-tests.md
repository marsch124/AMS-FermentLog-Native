# 04 — Tests

Lean: every rule has one small data test (seconds); every main screen one short screen test that finds things by identifier; one flow on the sample Cabbage jar. Apple's run after each push is the safety net.

## Data tests (`Tests/`, XCTest, run on the simulator or the Mac)

| File | What it proves |
|---|---|
| `LogicTests.swift` | Brine (formula, range ends, missing input); days and status; ratings and stars; new-jar defaults; the taste-test reminder (only Taste lines move it; off at 0); statistics and the recommendation (needs two jars rated 4+); CSV and spreadsheet columns; templates and duplicates; own lists; recipes and bakes; bake statistics; search (every word must match); the Timeline (order, step parsing, "2% salt" kept); **burp alarm** (on by lid, own choice wins, off once in the fridge, 14 slots, a burp within 3 hours skips a slot, the "Burped the jar" line has kind "burp"); **steps → recipe** (ingredients, equipment, burps left out); **recipe → jar and the tick list** (name, vegetable, spices, plan, tick adds one Did line once, untick removes it); the web import (tolerant reading of the web backup, twice = no doubles and native edits win, other files refused); **moving steps** (`testMoveStep`: `Logic.moveStep` — a step dropped on another step takes that step's place; dropping it on itself or on an unknown step changes nothing). |
| `PictureArgsTests.swift` | Two tests for the picture-mode launch arguments (see "Mac picture mode" below): the arguments are read only together with `-uiTesting`, and each one gives the expected page, sample data and look. |
| `AlarmPlanTests.swift` | The pure alarm plan: a plain-lid jar gives 14 slots in 7 days with the right title, id and body; an airlock jar none unless switched on; a jar in the fridge none; none when this device does not ring; a burp an hour before a slot removes it (13 left); the limit cuts the farthest; the taste reminder lands on the due day at the morning time with its words, and not when this device's switch is off; a due day whose morning time has passed gets none; `testBurpedNote` (6.5): the Burped note's id `burped.<jarid>`, title "Burped: <jar>", body with the time as 08:12 and "Burp: Deep rumble.", and the sound file of that burp. |
| `BurpSoundsTests.swift` | 6.5. `testDefaultAllOn` (missing or empty = all 10 on; "3,7" = 8 on); `testPickStaysInTheMix` (always one of the on ones, never the last one when two or more are on, the only one when one is on, nil when none); `testFilesShip` (all 10 burp files are in the app). |
| `StoreTests.swift` | Save and reload on the same folder; two devices that saved different jars from the same start lose nothing; a removed jar stays removed after a merge. |
| `ImportTests.swift` | The same web file twice adds no doubles; wrong files are refused in plain words; an own backup round-trips and restoring joins; the counts line; renaming and removing own vegetables, cuts and spices everywhere. |
| `AITests.swift` | Finding the JSON in a reply (clean or inside prose); turning replies into a recipe, a jar, a taste line and a bake safely (bad date → today, ratings clamped); the request shape and the plain-words error sentences. |
| `XlsxTests.swift` | The workbook is a zip with the sheets and escaped text; the CRC of a known text; a real export builds. |

## Screen tests (`UITests/`, XCUITest)

Everything is found by accessibility identifier, never by words.

- `AppUITests.swift` — `launch(part:sample:extra:)` helper; `testLaunchShowsTheFirstArea`: the Home tab (`tab-home`) on iPhone or the Jars row (`sidebar-jars`) on iPad and Mac exists.
- `ScreenTests.swift` — one test per main screen on the sample data: jars list (`jars-stats`, `jars-start`, the Cabbage row); jar page (`jar-edit`, `jar-burped`, `jar-plan-progress`); jar form (`jar-name`, `cancel`, `save`); recipes (the sauerkraut row, `recipes-new`, then `recipe-edit`, `recipe-start-jar`); bakes (`bake-row-k_sample_1`, `bakes-log`, `bakes-insights`, then `bake-edit`, `bake-duplicate`); insights (`insights-switch`, `insights-total`, `insights-success`); search (`search-field`, typing "cab" finds the jar); settings (`settings-screen`, `settings-appearance`, `settings-guide`, `settings-whats-new`, `settings-version`); and `testCabbageJarFlow`: Burped adds one Timeline line; ticking a To-do step changes the progress and writes a line; two typed lines make two more lines.

These two files are being rewritten alongside the 6.0 texts; the list above is what they contain at the time of writing.

## Mac picture mode (6.0 build 2)

`tools/mac-pictures.sh` photographs every Mac page by day and by night, with the sample data and without a single click. It starts the Mac app with launch arguments read in `App/Sources/PictureArgs.swift`; they work only together with `-uiTesting`, so a normal start of the app never sees them. The two data tests in `Tests/PictureArgsTests.swift` prove the reading of these arguments.

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
| `-charts` | With `-sample`: five more finished, rated jars, so Insights draws its charts (pictures only) |
| `-samplePhoto` | With `-sample`: the Cabbage jar gets a made-up picture (pictures only) |
| `-insights:<view>` | Pick the Insights view: `ferments` or `bakes` (a separate word after `-insightsView` reaches the Mac as a file to open, and the app then shows no window) |
| `-scrollDown:<points>` | Move the page down before the picture is taken — Mac and, since 6.1, iPhone and iPad |

## Added in 6.1 (the Full colour look)

- `Tests/LookTests.swift` — `LookTests` (4: a day in plain words, "in 3 days", minutes read from a step's words incl. weeks, the amount of an ingredient) and `JarLookTests` (2: the Timeline grouped by day with a shared time written once, the line to the next taste test).
- `Tests/RibbonTests.swift` — 1: the widths of the recipe time ribbon.
- Pictures without a screen test: `tools/mac-pictures.sh` (`QUIET=1` opens the windows behind his work, `ONLY="02 14"` picks pages) and the new `tools/phone-pictures.sh <simulator-udid>` for iPhone and iPad.

## Added in 6.3 (tile filter and picture viewer)

- `JarsFilterTests` — 1 data test: `Logic.jars(_:showing:)` returns every live jar for nil and only the jars of that status for a choice.
- `ScreenTests.testPhotoViewer` — opens the Cabbage jar with `-samplePhoto`, taps the head picture (`jar-head-photo`), sees `photo-viewer`, taps Done (`photo-viewer-done`).

| Argument (6.3, pictures only) | Effect |
|---|---|
| `-jarsShowing:<state>` | Open the Jars list with one tile chosen: `fermenting`, `fridge` or `done` |
| `-openViewer` | With `-open:jar:<id>`: open the jar's head picture large (use with `-samplePhoto`) |

## Added in 6.4 (find and sort jars)

- `JarsFindSortTests` — 2 data tests: `Logic.jars(_:matching:)` (name or vegetable, capitals and accents ignored, empty or spaces-only text keeps all) and `Logic.sortJars(_:by:)` (`.startDate` keeps the old order with due jars first; `.name` is A to Z).

| Argument (6.4, pictures only) | Effect |
|---|---|
| `-jarsFind:<text>` | Open the Jars list with that text in the find box |
| `-jarsSort:name` | Open the Jars list sorted by Name |
