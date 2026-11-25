# 03 — Rules

Every rule in `Logic.swift`, `AlarmPlan.swift`, `Alarms.swift`, `SettingsListEdit` and the web import, in words with numbers. All dates and clock times are the device's local ones (the web app used universal time in a few places). `Logic` is Foundation only, so everything here is covered by the data tests.

## Lists built into the app

- Vegetables: Carrot, Cabbage, Cucumber, Beetroot, Cauliflower, Green beans, Radish, Garlic, Onion, Pepper.
- Forms (cuts): Sticks, Slices, Rounds, Cubes, Spears, Wedges, Shredded, Grated, Chopped, Florets, Whole, Halved.
- Lids: Airlock, Burping / self-venting lid, Plain lid, Cloth / open. Weights: Glass weight, Ceramic weight, Cabbage leaf, Smaller jar, None.
- Spices: Garlic, Dill, Mustard seed, Black pepper, Bay leaf, Ginger, Chilli.
- Jar problems: Mould, Kahm yeast, Mushy / soft, Too salty, Not sour enough, Off smell. Bake problems: Dense crumb, Gummy, Flat / didn’t rise, Over-proofed, Under-proofed, Burnt, Pale crust.
- Bake categories: Sourdough, Bread, Other. Recipe categories: Sourdough, Vegetable ferment, Drink / kombucha, Dairy, Other.
- His own vegetables, cuts and spices are kept in `AppSettings` beside the built-in ones; a new one is added when a jar that uses it is saved. `splitVegForm` splits an old combined name ("Carrot sticks") into vegetable and form only when the last word is a known form.

## Brine

`brine % = salt ÷ (salt + water) × 100` (1 ml of water counts as 1 g). Nothing if salt or water is missing, negative, or both are 0. The sweet spot is from 2.0 % to 3.0 %, both ends included (`BRINE_MIN`, `BRINE_MAX`); outside it is only a hint ("typical range is 2–3%"), never an error. New jar defaults: salt 25 g, water 1000 ml (2.4 %), 20 °C, jar 1000 ml, Carrot, Sticks, Glass jar, Glass weight, Burping / self-venting lid, remind every 3 days.

## Days and status

- `daysBetween(start, end)`: whole calendar days, never negative, nothing when the start is missing or unreadable; the end is the given day or today.
- `fermentDays` (jar page, Insights, exports): start to the fridge day; else to the day the outcome was recorded; else to today.
- **Status**: Done when an outcome is recorded; else In fridge when the fridge day is set; else Fermenting. The list's pill and the jar page both use `fermentDays`, so they show the same day number.
- **Overall rating of a jar**: the explicit Overall, else the average of Taste, Sourness and Crunch that are set; nothing when none. A bake: the explicit Overall, else the average of Crust, Crumb and Flavour. Stars are the rating rounded to a whole number, 0–5, "★" filled and "☆" empty; no rating shows "—".

## Taste-test reminder

`nextCheckDue`: only for a Fermenting jar with `remindEveryDays` above 0: the day of the newest Taste line (or the start date when there is none) plus `remindEveryDays` days. Only Taste lines move it; Did lines never do. A jar is **due** when today is the due day or later. In the list, due jars come first inside Fermenting, the most overdue first, the rest newest start first.

Notification (`AlarmPlan`): one per due jar, id `taste.<jarid>.<due day>`, at the due day at the morning burp time (`burpMorning`, "08:00" unless changed), only when that moment is still in the future and this device's "Remind on this …" switch is on. Title "Taste test: <jar>", body "Day N — time to taste and write a line." (N = days from the start to the due day). A due day whose morning time has passed gets no notification (the jar still shows "Taste test due" in the app).

## Timeline

