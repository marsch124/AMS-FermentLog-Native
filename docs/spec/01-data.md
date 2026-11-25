# 01 — Data

Source: `Model.swift` (types), `Store.swift` (the only thing that touches disk), `WebImport.swift`, `ImportApply.swift`, `Photos.swift`, `Keychain.swift`.

## The file and the folders

Container `iCloud.com.schabbauer.AMSFermentLog`, folder `Documents` (shown in Files as "FermentLog"):

```
fermentlog.json     the whole database: pretty-printed JSON, keys sorted, dates ISO 8601
Photos/             every picture as <uuid>.jpg (lower-case uuid), at most 1600 px on the long side, JPEG quality 0.8
Safety copies/      Daily yyyy-MM-dd.json (newest 30 kept) · Copy <stamp>.json · Before import <stamp>.json
                    · Before restore <stamp>.json · Could not read <stamp>.json
Safety copies/Photos/   a mirror of Photos/, never pruned
```

`<stamp>` is "2026-11-09T13.07.08" (colons replaced by dots). Without iCloud Drive: `~/Library/Application Support/AMSFermentLog` with the same layout. UI tests: a fresh temporary folder `AMSFermentLog-UITest-<uuid>`. `Store.inCloud` is true when the file's path contains "Mobile Documents".

## Stored types (all in `fermentlog.json`)

Every type decodes tolerantly: a missing key takes its default, an unknown key is ignored, so a newer file never fails to read on an older app and the other way round. Day-only dates are text "yyyy-MM-dd" and clock times are text "HH:mm", exactly as the web app wrote them.

### AppData (the file)

`batches` [Batch], `presets` [Preset], `recipes` [Recipe], `bakes` [Bake], `lessons` [Lesson], `settings` AppSettings, `savedAt` Date, `format` Int (6.0 = 1).

### Batch (a jar)

