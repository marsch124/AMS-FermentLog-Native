#!/bin/bash
# Photographs pages of the iPhone (or iPad) app in a simulator, by day and by night, with sample data and
# without a screen test: the app opens each page itself (launch arguments, App/Sources/PictureArgs.swift).
#   tools/phone-pictures.sh <simulator-udid> [out-folder]      (default: build/shots/phone-all)
#   ONLY="02 14" → just the pictures whose name starts with one of these.
# The simulator must be booted and must be one of our own (never one another conversation uses).
set -e
cd "$(dirname "$0")/.."
UD="$1"; OUT="${2:-build/shots/phone-all}"
[ -n "$UD" ] || { echo "usage: tools/phone-pictures.sh <simulator-udid> [out-folder]"; exit 1; }
DD="${TMPDIR:-/tmp}/AMSFermentLog-build"
xcodegen generate >/dev/null
xcodebuild -project AMSFermentLog.xcodeproj -scheme AMSFermentLog -destination "platform=iOS Simulator,id=$UD" -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD" || true
APP="$DD/Build/Products/Debug-iphonesimulator/AMSFermentLog.app"
[ -d "$APP" ] || { echo "no app built"; exit 1; }
xcrun simctl install "$UD" "$APP"
ID=com.schabbauer.AMSFermentLog
CAB="b_sample_cabbage"; BEET="b_sample_beets"; KRAUT="r_sample_sauerkraut"; BAKE="k_sample_1"
SHOTS=(
"01-jars|-part:jars"
"02-jar-1|-part:jars -open:jar:$CAB"
"02-jar-2|-part:jars -open:jar:$CAB -scrollDown:620"
"02-jar-3|-part:jars -open:jar:$CAB -scrollDown:1240"
"02-jar-4|-part:jars -open:jar:$CAB -scrollDown:1860"
"07-jar-done-1|-part:jars -open:jar:$BEET"
"07-jar-done-2|-part:jars -open:jar:$BEET -scrollDown:620"
"08-bakes|-part:bakes"
"09-bake-1|-part:bakes -open:bake:$BAKE"
"09-bake-2|-part:bakes -open:bake:$BAKE -scrollDown:620"
"12-bake-insights-1|-part:bakes -open:bakeInsights"
"12-bake-insights-2|-part:bakes -open:bakeInsights -scrollDown:620"
"13-recipes|-part:recipes"
"14-recipe-1|-part:recipes -open:recipe:$KRAUT"
"14-recipe-2|-part:recipes -open:recipe:$KRAUT -scrollDown:620"
"14-recipe-3|-part:recipes -open:recipe:$KRAUT -scrollDown:1240"
"17-insights-1|-part:insights -insights:ferments -charts"
"17-insights-2|-part:insights -insights:ferments -charts -scrollDown:620"
"17-insights-3|-part:insights -insights:ferments -charts -scrollDown:1240"
"17-insights-4|-part:insights -insights:ferments -charts -scrollDown:1860"
"18-insights-bakes|-part:insights -insights:bakes"
"27-jars-line-photos|-lineSamplePhotos -part:jars"
"27-jar-line-photos-1|-lineSamplePhotos -part:jars -open:jar:$CAB"
"27-jar-line-photos-3|-lineSamplePhotos -part:jars -open:jar:$CAB -scrollDown:1240"
"27-jar-line-photos-4|-lineSamplePhotos -part:jars -open:jar:$CAB -scrollDown:1860"
"27-jar-line-photos-5|-lineSamplePhotos -part:jars -open:jar:$CAB -scrollDown:2480"
"28-jar-story|-lineSamplePhotos -part:jars -open:jar:$CAB -openStory"
"29-jar-photo-line-editor|-lineSamplePhotos -part:jars -open:jar:$CAB -sheetPhotoLine"
"20-search-cab|-part:search -search:cab"
"21-settings|-part:settings"
"25-whats-new|-part:settings -open:whatsNew"
)
for MODE in light dark; do
  mkdir -p "$OUT/$MODE"
  xcrun simctl ui "$UD" appearance $MODE
  for S in "${SHOTS[@]}"; do
    NAME="${S%%|*}"; ARGS="${S#*|}"
    if [ -n "$ONLY" ]; then HIT=""; for O in $ONLY; do [[ "$NAME" == $O* ]] && HIT=1; done; [ -z "$HIT" ] && continue; fi
    xcrun simctl terminate "$UD" $ID >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    xcrun simctl launch "$UD" $ID -uiTesting -sample $ARGS >/dev/null
    sleep 4.2
    xcrun simctl io "$UD" screenshot --type=png "$OUT/$MODE/$NAME.png" >/dev/null 2>&1 || echo "NO PICTURE: $MODE $NAME"
  done
done
xcrun simctl terminate "$UD" $ID >/dev/null 2>&1 || true
echo "Pictures in $OUT"
