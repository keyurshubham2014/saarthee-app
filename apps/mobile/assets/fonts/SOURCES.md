# Bundled fonts — sources and licences

| Family | Files | Source | Upstream | Licence | Downloaded |
|---|---|---|---|---|---|
| Baloo Bhai 2 | `BalooBhai2-SemiBold.ttf` (600), `-Bold.ttf` (700), `-ExtraBold.ttf` (800) | https://github.com/google/fonts/tree/main/ofl/baloobhai2 (`BalooBhai2[wght].ttf`, variable) | Ek Type, https://github.com/EkType/Baloo2 | SIL OFL 1.1 (`BalooBhai2-OFL.txt`) | 2026-10-03 |
| Mukta Vaani | `MuktaVaani-Regular.ttf` (400), `-Medium.ttf` (500), `-SemiBold.ttf` (600) | https://github.com/google/fonts/tree/main/ofl/muktavaani (static) | Ek Type | SIL OFL 1.1 (`MuktaVaani-OFL.txt`) | 2026-10-03 |

Built with `tool/fonts/subset_fonts.sh` (fonttools 4.x): Baloo Bhai 2 static
instances cut at `wght=600/700/800` with `varLib.instancer`, then both
families subset to Basic Latin, Latin-1, General Punctuation, ₹ (U+20B9),
Gujarati (U+0A80–0AFF), danda (U+0964–0965), ZWNJ/ZWJ and the dotted circle,
keeping **all** OpenType layout features (Gujarati conjuncts need GSUB/GPOS,
Baloo's `tnum` is kept for tabular figures) and dropping TrueType hinting.

Total ≈ 2.2 MB for the six files (Baloo ≈ 467 KB each, Mukta ≈ 275 KB each);
see TASK-03 §5.6 for the budget note. The subset files are a Modified
Version under the OFL; neither copyright notice declares a Reserved Font
Name, so the family names are kept.

Material Symbols Rounded comes from the `material_symbols_icons` package
(Apache 2.0, registered by Flutter's package licence collection).
