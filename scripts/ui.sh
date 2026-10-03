#!/usr/bin/env bash
# Emulator UI helper for the demo walk-through.
#   ui.sh dump              -> list visible labels with tap centres
#   ui.sh tap "<label regex>" [n] -> tap nth match (default 1)
#   ui.sh shot <name>       -> save docs/demo/evidence/<name>.png
set -euo pipefail
ADB="${ADB:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
  shot) "$ADB" exec-out screencap -p > "$ROOT/docs/demo/evidence/$2.png"; echo "saved $2.png";;
esac
