#!/bin/bash
# Photographs every page of the Mac app, by day and by night, with sample data and without one click.
#   tools/mac-pictures.sh [out-folder]        (default: build/shots/mac-all)
# Mac screen tests need a fingerprint for every run; this needs nothing: the app opens each page itself
# (launch arguments in App/Sources/PictureArgs.swift, only with -uiTesting = sample data in a throw-away folder),
# and `screencapture` takes the window. Look at every picture afterwards.
set -e
cd "$(dirname "$0")/.."
OUT="${1:-build/shots/mac-all}"
DD="${TMPDIR:-/tmp}/AMSFermentLog-macpictures"
xcodegen generate >/dev/null
xcodebuild -project AMSFermentLog.xcodeproj -scheme AMSFermentLog -destination 'platform=macOS' -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD" || true
APP="$DD/Build/Products/Debug/AMSFermentLog.app"
BIN="$APP/Contents/MacOS/AMSFermentLog"
[ -x "$BIN" ] || { echo "no Mac app built"; exit 1; }
swiftc -O tools/winid.swift -o "$DD/winid"

CAB="b_sample_cabbage"; BEET="b_sample_beets"; KRAUT="r_sample_sauerkraut"; BAKE="k_sample_1"
SHOTS=(
"01-jars|-part:jars"
"02-jar-1|-part:jars -open:jar:$CAB"
"02-jar-photo|-samplePhoto -part:jars -open:jar:$CAB"
"01-jars-photo|-samplePhoto -part:jars"
"02-jar-2|-part:jars -open:jar:$CAB -scrollDown:650"
"02-jar-3|-part:jars -open:jar:$CAB -scrollDown:1300"
"02-jar-4|-part:jars -open:jar:$CAB -scrollDown:1950"
"03-jar-line-editor|-part:jars -open:jar:$CAB -sheetLine"
"04-jar-outcome-form|-part:jars -open:jar:$CAB -sheetOutcome"
"05-jar-edit-1|-part:jars -open:jar:$CAB -open:jarEdit:$CAB"
"05-jar-edit-2|-part:jars -open:jar:$CAB -open:jarEdit:$CAB -scrollDown:650"
"05-jar-edit-3|-part:jars -open:jar:$CAB -open:jarEdit:$CAB -scrollDown:1300"
"06-jar-new-1|-part:jars -open:jarNew"
"06-jar-new-2|-part:jars -open:jarNew -scrollDown:650"
"07-jar-done-1|-part:jars -open:jar:$BEET"
"07-jar-done-2|-part:jars -open:jar:$BEET -scrollDown:650"
"07-jar-done-3|-part:jars -open:jar:$BEET -scrollDown:1300"
"08-bakes|-part:bakes"
"09-bake-1|-part:bakes -open:bake:$BAKE"
"09-bake-2|-part:bakes -open:bake:$BAKE -scrollDown:650"
"10-bake-edit-1|-part:bakes -open:bake:$BAKE -open:bakeEdit:$BAKE"
"10-bake-edit-2|-part:bakes -open:bake:$BAKE -open:bakeEdit:$BAKE -scrollDown:650"
"11-bake-new|-part:bakes -open:bakeNew"
"12-bake-insights-1|-part:bakes -open:bakeInsights"
"12-bake-insights-2|-part:bakes -open:bakeInsights -scrollDown:650"
"13-recipes|-part:recipes"
"14-recipe-1|-part:recipes -open:recipe:$KRAUT"
"14-recipe-2|-part:recipes -open:recipe:$KRAUT -scrollDown:650"
"14-recipe-3|-part:recipes -open:recipe:$KRAUT -scrollDown:1300"
"15-recipe-edit-1|-part:recipes -open:recipe:$KRAUT -open:recipeEdit:$KRAUT"
"15-recipe-edit-2|-part:recipes -open:recipe:$KRAUT -open:recipeEdit:$KRAUT -scrollDown:650"
"15-recipe-edit-3|-part:recipes -open:recipe:$KRAUT -open:recipeEdit:$KRAUT -scrollDown:1300"
"15-recipe-edit-4|-part:recipes -open:recipe:$KRAUT -open:recipeEdit:$KRAUT -scrollDown:1950"
"16-recipe-new|-part:recipes -open:recipeNew"
"17-insights-1|-part:insights -insights:ferments -charts"
"17-insights-2|-part:insights -insights:ferments -charts -scrollDown:650"
"17-insights-3|-part:insights -insights:ferments -charts -scrollDown:1300"
"18-insights-bakes|-part:insights -insights:bakes"
"19-search-empty|-part:search"
"20-search-cab|-part:search -search:cab"
"21-settings-1|-part:settings"
"21-settings-2|-part:settings -scrollDown:650"
"21-settings-3|-part:settings -scrollDown:1300"
"22-your-lists-1|-part:settings -open:manageLists"
"22-your-lists-2|-part:settings -open:manageLists -scrollDown:650"
"23-safety-copies|-part:settings -open:safetyCopies"
"24-how-it-works-1|-part:settings -open:guide"
"24-how-it-works-2|-part:settings -open:guide -scrollDown:650"
"24-how-it-works-3|-part:settings -open:guide -scrollDown:1300"
"24-how-it-works-4|-part:settings -open:guide -scrollDown:1950"
"24-how-it-works-5|-part:settings -open:guide -scrollDown:2600"
"25-whats-new-1|-part:settings -open:whatsNew"
"25-whats-new-2|-part:settings -open:whatsNew -scrollDown:650"
"26-settings-window-1|-part:jars -settingsWindow"
"26-settings-window-2|-part:jars -settingsWindow -scrollDown:700"
)
ONLY="${ONLY:-}"     # ONLY=05-jar-edit → just the pictures whose name starts with that; ONLY="01 02 14" → several
for MODE in light dark; do
  mkdir -p "$OUT/$MODE"
  STYLE=Light; [ "$MODE" = dark ] && STYLE=Dark
  for S in "${SHOTS[@]}"; do
    NAME="${S%%|*}"; ARGS="${S#*|}"
    if [ -n "$ONLY" ]; then HIT=""; for O in $ONLY; do [[ "$NAME" == $O* ]] && HIT=1; done; [ -z "$HIT" ] && continue; fi
    [ -n "$KEEP" ] && [ -f "$OUT/$MODE/$NAME.png" ] && continue     # KEEP=1 → only the pictures still missing
    # shellcheck disable=SC2086
    if [ -n "$QUIET" ]; then
      # QUIET=1 → the window opens BEHIND whatever he is working in and never takes his typing.
      open -g -n "$APP" --args -uiTesting -sample -$MODE -tall -AppleInterfaceStyle $STYLE $ARGS
      sleep 3.8
      PID=$(pgrep -n -f "AMSFermentLog-macpictures/Build/Products/Debug/AMSFermentLog.app/Contents/MacOS/AMSFermentLog")
    else
      "$BIN" -uiTesting -sample -$MODE -tall -AppleInterfaceStyle $STYLE $ARGS >/dev/null 2>&1 &
      PID=$!
      sleep 3.4
    fi
    N=0
    "$DD/winid" $PID | while read -r WID WNAME; do
      N=$((N+1)); SUFFIX=""; [ $N -gt 1 ] && SUFFIX="-window$N"
      screencapture -x -o -l"$WID" "$OUT/$MODE/$NAME$SUFFIX.png" 2>/dev/null \
        || { sleep 1.5; screencapture -x -o -l"$WID" "$OUT/$MODE/$NAME$SUFFIX.png" 2>/dev/null; } \
        || echo "NO PICTURE: $MODE $NAME$SUFFIX"
      echo "$MODE $NAME$SUFFIX: window title '$WNAME'" >> "$OUT/titles.txt"
    done
    kill $PID 2>/dev/null || true
    wait $PID 2>/dev/null || true
  done
done
echo "Pictures in $OUT"