`id` ("b_<ms>_<6 hex>" for new ones; web ids kept on import), `name`, `vegetable` (default "Carrot"), `form` ("Sticks"), `startDate` day, `saltGrams` (25), `waterMl` (1000), `roomTempC` (20), `jarSizeMl` (1000) — all four optional numbers, `additions` [String] (the spices), `vesselType` ("Glass jar"), `weightType` ("Glass weight"), `lidType` ("Burping / self-venting lid"), `remindEveryDays` (3; 0 = taste reminder off), `checkIns` [CheckIn], `steps` [Step], `plan` [PlanStep], `recipeID`, `recipeTitle`, `movedToFridgeDate` day or "", `outcome` Outcome?, `photos` [file names], `notes`, `loggedBy`, `burpAlarm` Bool? (nil = follow the lid; true/false = the owner's own choice for this jar), `createdAt`, `modifiedAt`, `deletedAt`. Computed: `title` = name, else vegetable.

- **Step** (a "Did" line): `id` (uuid), `date`, `time` ("" = no time), `text`, `kind` ("burp" when written by the Burped button or the notification button; "" otherwise).
- **CheckIn** (a "Taste" line): `id`, `date`, `time`, `tasteNote`.
- **PlanStep** (a To-do step from a recipe): `id`, `title`, `detail`, `time` (the recipe's hint, e.g. "3 min"), `doneAt` Date? (nil = still to do).
- **Outcome**: `recorded`, `success`, `taste`, `sourness`, `crunch`, `overall` (Int? 1–5), `problems` [String], `recordedAt`.

### Preset (a jar template)

`id` ("p_…"), `name`, `vegetable`, `form`, `saltGrams`, `waterMl`, `roomTempC`, `jarSizeMl`, `additions`, `vesselType`, `weightType`, `lidType`, `remindEveryDays`, `modifiedAt`, `deletedAt`. A template does not hold the burp-alarm choice, name, date, photos or notes.

### Recipe

`id` ("r_…"), `title`, `category` (default "Sourdough"; "Other" when missing in a file), `description`, `photos`, `ingredients` [String], `equipment` [String], `activeTime`, `totalTime`, `steps` [RecipeStep], `storage`, `createdAt`, `modifiedAt`, `deletedAt`. **RecipeStep**: `id`, `title`, `detail`, `time`.

### Bake

`id` ("k_…"), `name`, `category` ("Sourdough"), `bakeDate` day, `recipeID`, `recipeTitle`, `photos`, `ratings` {`crust`, `crumb`, `flavour`, `overall`: Int?}, `problems`, `notes`, `loggedBy`, `createdAt`, `modifiedAt`, `deletedAt`.

### Lesson

`id` ("l_…"), `text`, `loggedBy`, `recipeID`, `recipeTitle`, `linkType` ("bake", "batch" or ""), `linkID`, `linkLabel`, `createdAt`, `modifiedAt`, `deletedAt`. Names are copied in so a lesson still reads well if the recipe or bake is removed later.

### AppSettings (one record, shared by all devices)

`people` [String], `activePerson`, `customVegetables`, `customForms`, `customSpices` (his own, remembered beside the built-in ones), `burpMorning` ("08:00"), `burpEvening` ("20:00"), `backupCadenceDays` (30) and `lastBackupAt` (both kept in the file for compatibility, no longer used by any screen; `lastBackupAt` is still stamped when a file is exported), `modifiedAt`.

## Merge rule

`mergeRecords(a, b)`: records are matched by `id`; a record only one side has is kept; if both have it, the one with the strictly newer `modifiedAt` wins (a tie keeps the one from `a`). `AppData.merged(a, b)` applies this to batches, presets, recipes, bakes and lessons; settings are one record: the side with the newer `settings.modifiedAt` wins whole (fields are not joined); `savedAt` = the later; `format` = the higher.

Every `Store` change goes through `upsert` (sets `modifiedAt` = now) or `tombstone`. `scheduleSave()` waits 400 ms (so typing does not write on every letter), then `saveNow()`.

## Reading and writing

- **load()**: asks iCloud to download the newest file, reads it under file coordination, then MERGES it into what is in memory (never a plain replace, so unsaved changes survive), merges iCloud "conflict copies", sets `syncPlace`, purges old tombstones, refreshes the list of safety copies and the cloud state. A file watcher (file presenter and, in iCloud, a metadata query) calls `load()` when another device writes; it asks for the download again 2 seconds later.
- **saveNow(merge: true)**: under file coordination reads what is on disk, merges (`merged(onDisk, mine)`), and writes atomically. If the bytes on disk cannot be read as this app's data and are not empty, they are first parked as `Safety copies/Could not read <stamp>.json` — a file this app cannot read is never overwritten blind. If the merged `format` is higher than `currentFormat` nothing is written (see below). A failed write sets `saveProblem` (shown as a red line in Settings › iCloud and, the first time, a bar "Could not save. Your changes are not stored yet."). After a write: the daily copy.
- **syncNow()** (Settings › Sync now, and every return to the foreground): asks iCloud for the newest version, waits up to 10 seconds (20 × 0.5 s) for it, loads (merge), saves (so the others get this device's changes), sets `lastSynced`.
- **Conflict copies**: when iCloud sets one write aside (two devices at once), each unresolved version is decoded, merged in, marked resolved, and the other versions removed; the number is shown in Settings ("N clash(es) between devices joined together since this app opened. Nothing was lost.").
- **cloudState**: "Up to date", "Downloading…", "Uploading…", "Waiting to upload", "A newer version is waiting in iCloud", "Upload failed: …", "Download failed: …", "No shared file yet", or "Not in iCloud — turn on iCloud Drive for this app on every device".

## Removed things (tombstones)

Removing a record sets `deletedAt` and `modifiedAt` = now and keeps the record; screens use only the `live…` lists. The tombstone merges like any change, so the removal reaches the other devices. Undo (the bar after a removal) clears `deletedAt`. At every `load()`, records whose `deletedAt` is older than 30 days are dropped for good, and picture files no longer used by any record are deleted from `Photos/` (not from `Safety copies/Photos/`). `Store.photoFiles(in:)` lists the files the data still points at (jars, recipes, bakes).

## The format number

`AppData.currentFormat` = 1 ("the first native format"). Rule: raise it by one in every version that adds a stored field to anything in `AppData`. A device with `data.format > currentFormat` (`Store.needsUpdate`) shows the red bar "Update this device first" and the same words in Settings › iCloud, never writes the file, writes no safety copies (`writeCopy` returns false), and has Restore, Import, "Make a safety copy now", the people list and "Your lists" switched off. A web backup is not subject to this; an own backup file with a higher format is refused with "A newer FermentLog made this backup. Update this device first."

## Safety copies

- **Daily**: after every successful save, if `Daily yyyy-MM-dd.json` for today does not exist, it is written. Only files starting "Daily " are pruned: the newest 30 by name are kept.
- **Named copies**: "Before import" (before a web import), "Before restore" (before a restore from a copy or from a backup file), "Copy" (Make a safety copy now), "Could not read" (parked unreadable bytes): kept for good.
- **Proof**: a copy counts only if reading it back decodes and has the same number of jars, recipes, bakes and lessons (removed ones included) as the data; otherwise the file is deleted and the copy reports failure.
- **Pictures**: after every copy, every picture file not yet in `Safety copies/Photos/` is copied there (in the background); never pruned.
- **Restore** (`restore(from:)`): needs a readable copy and not `needsUpdate`; writes "Before restore"; data = the copy (no merge, `saveNow(merge: false)`); pictures missing from `Photos/` are copied back from `Safety copies/Photos/`.
- The list (Settings › iCloud › Safety copies) shows each copy's title (without the stamp), its date and time and "N jars · N bakes · N recipes" (read once in the background; "Reading…" meanwhile; "Not readable on this device yet" when it cannot be read).

## Pictures

`Store.addPhoto(jpeg)` shrinks to at most 1600 pixels on the long side (turned the right way up, JPEG 0.8) and writes `<uuid lower-case>.jpg`; the record stores only the file name. `photoURL` asks iCloud to download a picture another device added when it is not here yet. Removing a picture in a form only takes its name off the record (`Remove` under the picture); the file stays in `Photos/` (nothing deletes it later; only the pictures of a record purged after 30 days are deleted) and the safety copies' mirror keeps it. (`Store.removePhoto` exists but no screen calls it.)

## What is not in the file

- **Per device** (`UserDefaults`, key `deviceSettings`, JSON): `appearance` (system, light, dark), `burpAlarmHere`, `tasteAlarmHere` (default true on iPhone, false on iPad and Mac), `timelineKind` (did, taste). Also `@AppStorage` `homeView` ("jars"/"bakes") and `insightsView` ("ferments"/"bakes").
- **AI key**: the device's keychain, service `com.schabbauer.AMSFermentLog.ai`, account `key`, generic password, available after first unlock, this device only, never synchronised, never in the file, a backup or a copy.
- **Notifications**: planned from the data by `AlarmPlan`, held by the system; nothing stored by the app.

## Web import mapping (`WebImport.swift`)

Reads the web app's backup `{ app: "fermentlog", version, exportedAt, batches, presets, recipes, bakes, bakeLessons }` (the oldest backups were a bare list of jars and are accepted). A file without `app: "fermentlog"` is refused ("This file is not a FermentLog backup."; unreadable: "This file could not be read.").

- Numbers are read tolerantly (numbers or text; a comma decimal is accepted; empty = none). Day fields keep the first 10 characters.
- Jar: web `id` kept; `checkIns` and `steps` get id `<jarid>-c<i>` / `<jarid>-s<i>` when they have none; `remindEveryDays` default 3; `outcome` mapped field by field; `createdAt` and `modifiedAt` = the web `createdAt` (or "unknown" = distantPast + 1 second), so anything already edited natively wins a merge. New native fields (`plan`, `recipeID`…, `burpAlarm`) are empty.
- Template (web "preset") → Preset; recipe → Recipe (`category` "Other" when empty); bake → Bake (`recipeId` → `recipeID`); `bakeLessons` → lessons (`recipeId`, `linkKind` → `linkType`, `linkId` → `linkID`).
- Pictures: each web data URL (`data:…;base64,…`) is decoded to a file named from a UUID made from the bytes (two FNV-1a runs), so the same picture always has the same name and a second import adds no files; an existing file is never overwritten.
- Settings the web kept in the browser are rebuilt: `customVegetables` = vegetables of the jars and templates that are not built in; `customSpices` likewise; `customForms` = forms not built in; `people` = every `loggedBy` of jars, bakes and lessons. They are merged into the current settings as a union (`WebImport.merge`), never replacing.
- Importing the same file twice changes nothing (stable ids, stable picture names).
