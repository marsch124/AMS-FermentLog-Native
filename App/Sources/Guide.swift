import Foundation

/// The single source for the version the app shows, "What's new" and "How it works".
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
            // The big change
            "New: FermentLog is now a real app for iPhone, iPad and Mac. Before (web app 5.25): a web page you put on the iPhone’s Home Screen, one copy per browser. Now: one app from TestFlight on each device, with its own icon, its own notifications and, on the Mac, its menus and keys (⌘N new jar, ⌥⌘N new bake, ⇧⌘N new recipe, ⌘F search, ⌘, Settings).",
            "Note: “Bring your jars over from the web app” needs the web app at version 5.26 or newer on the iPhone. Older copies could not save a backup file from the Home Screen, so open the web app, let it update, and then make the backup.",
            "New: iCloud keeps your iPhone, iPad and Mac on the same jars. Before: every device (and every browser) had its own jars, and moving them meant a backup file. Now: one file in iCloud Drive, in the folder FermentLog, holds all your jars, bakes, recipes, lessons, templates, people and lists, with the pictures beside it. A change on one device shows up on the others by itself. Settings › iCloud shows the state, the time of the last sync and a Sync now button.",
            "New: when two devices change things at the same time, nothing is lost. Each jar, bake, recipe and lesson is joined one by one and the newest change to each one wins. Things you delete stay hidden for 30 days, then leave for good. Before: there was only one copy, so this could not happen.",
            "New: “Update this device first”. If one device has a newer FermentLog that stores more details, a device still on the older one shows a red bar with these words. It saves nothing, makes no safety copies and cannot import or restore, so it can never save your file without the new details. Update it in TestFlight and the bar goes away. Nothing is lost meanwhile.",
            // Burp
            "New: the “Burped” button. A fermenting jar’s page has a block “Burp” with a full-colour Burped button. One tap writes “Burped the jar” and the time into the Timeline and shows “Last burp: today 08:12 · 2 today” beside the button, with a bar at the bottom and Undo for 4 seconds. Before: you typed “burped the jar” as a step by hand.",
            "New: the burp alarm. FermentLog rings twice a day, at 08:00 in the morning and 20:00 in the evening (change both in Settings › Burp alarm), for every fermenting jar whose alarm is on: “Burp: Cabbage jar — Morning burp · day 3. Tap Burped when it is done.” The notification has its own Burped button that writes the burp into the Timeline without opening the app; tapping the notification itself opens the jar. Before: nothing rang.",
            "New: the alarm is on by itself for jars with a plain lid and off for the other three lids (airlock, burping / self-venting, cloth / open). Each jar has its own “Burp alarm” switch, on its page and in its form, with a line under it that says why (“On by itself for a plain lid”, “Off: this lid lets the gas out by itself”, “On for this jar”, “Off for this jar”). Each device has its own switch too, “Ring on this iPhone / iPad / Mac” in Settings › Burp alarm: on from the start on the iPhone, off on the iPad and the Mac.",
            "New: the alarm stops by itself. It rings only for jars that are still fermenting: moving a jar to the fridge, recording its outcome or deleting it ends it at once. A ring is skipped when you logged a burp with the Burped button in the 3 hours before it, and a notification still on your screen goes away when you burp the jar. It plans 7 days ahead (up to 14 rings per jar, 60 in all) and renews the plan every time you open the app.",
            "New: the jar list shows a small grey tag “Burp alarm on” on every jar the alarm rings for.",
            "New: FermentLog asks for permission to notify by itself, once, the first time something should ring on this device (for example a plain-lid jar that is fermenting, on the iPhone). Say Allow and the alarm works. Settings › Burp alarm shows the state: a green tick and “Notifications are allowed”, or, if you said no, a red line with an Open Settings button; the button “Allow notifications” is there too.",
            // Taste reminder
            "Changed: the taste-test reminder is now a real notification. Before (5.25): it showed only while you had the web app open, as an orange bar and a clock mark. Now: on the day a taste test is due the device rings at the morning time (08:00 unless you changed it): “Taste test: Cabbage jar — Day 3 — time to taste and write a line.” Settings › Taste-test reminder has a switch for each device (on from the start on the iPhone, off on iPad and Mac). The list still shows the tinted box “2 jars are due for a taste test”, the clock mark is now the small tag “Taste test due”, and the jar’s page says “Taste test due 2026-11-28”.",
            "Unchanged on purpose: the days are counted from your last Taste line (or the start date), and only a Taste line moves the next reminder; a Did line such as “Burped the jar” does not. Each jar has its own number of days (0 to 60, 3 to begin with, 0 = off), set in the jar form.",
            // Recipes
            "New: a To-do list on a jar started from a recipe. “Start a jar from this recipe” now gives the jar a block “To do — from <recipe>” with the recipe’s steps as round boxes and “2 of 7 done” above them. Tick a step and it turns green, shows “done 14:05”, and a Did line with the step’s words and the time is written into the Timeline. Tick it again to take the tick and that line back. Before: the steps were not carried over as a list.",
            "New: “Save steps as a recipe” on a jar’s page. It opens a new recipe already filled in: title = the jar’s name, category Vegetable ferment, ingredients (vegetable and cut, grams of salt, ml of water, spices), equipment (vessel, weight, lid) and one step for each Did line in time order (burps are left out). Nothing is saved until you press Save. The button shows only when the jar has at least one Did line besides burps.",
            "Changed: the recipe buttons. Before: “Start a batch from this” and “Log a bake from this”. Now: “Start a jar from this recipe” (on every recipe except Sourdough ones) and “Log a bake from this recipe” (on every recipe except Vegetable ferment ones; the full-colour button on a Sourdough recipe). The word “batch” is gone from the screens; it is “jar” everywhere.",
            // Jar page and form
            "Changed: the Timeline on a jar. Before: a ✕ at the end of each line. Now: tap a line to change its day, time or words in “Change this line” (Cancel and Save), or press “Delete this line”, which asks “Delete this line?” with “Keep it”. Adding is as before: the switch “What I did” / “Taste test”, a day-and-time box, one step per line (paste a whole list and the list numbers go away) and a full-colour Add button.",
            "Changed: words instead of crosses. Before: ✕ took things away (a line, a photo, a recipe step, a lesson, a person). Now: the word “Remove” or “Delete” in red, and after a jar, recipe, bake, lesson or template is removed a bar at the bottom offers Undo for 4 seconds. A jar removed by mistake can still be brought back from a safety copy for 30 days.",
            "Changed: no more emoji. Before: the web app used emoji for the fridge, the AI helper, search, backup and more. Now: small hand-drawn marks (jar, recipe book, plus, chart, gear, bread, search) and words on the buttons: “Move to the fridge”, “Build jar with AI”, “Search”.",
            "Changed: each part has its own colour. Before: orange almost everywhere. Now: Jars orange, Bakes gold-brown, Recipes purple, Insights teal, Search slate blue, Settings grey-blue, each with its own headings, marks and main button. A main button is always full colour, never grey. Day and night colours are set for each.",
            "Changed: Share does the job of Print. Before: Print on a jar and on a recipe. Now: Share sends the same plain-words summary (a jar: name, status, brine, temperature, equipment, dates, result, notes and the whole Timeline) through the system’s share sheet, which also offers a printer. There is no Print button any more.",
            "Changed: Move to the fridge. Before: “🧊 Move to fridge”. Now: “Move to the fridge”, one tap on a fermenting jar’s page. It stops the burp alarm and the taste-test reminder.",
            "Changed: the jar list. Before: one list with an orange banner and a clock mark when a taste test was due. Now: the numbers “2 fermenting · 1 in the fridge · 1 done”, then three groups (Fermenting, In the fridge, Done), each with its count. Fermenting jars that are due for a taste test come first, the most overdue first. Each row has the picture or a jar mark, the name, the status pill with the day number, the brine, the stars and the tags.",
            // Safety, backups
            "Changed: a safety copy every day. Before (5.25): a note “Time for a backup” appeared on Home when your chosen interval (weekly, every 2 weeks, monthly, every 3 months or off; monthly to begin with) had passed. Now: the first time anything is saved each day, FermentLog writes “Daily <date>” into the Safety copies folder next to your file, checks it by reading it back, and keeps the newest 30. The pictures are copied beside them and never removed. Settings › iCloud › Safety copies lists them newest first with “4 jars · 2 bakes · 2 recipes”, and “Restore this copy” brings one back (a copy of how things are now is kept first, called “Before restore”). “Make a safety copy now” makes one that is kept for good.",
            "Removed: the backup reminder and its interval setting. It is no longer needed, because the daily copies and iCloud do that work.",
            "Unchanged: Export is still in Settings. Spreadsheet (.xlsx, four tabs: Ferments, Bakes, Recipes, Lessons), CSV (one file, four labelled parts) and Backup file (a .json file with all jars, bakes, recipes, templates, lessons and settings, but not the pictures). New: “Restore from a backup file” in the same place asks first, makes a safety copy and joins the file with what is here. Before: “Export backup (JSON)”, “Import backup” and “Export spreadsheet (Excel)”.",
            "New: “Bring your jars over from the web app” in Settings, in three steps: open the old FermentLog on the iPhone, Settings › Backup & export › Export backup (JSON), save the file to Files, then here choose that file. The app shows what is inside (“7 jars, 2 bakes, 3 recipes …”), makes a safety copy “Before import”, adds everything and deletes nothing. Doing it twice with the same file adds nothing twice. The pictures come across, and so do your people and your own vegetables, cuts and spices, which the old backup did not hold, so FermentLog works them out from your entries.",
            // AI
            "Changed: the AI key. Before: kept in the browser of that one device. Now: kept in the keychain of this device only. It does not travel through iCloud and is in no backup or copy, so enter it once on each device in Settings › AI assistant. Everything else about the AI is as before: your own key, only the words you write are sent, and you check the result before anything is saved.",
            // What differs
            "Changed: the lessons notebook shows the day a lesson was written. Before: the day and the time. The form keeps text, who logged it, the recipe and the list “From a jar or bake”.",
            "Changed: Settings. Before: People, Backup & export, Backup reminder, AI assistant, Appearance, Manage vegetables & spices, What’s new and install help. Now: Who is logging, Burp alarm, Taste-test reminder, Appearance (System, Light or Dark, for this device), iCloud, Bring your jars over from the web app, Export, AI assistant (optional) and, at the end, Your lists, How it works, What’s new and the version number (6.0 (1)).",
            "Removed: what only a web page needed: “Add to Home Screen”, “fully close and reopen after an update”, and the banner and dot that pointed to What’s new. Updates now come through TestFlight.",
            "New: How it works is written for the whole app, with a part “Signs in this app” for the native marks and colours (the tick boxes of the To-do list, the Undo bar, the drag handle and the rest).",
            "Unchanged on purpose: the brine sum (salt ÷ (salt + water) × 100; 2 to 3 % is the sweet spot, only a hint), the status rules (Fermenting, In fridge, Done), ratings and Insights (best jar, a recommended recipe from two jars rated 4 or more), Search, bakes, recipes, the sourdough example, who is logging, the spreadsheet columns. Dates and times now follow the device you hold (the web app used universal time in a few places).",
            "Updated: the written specification (docs/spec) and this guide.",
        ]),
    ]

    struct Section: Identifiable {
        let title: String
        let text: String
        var id: String { title }
    }

    static let howItWorks: [Section] = [
        Section(title: "The basics", text: """
FermentLog is your private logbook for fermenting jars, baking and recipes. It is an app for iPhone, iPad and Mac, and all three show the same jars (see “iPhone, iPad and Mac together”). It works without internet; iCloud only passes your data between your own devices.
On the iPhone there are five tabs along the bottom:
• Home — your jars. A switch at the top, Jars | Bakes, shows your bakes instead. The Search button is at the top right.
• Recipes — your recipe book.
• New — three big buttons: New jar, New bake, New recipe.
• Insights — what makes your best jars and bakes.
• Settings — alarms, iCloud, safety copies, export, the AI assistant and this guide.
On the iPad and the Mac the same things stand in a list at the side: Jars, Bakes, Recipes, Insights, Search, Settings. A New button at the top right of the page offers New jar, New bake and New recipe. On the Mac these keys work: ⌘N new jar, ⌥⌘N new bake, ⇧⌘N new recipe, ⌘F search, ⌘, Settings; the Help menu opens this guide and What’s new.
Every page where you change something has Cancel and Save; on the Mac, Escape is Cancel. The main button of a page is always in full colour. Each part of the app has its own colour: Jars orange, Bakes gold-brown, Recipes purple, Insights teal, Search slate blue, Settings grey-blue.
Settings › Appearance picks System, Light or Dark for this device only. The version number is at the bottom of Settings.
"""),

        Section(title: "Your jars", text: """
The Jars list (Home on the iPhone, Jars at the side on iPad and Mac) starts with three numbers in their own colours: how many jars are fermenting, in the fridge and done. Under them is the full-colour button Start a jar. On the iPad and the Mac there is also New jar at the top right.
If any jar is due for a taste test, a tinted box says “2 jars are due for a taste test” and names them.
Jars are in three groups, each with its count:
• Fermenting — on the counter. Jars due for a taste test come first, the most overdue first; the others follow, newest first.
• In the fridge — newest first.
• Done — a verdict has been recorded; newest first.
Each row shows the jar’s picture (or a jar mark), its name (the vegetable when it has no name), a status pill with the day number (“Fermenting · day 3”), the brine percentage and, once rated, its stars. Two small tags can follow: “Taste test due” and “Burp alarm on”. Tap a row to open the jar.
With no jars yet you see a big jar mark, “No jars yet” and Start a jar.
"""),

        Section(title: "Starting a jar", text: """
Tap Start a jar (or New jar). The vegetable is the only thing you must have; Save stays off until there is one. Carrot and Sticks are chosen to begin with, so change them. The page has these parts, in order:
• Start — only when you have saved templates or an AI key. “Start from a template” fills in the conditions, spices and equipment of a template; your name, date, photos and notes stay. With an AI key you can also describe the jar in your own words and press Build jar with AI; look it over, then Save.
• Basics — Name (for example Spicy carrot #1), Vegetable and Form (each a list that ends in “Add your own…”; Form can be None), Start date (today to begin with) and Logged by (only when you added people in Settings; a new jar starts with whoever is logging).
• Brine and conditions — Salt (g) 25 and Water (ml) 1000 to begin with, Room temperature (°C) 20, Jar size (ml) 1000. A line under the salt and water works out the brine for you: salt ÷ (salt + water). From 2 % to 3 % it reads “Brine 2.4 % ✓ in the 2–3 % sweet spot” in green; outside that it says “typical range is 2–3 %”, which is only a hint, not an error.
• Spices — tap the ones you use: Garlic, Dill, Mustard seed, Black pepper, Bay leaf, Ginger, Chilli, and your own. “Add your own spice” and Add put a new one in the list for next time.
• Equipment — Vessel (type your own words), Weight (Glass weight, Ceramic weight, Cabbage leaf, Smaller jar, None) and Lid (Airlock, Burping / self-venting lid, Plain lid, Cloth / open).
• Reminders — “Remind me to taste every 3 days” (0 to 60; 0 turns the taste-test reminder off for this jar). Under it the switch Burp alarm. It follows the lid until you touch it: the small line under it says “On by itself for a plain lid” or “Off: this lid lets the gas out by itself”. Once you flip it yourself it stays as you set it (“On for this jar” or “Off for this jar”), even if you change the lid later.
• Photos and notes — Add pictures, Take a picture (iPhone and iPad) and a notes box. Pictures are shrunk to 1600 pixels on the long side.
At the bottom: Save as a template asks for a name (for example “Classic 2.5% carrots”) and keeps the vegetable, cut, salt, water, temperature, jar size, spices, vessel, weight, lid and taste-test days, so the next jar can start from it. When you change an existing jar, Delete this jar asks first and then shows Undo for 4 seconds.
After Save, a new jar opens on its own page.
"""),

        Section(title: "A jar’s page", text: """
At the top right: Edit. Then, from the top:
• A status pill (“Fermenting · day 3”, “In fridge · day 12”, “Done · day 12”) and, while a taste test is coming, “Taste test due 2026-11-28” (deep orange once the day has come, grey before).
• Pictures, then the facts: Vegetable, Form, Brine (green when it is 2–3 %), Room temp, Started, Lid, Weight, who logged it, your spices as small tags, and your notes.
• Burp (only while the jar is fermenting) — the full-colour Burped button; beside it “Not burped yet” or “Last burp: today 08:12 · 2 today”; the switch Burp alarm; and a line “Rings at 08:00 and 20:00” (with “— switched off for this device in Settings” when this device does not ring). One tap on Burped writes the burp into the Timeline; a bar at the bottom says “Burp logged 08:12” with Undo for 4 seconds.
• To do — from <recipe> (only when the jar was started from a recipe) — the recipe’s steps as round boxes, with “2 of 7 done” above them. Tap a box: it turns green with a tick, the step shows “done 14:05”, and a Did line with the step’s words and that time is written into the Timeline. Tap it again to take both back (if you have changed that Timeline line’s words or time in between, the line stays).
• Timeline — everything about the jar, oldest first, each line with its day and time. A line has a tag: Did (orange) for something you did, such as chopping the cabbage or burping the jar, or Taste (green) for a taste test. Tap a line to change its day, its time (“Has a time” can be switched off) or its words, then Save or Cancel; “Delete this line” asks first. To add a line, pick What I did or Taste test, set When (now to begin with; change it if it was earlier), write, and press the full-colour Add. In What I did every line you type or paste becomes its own step, and list numbers (“1.”, “2)”) and bullets are taken off; “2% salt” stays. In Taste test the whole text is one note, and it moves the next taste-test reminder. With an AI key, Taste test also offers “Add by voice”: write or dictate “day 4, tangy and still crunchy” and it makes the line.
• Move to the fridge (fermenting jars only) — one tap. Today is written as the fridge day, the status becomes In fridge and the alarms stop. There is no way back from the jar’s page, so tap it when you mean it.
• Outcome — “No verdict recorded yet” and Record outcome; or the verdict in a green box “Success” or a red box “Didn’t work out”, with Taste, Sourness, Crunch and Overall as stars and the problems as red tags (Mould, Kahm yeast, Mushy / soft, Too salty, Not sour enough, Off smell). Edit outcome changes it. Recording an outcome makes the jar Done.
• Duplicate (same set-up, a fresh jar called “… (copy)” with no lines, pictures or verdict; it opens at once), Share (a plain-words summary through the system’s share sheet) and Save steps as a recipe (it opens a new recipe filled in from the jar: ingredients, equipment and one step for each Did line, burps left out; nothing is saved until you press Save; the button shows only when there is a Did line besides burps). With an AI key there is also AI tips, with Add to notes or Dismiss.
"""),

        Section(title: "The burp alarm", text: """
Gas builds up in a closed jar, so some jars need a burp every day. The alarm reminds you twice a day.
• What rings: at 08:00 and 20:00 (change both in Settings › Burp alarm), for every jar that is fermenting and has its alarm on, you get “Burp: Cabbage jar — Morning burp · day 3. Tap Burped when it is done.”
• The Burped button is on the notification itself: press and hold it (or pull it down) and tap Burped. “Burped the jar” and the time are written into the jar’s Timeline without opening the app. Tapping the notification itself opens the jar.
• Which jars: a jar with a plain lid rings by itself. The other lids (airlock, burping / self-venting, cloth / open) do not, because the gas leaves on its own. Every jar has its own switch Burp alarm, on its page and in its form, to choose differently. The jar list marks the jars that ring with the grey tag “Burp alarm on”.
• Which devices: Settings › Burp alarm › “Ring on this iPhone” (or iPad, or Mac). It is on from the start on the iPhone and off on iPad and Mac, because the iPhone is the one in your pocket. It is a choice for each device. The two times are the same on every device.
• When it stays quiet: if you logged a burp with the Burped button (on the page or on a notification) in the 3 hours before a ring, that ring is skipped; a Did line you type yourself does not count. A notification still on your screen goes away when you burp the jar afterwards. The alarm stops for good when the jar goes to the fridge, gets its outcome or is deleted.
• It plans 7 days ahead and renews its plan each time you open the app or change a jar, so open FermentLog at least once a week.
• Allowing notifications: the first time something should ring on a device, FermentLog asks by itself; say Allow. Settings › Burp alarm shows the state: a green tick and “Notifications are allowed”; or, if you said no, a red line and Open Settings, which takes you to the system’s settings; and “Allow notifications” if it was never asked. On the iPad and the Mac, switch “Ring on this …” on too.
"""),

        Section(title: "Taste-test reminder", text: """
Each jar has its own number of days between taste tests, set in the jar form (3 to begin with; 0 turns it off for that jar).
• The days are counted from your last Taste line, or from the start date when there is none. A Did line (even “Burped the jar”) does not move it; writing a Taste line does.
• On the day it is due, the device rings at the same time as the morning burp (08:00 unless you changed it): “Taste test: Cabbage jar — Day 3 — time to taste and write a line.” If that time has already passed when FermentLog makes its plan (for example a jar that is days overdue), there is no notification, but the jar still shows “Taste test due” in the list, in the tinted box above the groups and on its page.
• Only jars that are fermenting get a reminder; one in the fridge or done does not.
• Settings › Taste-test reminder › “Remind on this iPhone” (or iPad, or Mac) switches it for the device: on from the start on the iPhone, off on iPad and Mac. It uses the same permission as the burp alarm (see above).
"""),

        Section(title: "Recipes", text: """
The Recipes tab (Recipes at the side on iPad and Mac) is a recipe book for fermenting and baking, the newest changed first. A row shows the picture (or a book mark), the title, a purple category pill, “Hands-on …”, “Total …” and the number of steps. With no recipes yet you get New recipe and “Add the sourdough example”.
A recipe holds: Title, Category (Sourdough, Vegetable ferment, Drink / kombucha, Dairy, Other), Description, Pictures, Ingredients and Equipment (one per line), Hands-on time, Total time, the Method (each step has a title, a time hint such as “3 min” and what to do; drag a step by its handle to move it; Remove takes one away; Add a step adds one) and Storage and keeping. “Delete this recipe” asks first and then offers Undo for 4 seconds.
On a recipe’s page:
• Start a jar from this recipe — on every recipe except Sourdough. It opens the New jar page already filled in: the name is the recipe’s title, the vegetable is found from the title when it names one (otherwise Carrot stays), spices are ticked when the ingredients mention them, the notes say “From recipe: …”, and the recipe’s steps become the jar’s To do list. Nothing is saved until you press Save. Each tick on the To do list is written into the Timeline with the time.
• Log a bake from this recipe — on every recipe except Vegetable ferment. It opens a new bake linked to the recipe.
• Duplicate, Share and, with an AI key, Improve with AI (it opens the form with the changes for you to check).
• Lessons learned about this recipe are listed at the end.
Save steps as a recipe, on a jar’s page, makes a recipe the other way round.
"""),

        Section(title: "Bakes and lessons", text: """
Bakes are for sourdough and other baking. On the iPhone choose Bakes in the switch at the top of Home; on the iPad and Mac it is Bakes at the side. The full-colour button is Log a bake. A bake’s row shows a picture or a bread mark, its name, a gold-brown category pill, the date, its recipe, its stars (or “Not rated yet”) and its problems as red tags.
• A bake has: Name, Category (Sourdough, Bread, Other), Date, Recipe (None or one of yours), Logged by, Photos, Crust, Crumb, Flavour and Overall (tap a star; tap the same star again to clear it), Problems (Dense crumb, Gummy, Flat / didn’t rise, Over-proofed, Under-proofed, Burnt, Pale crust) and Notes. With an AI key you can describe a bake and press Fill this in. Delete this bake asks first.
• A bake’s page: ratings, problems, notes, who logged it, Duplicate (a copy dated today), Share, a link to its recipe, and “Lessons from this bake” with a box to add one.
• Bake insights and lessons (a button under the bakes, or Insights › Bakes): the numbers (bakes, rated, average rating); the best bake; a trend chart and averages by recipe and by category (they appear once two bakes are rated); how often each problem came up; and the notebook “Lessons learned and improvements”. A lesson has its words, who noticed it, the recipe it is about, the jar or bake it came from and the day it was written. Remove takes one away and offers Undo for 4 seconds. A lesson is tied to a bake when you add it on that bake’s page; the notebook’s own form has the list “From a jar or bake” to tie a lesson to either.
"""),

        Section(title: "Insights", text: """
The Insights tab has a switch, Ferments | Bakes.
Ferments:
• When your jars hold more than one vegetable, a list picks All vegetables or one vegetable, and everything below follows it.
• Your jars: Jars, Active now (fermenting or in the fridge), Success rate and Average rating.
• Recommended recipe: once two finished jars are rated 4 or more, the typical values of those jars (vegetable, brine, temperature, days, lid). Until then it says how to get one.
• With at least two finished, rated jars: Best jar so far (with “Open this jar”), scatter charts of the rating against brine strength, room temperature and days fermented, “Rating over your attempts”, the average rating by vegetable, by form and by lid, and “Problems that came up”. With fewer, it says “Not enough yet — finish and rate at least two jars and your charts appear here.”
Bakes: see “Bakes and lessons”.
"""),

        Section(title: "Search", text: """
On the iPhone: Home › Search at the top right. On iPad and Mac: Search at the side (⌘F on the Mac). Results come as you type, grouped as Jars, Bakes and Recipes, each with its count. Every word you type must be found (in any order; capitals do not matter).
FermentLog looks in:
• Jars — name, vegetable, form, vessel, lid, weight, notes, spices, taste notes, your Did lines and the titles of To do steps.
• Bakes — name, category, recipe name, notes and problems.
• Recipes — title, category, description, storage, ingredients, equipment and the title and words of each step.
It does not look in pictures, in lessons or in the problems of a jar’s outcome.
"""),

        Section(title: "iPhone, iPad and Mac together", text: """
All your data is one file, fermentlog.json, in iCloud Drive (folder FermentLog, which you can also see in Files), with a Photos folder and a Safety copies folder beside it. Use the same Apple ID and keep iCloud Drive on for FermentLog on every device. Settings › iCloud tells you: “In iCloud — the same jars on your iPhone, iPad and Mac” or “Only on this device — iCloud Drive is off”, the State (Up to date, Uploading…, Downloading…), the time of the last sync, and Sync now. FermentLog also looks for news each time you come back to the app and whenever another device saves.
• How it joins: each time a device saves, it first reads what is in the file and joins it with its own changes, jar by jar and recipe by recipe. The newest change to each one wins and nothing the other device wrote is lost. If iCloud sets one write aside because two devices wrote at once, FermentLog joins it in and Settings says “1 clash between devices joined together since this app opened. Nothing was lost.”
• Deleting: what you delete stays hidden for 30 days (so the other devices learn of it), then leaves for good, together with pictures nobody uses any more.
• What is shared: jars, bakes, recipes, lessons, templates, people, your own vegetables, cuts and spices, and the two alarm times. What stays on each device: Appearance, “Ring on this …” and “Remind on this …”, the view you last chose (Jars or Bakes, Ferments or Bakes, What I did or Taste test) and the AI key.
• Update this device first: if another device has a newer FermentLog that stores more details, an older device shows a red bar “Update this device first”, and Settings says so too. It saves nothing, makes no safety copies and cannot import or restore until you update it in TestFlight. Nothing is lost meanwhile.
• Safety copies: the first time anything is saved each day, FermentLog writes “Daily <date>” into the Safety copies folder, checks it by reading it back, and keeps the newest 30. Copies it makes before an import or a restore (“Before import”, “Before restore”) and the ones you make with Make a safety copy now are kept for good. The pictures are copied beside them and never removed. Settings › iCloud › Safety copies lists them, newest first (“4 jars · 2 bakes · 2 recipes”). To go back: Restore this copy, then Restore this copy again to confirm. FermentLog first keeps a copy of how things are now, called “Before restore”; then everything is as it was in the copy, pictures included.
• If saving fails (iCloud not reachable, device full), a bar says “Could not save. Your changes are not stored yet.” and a red line stays in Settings › iCloud until a save works.
"""),

        Section(title: "Bringing your jars over from the web app", text: """
Your jars from the old web app come across in three steps, once:
1. Open the old FermentLog (the web app) on the iPhone.
2. Settings › Backup & export › Export backup (JSON), and save the file to Files.
3. Come back here: Settings › Bring your jars over from the web app › Choose the backup file, and pick that file.
FermentLog shows what is inside (“7 jars, 2 bakes, 3 recipes, 4 lessons, 1 template, 12 pictures”) and asks “Bring in this backup?”. Bring them in makes a safety copy “Before import” first and then adds everything. Nothing is deleted and anything already here stays; if the same jar exists on both sides, the newest change wins. Doing it again with the same file adds nothing twice. The pictures come across too. The old backup did not hold your people or your own vegetables, cuts and spices, so FermentLog collects them from the names on your entries and from your jars. The AI key does not come across; enter it again under Settings › AI assistant.
A backup made by this app (Export › Backup file) is not read here; use “Restore from a backup file” for that.
"""),

        Section(title: "Export and backup files", text: """
Settings › Export:
• Spreadsheet (.xlsx) — four tabs, Ferments, Bakes, Recipes and Lessons; the Did lines of a jar are in the last column of Ferments. It opens in Numbers, Excel and Google Sheets.
• CSV — one file with the same four parts one after the other.
• Backup file — a .json file with all your jars, bakes, recipes, templates, lessons and settings, but not the pictures (they stay in iCloud and in the safety copies).
• Restore from a backup file — asks first, makes a safety copy “Before restore” and joins the file with what is here (it does not replace it). Files from the old web app are for “Bring your jars over” instead.
Files are named fermentlog-<date>. Printing is gone: Share on a jar or a recipe sends a plain-words summary instead.
"""),

        Section(title: "The AI assistant", text: """
Optional. With your own key from Anthropic (console.anthropic.com: make an account, add a little credit, create a key that starts with sk-ant-) you can describe a jar, a recipe or a bake in your own words and let the fields fill in, ask for tips on a jar, improve a recipe, or add a taste note by writing it down. Paste the key under Settings › AI assistant and press Save; “Key saved on this device” appears with a green tick. Remove deletes it at once. You always look over the result before anything is saved.
The key is kept in this device’s keychain only. It does not travel through iCloud and is in no backup, so enter it once on each device. Only the words you write are sent to Anthropic, never your jars, pictures or ratings. You pay Anthropic directly, a fraction of a cent for each use. Without a key the AI buttons are not there, and the rest of FermentLog works as ever.
"""),

        Section(title: "Who is logging", text: """
Settings › Who is logging. Add the names of whoever logs jars, bakes and lessons (the first name you add is chosen at once). Tap a name to log as that person; the pill “Logging” shows who it is now. Jars, bakes and lessons get that name as “Logged by” when you start them, and you can change it on any entry. A new jar, too, starts with that name. Remove asks “Remove <name>?”; their name stays on what they logged. With no people added, the Logged by lists are not shown.
"""),

        Section(title: "Your lists", text: """
Settings › Your lists (near the end of Settings). The vegetables, cuts and spices you added yourself, and your jar templates, each with a line such as “used in 3 jars”.
• Rename changes the name in every jar and template that uses it.
• Remove: a vegetable or a cut can only go when no jar uses it (rename it, or change those jars first); a spice goes and is taken off every jar and template that has it. A template can be removed with Undo for 4 seconds.
The built-in vegetables, cuts and spices are not listed.
"""),

        Section(title: "Signs in this app", text: """
Every mark and colour that means something, and what it tells you.
Pills (round-ended) and tags (small, square-cornered):
• Orange pill “Fermenting · day 3” — the jar is on the counter; the number is the days since it started.
• Blue pill “In fridge · day 12” — the jar is in the fridge; the days stop at the day it went in.
• Green pill “Done” — a verdict has been recorded.
• Purple pill — a recipe’s category (for example Sourdough). Gold-brown pill — a bake’s category.
• Grey-blue pill “Logging” — the person whose name goes on new entries.
• Orange tag “Did” — a Timeline line about something you did.
• Green tag “Taste” — a Timeline line that is a taste test.
• Deep orange tag “Taste test due” — this jar needs a taste test now. The same deep orange is used for the words “Taste test due <date>” on the jar’s page, and for the tinted box above the groups.
• Grey tag “Burp alarm on” — the burp alarm rings for this jar. Your spices on a jar’s page are grey tags too: a plain fact, nothing to do.
• Red tag — a problem you noted (Mould, Dense crumb …).
Boxes and words:
• Green box “Success” and red box “Didn’t work out” — your verdict on a finished jar.
• Green brine figure — the brine is between 2 and 3 %. A plain figure is outside that range; it is a hint only.
• Red words — something is wrong (“Could not save”, “Notifications are switched off”), or it goes away when you tap it (Delete, Remove). A red bar at the top, “Update this device first”, means this device is a version behind.
• Green “done 14:05” under a To do step — the time you ticked it.
Marks:
• ✓ green tick — in order: the brine is in the sweet spot, notifications are allowed, the AI key is saved.
• Round box with a hand-drawn green tick — a To do step that is done. A grey empty circle is a step still to do.
• ★ ☆ stars — a rating from 1 to 5; a filled star counts and an empty one does not, in the colour of the part. A dash “—” means no rating or no value. “Not rated yet” is a bake with no stars.
• Chips — in Spices and in Problems, a chip with a coloured outline is chosen; a grey chip is not.
• The drag handle at the right of a recipe step — hold it and drag to move the step (“Drag a step to move it”).
• The Undo bar — a small bar at the bottom after you remove something or log a burp. It goes by itself after 4 seconds; tap Undo before then to take it back.
• Hand-drawn marks — a jar (Jars), a book (Recipes), a loaf (Bakes), a chart (Insights), a magnifying glass (Search), a gear (Settings), a plus (New). Each stands for the part it opens.
• Colours of the parts — orange Jars, gold-brown Bakes, purple Recipes, teal Insights, slate blue Search, grey-blue Settings: headings, marks and the main button of that part.
• A full-colour button — the main thing to do on that page; the softer tinted buttons are the other choices.
"""),
    ]
}
