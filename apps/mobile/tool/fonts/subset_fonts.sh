#!/usr/bin/env bash
# Builds the bundled Saarthee fonts (DS §3, TASK-03 step 3).
#
# Sources (SIL OFL 1.1, Ek Type), from the Google Fonts repository:
#   https://github.com/google/fonts/tree/main/ofl/baloobhai2  (variable wght)
#   https://github.com/google/fonts/tree/main/ofl/muktavaani  (static)
# Downloaded 2026-10-03 (see assets/fonts/SOURCES.md).
#
# Requires: python3 with `fonttools` and `brotli` (pip install fonttools brotli).
# Usage (from apps/mobile): tool/fonts/subset_fonts.sh [work-dir] [fonttools-binary]
set -euo pipefail

WORK="${1:-$(mktemp -d)}"
FT="${2:-fonttools}"   # path to the fonttools CLI
OUT="assets/fonts"
RAW="https://raw.githubusercontent.com/google/fonts/main/ofl"
mkdir -p "$WORK" "$OUT"

fetch() { [ -f "$WORK/$2" ] || curl -fsSL "$1" -o "$WORK/$2"; }
fetch "$RAW/baloobhai2/BalooBhai2%5Bwght%5D.ttf" BalooBhai2-VF.ttf
fetch "$RAW/baloobhai2/OFL.txt" BalooBhai2-OFL.txt
for w in Regular Medium SemiBold; do
  fetch "$RAW/muktavaani/MuktaVaani-$w.ttf" "MuktaVaani-$w.ttf"
done
fetch "$RAW/muktavaani/OFL.txt" MuktaVaani-OFL.txt

# Basic Latin, Latin-1, General Punctuation, Rupee, Gujarati, danda,
# ZWNJ/ZWJ and the dotted circle (shaping fallback).
UNICODES="U+0020-007E,U+00A0-00FF,U+2000-206F,U+20B9,U+0A80-0AFF,U+0964-0965,U+200C-200D,U+25CC"

subset() {
  "$FT" subset "$1" --unicodes="$UNICODES" --layout-features='*' --no-hinting \
    --name-IDs='*' --name-languages='*' --notdef-outline \
    --output-file="$2"
}

for pair in "600:SemiBold" "700:Bold" "800:ExtraBold"; do
  w="${pair%%:*}"
  name="${pair##*:}"
  "$FT" varLib.instancer "$WORK/BalooBhai2-VF.ttf" "wght=$w" \
    --static --output "$WORK/BalooBhai2-$name-full.ttf"
  subset "$WORK/BalooBhai2-$name-full.ttf" "$OUT/BalooBhai2-$name.ttf"
done
for w in Regular Medium SemiBold; do
  subset "$WORK/MuktaVaani-$w.ttf" "$OUT/MuktaVaani-$w.ttf"
done
cp "$WORK/BalooBhai2-OFL.txt" "$OUT/BalooBhai2-OFL.txt"
cp "$WORK/MuktaVaani-OFL.txt" "$OUT/MuktaVaani-OFL.txt"
ls -l "$OUT"
