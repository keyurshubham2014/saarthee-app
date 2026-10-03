#!/usr/bin/env bash
# Emulator UI helper for the demo walk-through.
#   ui.sh dump              -> list visible labels with tap centres
#   ui.sh tap "<label regex>" [n] -> tap nth match (default 1)
#   ui.sh shot <name>       -> save $EVIDENCE_DIR/<name>.png (default docs/demo/evidence)
#   ui.sh rec <name> <secs> -> screenrecord to $EVIDENCE_DIR/motion/<name>.mp4
#   ui.sh type "<text>"     -> type text in the focused field (single adb call)
set -euo pipefail
ADB="${ADB:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT/docs/demo/evidence}"
dump() {
  "$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  "$ADB" exec-out cat /sdcard/ui.xml | python3 -c '
import sys,re,html
x=sys.stdin.read()
for m in re.finditer(r"<node [^>]*>", x):
    n=m.group(0)
    t=html.unescape(re.search(r"text=\"([^\"]*)\"",n).group(1))
    d=html.unescape(re.search(r"content-desc=\"([^\"]*)\"",n).group(1))
    b=re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"",n)
    lab=(t or d).replace("\n"," / ")
    if lab and b:
        x1,y1,x2,y2=map(int,b.groups()); print(f"{(x1+x2)//2},{(y1+y2)//2}\t{lab}")
'
}
case "$1" in
  dump) dump ;;
  tap)
    n="${3:-1}"
    xy=$(dump | awk -F'\t' -v re="$2" 'tolower($2) ~ tolower(re) {print $1}' | sed -n "${n}p")
    [ -n "$xy" ] || { echo "no match for: $2" >&2; exit 1; }
    "$ADB" shell input touchscreen swipe "${xy%,*}" "${xy#*,}" "${xy%,*}" "${xy#*,}" 120; echo "tapped $xy ($2)";;
  shot) mkdir -p "$EVIDENCE_DIR"; "$ADB" exec-out screencap -p > "$EVIDENCE_DIR/$2.png"; echo "saved $2.png";;
  rec)
    mkdir -p "$EVIDENCE_DIR/motion"
    "$ADB" shell screenrecord --time-limit "${3:-6}" --bit-rate 6000000 "/sdcard/$2.mp4"
    "$ADB" pull "/sdcard/$2.mp4" "$EVIDENCE_DIR/motion/$2.mp4" >/dev/null && "$ADB" shell rm "/sdcard/$2.mp4"; echo "saved motion/$2.mp4";;
  type) "$ADB" shell input text "$(printf '%s' "$2" | sed 's/ /%s/g')";;
esac