- `timelineEntries`: all Did lines (steps) and Taste lines (check-ins) in one list, oldest first by "date time"; a line without a time sorts as 99:99 (the end of its day); equal keys keep their entry order (Did before Taste).
- `parseStepLines` (adding a Did line): one step per line; leading bullets and dashes ("•", "·", "*", "-", "–", "—") and list numbers like "3." or "4)" up to 3 digits are removed; empty lines are dropped; "2% salt" and "2.5 kg" stay. All lines get the same date and time (the When box). A Taste line is one note: line breaks are turned into single spaces.
- Changing a line: day, time (or none) and words; words may not be empty; line breaks become spaces.
- `stepsText` (for Share and the spreadsheet's "What I did"): each Did line as "date time — words".

## Burp alarm

- **On** for a jar: it is Fermenting and its own choice (`burpAlarm`) says so; with no choice made, on only for the lid "Plain lid". So moving to the fridge, recording an outcome or deleting ends it.
- **Burped** (`Logic.burped`): adds a Did line "Burped the jar" with kind "burp", today's date and the time of the tap. A burp counts only when it has this kind (a Did line typed by hand does not).
- **Slots** (`burpSlots`): for the next 7 days from now, the morning and evening time of each day (today and the next 7), keeping only those after now and not later than now + 7 days; a slot is skipped when a burp was logged at or before it and not more than 3 hours before it. Seen at 09:00 a plain-lid jar has 14 slots: the evening of today, 6 whole days, and the morning of the 8th day.
- **Plan** (`AlarmPlan.plan`): for every live jar: its burp slots when this device rings (`burpAlarmHere`), plus its taste reminder when `tasteAlarmHere`; sorted by time (then id); cut to 60 (iOS keeps 64 waiting). Burp id `burp.<jarid>.<yyyyMMddHHmm>`; title "Burp: <jar>"; body "Morning burp · day N. Tap Burped when it is done." or "Evening burp · …" (morning = the slot whose clock time equals the morning setting; N = days from the start to the slot's day).
- **When it is re-planned** (`Alarms.reschedule`, after 0.5 s of quiet): at launch, each time the app becomes active, after any change to the data or to this device's settings, and after each action on a jar. It does nothing in UI tests, or in a test store. It removes waiting `burp.`/`taste.` requests that are no longer wanted, adds the missing ones, and removes delivered burp notifications older than the jar's last burp.
- **Permission**: `apply` asks the system by itself, once, the first time the plan is not empty while permission was never asked; also when a jar's switch is turned on, when "Ring on this …" is turned on while still not asked, and by the button "Allow notifications". Without permission nothing is planned.
- **The button**: "Burped" on the notification adds the burp (as above), saves at once to disk, and re-plans. A tap on the notification itself opens the jar (a waiting route is handed over when the window is ready).

## Look rules added in 6.0 build 2

- **Moving recipe steps** (`Logic.moveStep(steps, moving, onto)`): a step dropped on another step takes that step's place and the others shift by one; dropping a step on itself, or on a step that is not in the list, changes nothing. iPhone and iPad use the list's own move handle; the Mac drags the step by its own handle (a plain drag gesture) and tints the step it is held over in the Recipes colour.
- **Cancel and Save on the Mac**: Cancel is a pale pill, Save is a full-colour button in the colour of its part (jars orange, bakes gold-brown, recipes purple); Escape is Cancel.
- **Settings window on the Mac** (⌘,): follows Settings › Appearance (System / Light / Dark).
- **Edit bake / Log a bake**: section headings in the Bakes colour; "Delete this bake" red.
- **Rating trend axis** (Bake insights): whole numbers only, one per bake.

## Look rules added in 6.1 (build 3)

- **`Human.day(iso)`**: an ISO day "2026-11-25" is written "Wed 25 Nov"; the year is added ("Wed 25 Nov 2025") only when it is not this year. Text that is not an ISO day comes back unchanged. Used on read pages only; edit pages, exports and share text keep ISO days.
- **`Human.fromNow(iso)`**: today / tomorrow / in N days / yesterday / N days ago, counted in whole calendar days from today.
- **`Human.minutes(text)`**: reads a step's time words ("3 min", "2 h", "1 day", "10-15 min"): h / min / days are understood; a range counts as its middle ("10-15 min" = 12.5 min); no time words = nothing (the step has no length).
- **Long wait**: a step of 120 minutes or more is a long wait (pale piece in the recipe time ribbon); a shorter one is full colour. The ribbon shows only when at least one step has a time.
- **`Human.amount(line)`**: splits a leading amount from an ingredient line ("100 g active sourdough starter" gives "100 g" and "active sourdough starter"); a line with no leading amount keeps all its words and an empty amount column.
- **Success ring**: the share of finished jars that were a success (same number as Success rate).
- **Brine chart band**: 2-3 % is shaded (the same range as the brine hint).

## Insights

- `summarizeStats(batches, vegetable)`: vegetables seen; total jars; active (not Done); finished (Done); success rate = successful finished ÷ finished; rated = finished jars with an overall rating, oldest start first; average rating (one decimal); points for rating against brine %, room temperature and days fermented; rating over time (attempt number 1, 2, 3 …); averages by vegetable, form and lid (sorted high to low, one decimal; empty labels skipped); problem counts (most frequent first); best jar = the highest rating (the first one on a tie).
- `recommendation`: needs at least 2 Done jars with an overall rating of 4 or more; brine, temperature and days are the middle value (median) of those jars (one decimal; days rounded), lid and vegetable the most frequent (the first seen on a tie).
- Charts show only with at least 2 rated finished jars (bakes: 2 rated bakes).
- `summarizeBakes`: total, rated, average overall, averages by recipe and by category, problems, trend, best bake.

## Search

Words split on spaces; every word must appear (lower-case match, anywhere) in the record's text. Jar text: name, vegetable, form, vessel, lid, weight, notes, spices, taste notes, Did lines, plan step titles. Bake: name, category, recipe name, notes, problems. Recipe: title, category, description, storage, ingredients, equipment, each step's title and detail. No words, no results.

## Creating, copying

- **New jar**: today as start date. **Template → jar** (`batchFromPreset`): takes vegetable, form (when not empty), salt, water, temperature, jar size, spices, vessel, weight, lid (when not empty), remind days; the picker keeps the name, date, photos, notes, logged by of the page.
- **Jar → template** (`presetFromBatch`): the same fields.
- **Duplicate jar**: a template-style copy (fresh id, today, no lines, plan, photos, outcome, notes or burp choice), name + " (copy)" (empty stays empty); opens at once.
- **Duplicate recipe**: copy with new id and new step ids, title + " (copy)", times now. **Duplicate bake**: copy with new id, today's date, name + " (copy)", removed mark cleared.
- **Sourdough example recipe**: "Everyday Sourdough Loaf", 7 steps (Feed the starter … Bake).

## Steps → recipe (`Logic.recipe(fromStepsOf:)`)

Title = the jar's name (else its vegetable). Category "Vegetable ferment". Description "From the jar started <start date>.". Ingredients, in order: vegetable (with ", <form in lower case>" when there is a form), "<salt> g salt", "<water> ml water" (numbers without needless decimals), then the spices. Equipment: vessel, weight (not when "None"), lid, empty ones left out. Steps: every Did line that is not a burp, in Timeline order, each as a step whose title is the line's words (no detail, no time). The recipe is a draft in the form; nothing is saved before Save.

## Recipe → jar (`Logic.batch(from:)`)

A new jar named after the recipe. Vegetable: the first built-in vegetable (list order) whose name, or whose first word, is in the title in lower case; otherwise the default (Carrot). Spices: every built-in or own spice found in the ingredients text (case-insensitive, once each). Notes: "From recipe: <title>". `recipeID` and `recipeTitle` set. **Plan**: each recipe step becomes a To-do step: its title (when the title is empty, the detail becomes the title and the detail is empty; a step with neither is dropped), detail and time hint, all trimmed.

## To-do ticks

- **Tick** (`Logic.tick`): when the step is not yet done, `doneAt` = now and a Did line (kind "") with the step's title, today's date and the time is added; ticking a done step does nothing.
- **Untick**: clears `doneAt` and removes the first Did line with the same words, the same day and the same time and no kind; if that line was changed by hand it is not found and stays.
- **Progress**: "N of M done".

## Share and export text

- Jar share text: see `02-screens.md`.
- **Spreadsheet** (`Xlsx.swift`, a real zip): tabs Ferments (Name, Vegetable, Form, Start date, Days fermented, Brine %, Salt (g), Water (ml), Room temp (°C), Vessel, Weight, Lid, Spices, Status, Success, Taste, Sourness, Crunch, Overall, Problems, Notes, Logged by, What I did), Bakes, Recipes, Lessons; removed records left out.
- **CSV**: "# Ferments (batches)", "# Bakes", "# Recipes", "# Lessons learned & improvements", each with a header line (or "(none yet)"); text with commas, quotes or line breaks is quoted.

## Your lists (`SettingsListEdit`)

Names listed = his remembered names plus those used by jars, not built in, sorted. Rename: in his list, in every live jar and in every template (a spice also keeps its place without duplicates). Remove: a vegetable or cut only when no jar uses it; a spice always, and it is taken off every jar and template that has it. Counts "used in N jar(s) and N template(s)".

## Backups and imports (`ImportApply`)

- **Counts line**: "7 jars, 2 bakes, 3 recipes, 4 lessons, 1 template, 12 pictures" — only kinds with at least one.
- **Web import**: write "Before import", add the pictures, then `WebImport.merge`. **Own backup restore**: `parseBackup` accepts only a JSON object that has `format` and `batches`; a web backup (`app` = "fermentlog") is refused with "This backup comes from the old web app. Use “Bring your jars over from the web app” for it."; a higher format with "A newer FermentLog made this backup. Update this device first."; anything else "This is not a FermentLog backup."; then "Before restore" and `AppData.merged` (joined, not replaced).
- **Logged by**: a new jar starts with the person who is logging, as bakes and lessons do.
- **People**: the first name added becomes the person who is logging; removing the one who is logging makes the first of the rest the one.
