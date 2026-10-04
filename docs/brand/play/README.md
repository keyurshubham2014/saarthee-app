# Google Play listing assets

| File | Play requirement | Status |
| --- | --- | --- |
| `icon-512.png` | App icon: 512 × 512 px, 32-bit PNG, max 1 MB, full-bleed square. Play applies its own rounded mask (30% radius) and shadow, so do not pre-round or add a shadow. | done |
| `feature-graphic-en.png` | Feature graphic: 1024 × 500 px, JPEG or 24-bit PNG (no alpha), max 15 MB. Keep key content away from the edges; Play may crop or overlay a play button in the centre. | done |
| `feature-graphic-gu.png` | Same, for the Gujarati (gu-IN) store listing. | done |
| Phone screenshots | 2–8, PNG or JPEG, 16:9 or 9:16, each side between 320 and 3840 px. At least 4 at ≥ 1080 px are needed for promotion. | integrator (from the emulator) |
| Short description | ≤ 80 characters, en and gu | copy deck |
| Full description | ≤ 4000 characters; must state independence from AMC | copy deck |

## Content rules for every listing asset

- Show the mark, the wordmark and the tagline:
  - en: "Report it. Track it. See it fixed."
  - gu: "ફરિયાદ કરો. ફોલો કરો. ઉકેલ જુઓ."
- Include the independence line: "Independent citizen app. Not run by or linked to AMC."
- Do not use AMC logos, colours, buildings or any other government imagery. Play's impersonation
  policy also forbids implying a government affiliation.
- Do not add text such as "#1", "best" or "free" to the icon or the feature graphic.

## Regenerating

From `apps/mobile/tool/brand/` (with resvg and playwright in a scratch dir):

```
node web.mjs <repoRoot>     # icon-512.png (and the web icons)
node cards.mjs <repoRoot>   # feature graphics and web/og-image.png
```

The feature graphics are 24-bit PNG screenshots with no alpha. The fonts are the app's own Baloo
Bhai 2 and Mukta Vaani TTFs, and `cards.mjs` aborts if either one falls back to another font.
