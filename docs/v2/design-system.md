# Saarthee v2 — Design System ("Neem")

**Version:** 2.2 · **Date:** 2026-10-03 · Direction chosen by the founder from four directions in `docs/v2/design-options.html` (A Civic Blue refined, **B Neem**, C Sabarmati Night, D Pol Heritage). Fonts chosen from seven pairings in `docs/v2/font-options.html`. Replaces Civic Blue v2.0, the v1 indigo/marigold tokens and "Pol Sunset".
**Principles:** neighbourly, warm, serious. A deep neem-green brand, rounded Baloo Bhai 2 headings with Mukta Vaani text, one warm sunrise orange that means "report a problem", generous spacing and rounded cards. Every status and severity carries an icon and a word, never colour alone. Plain language in Gujarati and English. Motion gives feedback and a sense of progress, never decoration. Deliberately distinct from AMC's branding.

## DS §1 Identity and independence

- Name: **Saarthee · સારથી**. Wordmark in Baloo Bhai 2 Bold, sentence case, `textPrimary`, or white on `primary`. English and Gujarati sit side by side or swap by locale (never stacked English-over-Gujarati, which is AMC's lockup).
- Mark: rounded square (corner radius 28% of size) in `primary` with a white upward-right route chevron ending in a `sunrise` dot ("the way forward"). No seal, no circle emblem, no architecture, no wheel/chakra, no AMC colours (bronze `#9E6B22`, amber, navy gradient `#1E3C72→#2A5298`, teal).
- Name origin, used in store copy and About: neem, the tree that shades Amdavad's streets.
- Tagline: "Report it. Track it. See it fixed." · "ફરિયાદ કરો. ફોલો કરો. ઉકેલ જુઓ." (Gujarati to be checked by a native copy editor.)
- Independence line, shown in onboarding, About, alert footers, services and every AMC hand-off: "Independent citizen app. Not run by or linked to AMC." · "નાગરિકોની સ્વતંત્ર એપ. AMC દ્વારા ચલાવાતી કે તેની સાથે જોડાયેલી નથી."
- Never "AMC" in the app name, icon or store title (Google Play government-information policy).

## DS §2 Colour tokens

Contrast = (L₁+0.05)/(L₂+0.05), WCAG 2.2; all pairs computed. Light theme:

| Token | Hex | Use | Contrast |
|---|---|---|---|
| `primary` | #14674A | Brand header, filled buttons, links, selected nav, focus ring base | white on it 6.84; on background 6.28 |
| `primaryDark` | #0E4A35 | Pressed state, `onPrimaryContainer`, toast background | white 10.25 |
| `primaryContainer` | #E1F0E7 | Selected nav indicator, selected tile, tonal buttons | #0E4A35 on it 8.69 |
| `onPrimarySubtle` | #BFE0CD | Secondary text on the green header | 4.81 on `primary` |
| `sunrise` | #C24A1F | **Report actions only** (Home Report card, Report tab glyph, "Submit report") | white on it 4.89 |
| `sunrisePressed` | #A33C17 | Pressed Report action | white 6.3+ |
| `background` | #F3F6F1 | Page background (leaf-tinted) | – |
| `surface` | #FFFFFF | Cards, sheets, bottom bar | – |
| `surfaceAlt` | #E8EFEA | Stat tiles, skeletons, progress track | – |
| `border` | #DCE5DE | Card borders, dividers | decorative |
| `borderStrong` | #86978C | Input borders, non-text UI | 3.08 on white |
| `textPrimary` | #17251E | Body text | 15.91 on white |
| `textSecondary` | #4E5E55 | Metadata, helper text | 6.87 on white, 6.30 on background |
| `textDisabled` | #8A978F | Disabled | exempt |
| `success` / `successTint` | #1A7340 / #E6F4EC | Success | 5.88 / 5.19 |
| `warning` / `warningTint` | #9A5B00 / #FFF4E0 | Warnings | 5.43 / 4.98 |
| `error` / `errorTint` | #B3261E / #FCEBEA | Errors (always with icon; never confused with `sunrise` because errors carry `error` icon + text) | 6.54 / 5.67 |
| `info` / `infoTint` | #1F5FAE / #E5EEFA | Info | 6.3 / 5.6 |
| `focus` | #FFDD00 ring + #17251E inner | Keyboard/TalkBack focus only | – |

Rules: `sunrise` appears at most once per screen and only on the report action; everything else interactive is `primary`. Never put `sunrise` and `error` next to each other.

**Issue status**: unchanged from v2.0. Solid colours have white text, tints use the solid colour as text, and each status uses a Material Symbols **Rounded** icon.

| Status | Solid | Tint | Icon | Word (en / gu) |
|---|---|---|---|---|
| Reported (open) | #4B5768 | #EDF0F4 | `radio_button_unchecked` | Reported / નોંધાયેલ |
| Sent / Acknowledged | #1F5FAE | #E5EEFA | `mark_email_read` | Acknowledged / સ્વીકારાયેલ |
| In progress | #8A5300 | #FFF3DC | `construction` | In progress / કામ ચાલુ |
| Marked fixed | #1A7340 | #E6F4EC | `check_circle` | Fixed / ઉકેલાયેલ |
| Verified | #0E5233 | #DDEFE5 | `verified` | Verified / ચકાસાયેલ |
| Reopened | #B4400F | #FDEDE4 | `replay` | Reopened / ફરી ખોલાયેલ |
| Rejected | #8A2234 | #F8E7EA | `block` | Not accepted / સ્વીકાર્ય નથી |

**Alert severity:** Info #1F5FAE/#E5EEFA (`info`) · Advisory #6F5A00/#FBF5D9 (`campaign`) · Warning #A34A00/#FFEEDD (`warning`) · Critical #B3261E/#FCEBEA (`emergency`, solid banner, white text). Non-critical alerts are tinted cards with the severity icon; no side bars.

**Categories**: glyph in the category colour on a 12% tint of it, inside a 40 dp rounded square (radius 14). Map pins use the solid colour with a white glyph. Category colours are never used as large fills.

| Slug | Hex | Glyph on 12% tint | Icon |
|---|---|---|---|
| roads | #5A5F66 | ≥ 5.4 | `road` |
| water | #1D5E9E | ≥ 5.6 | `water_drop` |
| drainage | #3F5E73 | ≥ 5.8 | `water_damage` |
| garbage | #5C6B2E | ≥ 4.9 | `delete` |
| streetlight | #8A5F00 | ≥ 4.7 | `lightbulb` |
| trees | #2E6B45 | ≥ 5.3 | `park` |
| animals | #7A4E2D | ≥ 6.0 | `pets` |
| health | #7A3F6B | ≥ 6.4 | `pest_control` |
| toilets | #2F6670 | ≥ 5.4 | `wc` |
| encroachment | #8C3B2E | ≥ 6.3 | `do_not_step` |
| traffic | #9C3D1A | ≥ 5.7 | `traffic` |
| property | #4F5A7A | ≥ 5.7 | `receipt_long` |
| building | #6B4F3A | ≥ 6.3 | `apartment` |
| other | #66707C | ≥ 4.6 | `more_horiz` |

The tint contrasts above are targets. TASK-03 computes the exact value for each pair in a test and darkens any glyph that falls below 4.5 (icons need 3:1, but the label beside them needs 4.5).

**Dark theme (P1):** background #131C18, surface #1A2520, border #2A3830, textPrimary #E6EFE9 (14.8), textSecondary #A9B9AF (8.5), primary #7BD3A6 with onPrimary #0F1A15 (9.9), sunrise #FF9E78 with onSunrise #1B120D (9.1). Status and severity use their tints as text on `surface`. TASK-03 re-checks every pair against AA.

## DS §3 Typography

Two families from Ek Type (Mumbai), designed together for Gujarati and Latin, both under the OFL. The founder chose them on 2026-10-03 from seven pairings in `docs/v2/font-options.html`.
- **Baloo Bhai 2** for display and headings: rounded, warm terminals that echo Neem's rounded cards. Weights 600/700, plus 800 for display numbers only.
- **Mukta Vaani** for body text, labels, buttons and metadata: open and plain, crisp at 12 sp. Weights 400/500/600.

Both are bundled as subset TTFs (Gujarati + Basic Latin + Latin-1 + ₹ and punctuation). Fallback `Noto Sans Gujarati`, `Noto Sans` (+ Noto Sans Devanagari for phase 3).

| Role | Family | sp | Weight | Line height |
|---|---|---|---|---|
| displaySmall (Home greeting, success) | Baloo Bhai 2 | 28 | 700 | 36 |
| headlineSmall (screen title, step question) | Baloo Bhai 2 | 24 | 700 | 32 |
| titleLarge (section) | Baloo Bhai 2 | 19 | 600 | 26 |
| titleMedium (card title) | Mukta Vaani | 16 | 600 | 22 |
| bodyLarge (default) | Mukta Vaani | 16 | 400 | 24 |
| bodyMedium | Mukta Vaani | 14 | 400 | 21 |
| labelLarge (buttons) | Mukta Vaani | 15.5 | 600 | 21 (was 20; Gujarati vowel signs touched in two-line buttons, 2026-10-04) |
| labelMedium (chips, nav) | Mukta Vaani | 12 | 600 | 16 |
| numeric (stat tiles, counts) | Baloo Bhai 2 | 20 | 700 | 24, tabular figures |
| bodySmall (metadata, minimum) | Mukta Vaani | 12 | 400 | 17 |

Rules:
- Baloo is never used below 16 sp or for running text, because it gets heavy.
- Card titles stay in Mukta Vaani so long Gujarati titles remain readable.
- No size below 12 sp, and no letter-spacing or ALL CAPS on Indic text.
- Layouts are tested at 1.3× and 2.0× font scale.
- Gujarati line heights are never reduced below the values above, because matras clip otherwise. Baloo's tall ascenders need the 36/32 line heights.

## DS §4 Shape, spacing, elevation, icons

- **Radius:**
  - 14: buttons, inputs, stat tiles, category badges, thumbnails.
  - 18: cards, tiles, alert cards.
  - 24: bottom sheets, and the top corners of dialogs.
  - Full pill: chips and the nav indicator.
- **Spacing:** 4 dp base; scale 4/8/12/14/16/20/24/32/40. Page gutter 16 dp; 14 dp between cards; 24 dp above a section title, 12 dp below it. Content max width 600 dp on tablets/web (the staff console uses 1,200 dp with side navigation).
- **Home header:** the green `primary` band holds the greeting, the ward and the Report card, overlapping the page like a hero. Other screens use a white app bar with a 1 px border once scrolled.
- **Elevation:**
  - Cards: 1 px `border` plus a 1 dp soft shadow (`#17251E` at 5%).
  - Report card: `sunrise` glow, 0 10 22 −10 at 70%.
  - Sheets, dialogs and toasts: elevation 3.
- **Icons:** Material Symbols **Rounded**, weight 400, 24 dp. The filled variant is used for the selected nav tab and the Report "+". No illustrations, mascots or clip art. Empty states use a 56 dp icon on a `primaryContainer` circle, one line of text and one action.
- **Photos:** 4:3, radius 14, no border. Add the caption "Faces and number plates blurred" where blurring was applied.

## DS §5 Components

| Component | Spec |
|---|---|
| Home header | `primary` band: ward line (`onPrimarySubtle`), greeting (displaySmall, white), language + bell buttons (36 dp circles, white 14%), Report card below |
| Report card | `sunrise` fill, 56 dp min height, radius 14, white "+" in a 32 dp circle, title + one-line hint ("Pothole, garbage, water, anything"), trailing arrow |
| App bar (other screens) | White, left-aligned title (headlineSmall), back arrow, actions; 1 px bottom border on scroll |
| Bottom navigation | M3 `NavigationBar`, 5 destinations Home / Map / Report / Alerts / My Ward, labels always visible, `primaryContainer` pill indicator; the Report glyph uses `sunrise` |
| Primary button | Filled `primary`, height 50 dp (56 dp pinned at the bottom of a step), radius 14, sentence case, verb first; one per screen; shows progress inside the button and is disabled while working. "Submit report" uses `sunrise` |
| Secondary / tertiary | Outlined (1.5 px `borderStrong`, `primary` text) / text button |
| Inputs | Label above, 1 px `borderStrong`, radius 14, 2 px `primary` on focus, helper text below, error text with icon below, "(optional)" suffix |
| Error summary | Box at the top of the form on submit, with links to each error; focus moves to it |
| Chips | Filter chips are pills. Status chips use the tint background, the solid colour as text and a leading icon |
| Stat tiles | `surfaceAlt`, radius 14, number (numeric) and label (bodySmall) |
| List rows | ≥ 56 dp (72 dp for two lines); leading 40 dp category badge; trailing status chip or chevron |
| Issue card | Photo thumbnail, category badge, title, ward · age, status chip, "Me too" count, overdue tag |
| Status timeline | Vertical stepper with 14 dp dots in the status colour, actor and date for each step, future steps hollow grey. Fixed steps carry their after-photos and the "Yes, fixed" / "Still not fixed" buttons |
| Alert card | Tint of the severity, severity icon + word, title, area, validity, source line; Critical = solid banner |
| Toast / snackbar | `primaryDark` background, white text, leading animated check (success) or icon; radius 18; 4 s |
| Banners | Offline (slate): "You're offline. Your report is saved and will send automatically." · Election mode · Independence notice |
| Empty / loading / error | Skeleton rows with a gentle shimmer (never full-screen spinners). Empty: icon, one line, one action. Error: the cause in plain words and "Try again" |
| Map | Muted basemap; teardrop pins in the category colour with a white glyph and a status ring; slate cluster bubbles with counts; filter chips; preview in a bottom sheet |
| Representative row | Initials avatar, name (gu/en), role, ward, party as plain text, "Message" button; a phone number only if it is a published office number |
| Step header (report) | Close/Back, "Step 2 of 3" with a hint of the next step, animated progress bar, then the step's single question as the title |

## DS §6 Motion

Motion explains what changed and confirms what the user did. It is never there only to decorate. The style is a **gentle spring**: quick to start, a slight overshoot, a soft settle.

### Tokens (`lib/core/theme/motion.dart`, `SaartheeMotion`)

| Token | Value | Use |
|---|---|---|
| `instant` | 100 ms, `easeOut` | Press states, ripples, checkbox |
| `short` | 180 ms, `Cubic(0.2,0,0,1)` | Chip colour, icon swaps, nav indicator |
| `medium` | 280 ms, `Cubic(0.2,0,0,1)` | Page transitions, sheets, cross-fades |
| `springIn` | 380 ms, `Cubic(0.34,1.35,0.64,1)` (≤ 6% overshoot) | Cards and tiles entering, toasts, the Report card |
| `long` | 450 ms, `Cubic(0.05,0.7,0.1,1)` | Shared-element card → detail, map camera |
| `stagger` | 60 ms between items, max 6 items (later items appear with item 6) | Lists and grids on first load |
| `rise` | 14 dp translate-Y + fade | Default enter for content |
| `drawCheck` | 450 ms stroke draw, starts 150 ms after its container | Success check marks |
| `countUp` | 600 ms, `easeOutCubic`, integers only | Stat numbers, ward scorecard |

Every animation must use these tokens. A widget test checks that no `Duration(` literal appears in `lib/features/**`.

### Catalogue

| Moment | Motion | Owner |
|---|---|---|
| App launch | Mark scales 0.92 → 1 and fades over `medium`, then the first screen cross-fades in. Nothing loops | TASK-03 |
| Onboarding | Shared-axis X between language → intro → ward. Selected language card springs to 1.02 and back | TASK-03 |
| Tab switch | Fade-through (`medium`); the nav pill slides and stretches between tabs (`short`). Each tab keeps its scroll | TASK-03 |
| Push navigation | Shared-axis X forward/back (`medium`). Sheets slide up with `springIn` | TASK-03 |
| Buttons and cards | Scale 0.97 on press (`instant`) plus a light haptic for primary actions | TASK-03 |
| Skeletons | Shimmer at 1.2 s per sweep at low contrast. It stops as soon as content arrives and cross-fades to it | TASK-03 |
| Home first load | Header elements, then alert, stats and cards rise with `stagger`. Only on first load, not when returning to the tab | TASK-07 |
| Report card | Springs in. A single `sunrise` ring pulses once on a user's first launch only | TASK-07 |
| Report step 1 | Tiles pop in (scale 0.88 → 1, 35 ms stagger). The selected tile springs, gets an outline and a selection haptic | TASK-05 |
| Between report steps | Shared-axis X. The progress bar animates to its new width (`medium`). Back reverses | TASK-05 |
| Photo captured | Thumbnail flies from the capture point into its slot (`long`). The pin drops onto the mini-map with a small bounce | TASK-05 |
| Duplicate found | Suggestion card slides down from under the map with `springIn`. "Add me too" morphs into "Added ✓" | TASK-05 |
| Report submitted | Full-screen success: green circle scales in, check draws, then the issue number fades up. Success haptic. No confetti | TASK-05 |
| Status change | Chip cross-fades colour, icon and word (`short`). The new timeline step expands in from its dot | TASK-06 |
| Verify fix ("Yes, fixed") | Button turns into a progress bar, then the toast slides up with a drawn check. The chip goes Fixed → Verified | TASK-06 |
| Feed card → detail | Shared element (`Hero`) on the photo and title (`long`). The rest of the detail rises in with `stagger` | TASK-07 |
| "Me too" | Icon springs to 1.2 and back. The count rolls to the next digit. Light haptic | TASK-07 |
| Pull to refresh | Branded indicator that turns the route chevron; new items rise in | TASK-07 |
| Map | Pins drop in with a 30 ms stagger (max 20 animated). Tapping a cluster zooms with `long`. The preview sheet uses `springIn` | TASK-07 |
| New alert while open | Banner slides down from under the app bar with `springIn`. Critical alerts get one slow attention pulse and no loop | TASK-08 |
| Inbox | Swipe to mark read: the row compresses and the unread dot fades. The badge count rolls | TASK-08 |
| My Ward | Representative rows rise with `stagger`. "Message sent" shows a toast with a drawn check | TASK-09 |
| Scorecard and dashboards | Numbers `countUp`. Bars grow from 0 (`long`) when first seen, not on every rebuild | TASK-09 (scorecard), TASK-11 (dashboard) |
| Initiative RSVP | "Going" button morphs into a filled pill with a check. The attendee count rolls | TASK-12 |
| Staff console (web) | `short` fades only. No staggers or springs; staff screens prioritise speed | TASK-10 |

### Rules

- **Reduced motion:** when the system "Remove animations" setting is on (`MediaQuery.disableAnimations`), or after the user turns off "Animations" in Settings, every motion becomes an instant change or a ≤ 100 ms cross-fade. Content is identical either way. Haptics follow the system setting separately.
- **Performance:**
  - Only animate transform, opacity and colour. Never animate layout size, except the progress bar and the expanding timeline step, which are clipped.
  - Hold 60 fps on the reference low-end phone (Android 10, 3 GB RAM, as in TASK-14). No frame may exceed 16 ms during a catalogued motion in a profile build.
  - Lottie and Rive are not used. Success checks and the refresh indicator are drawn with `CustomPainter`.
- **Accessibility:**
  - Motion never carries meaning alone; text always changes too.
  - TalkBack announces the state change ("Status changed to Fixed").
  - Nothing blinks more than 3 times per second.
  - Nothing loops forever except a skeleton while it waits.
- **Libraries (candidates, check on pub.dev and pin):**
  - `animations` (Material motion: shared axis, fade-through, container transform);
  - `flutter_animate` (stagger, rise, pop);
  - built-in `Hero` and `HapticFeedback`.

## DS §7 Accessibility

WCAG 2.2 AA / GIGW 3.0:
- Contrast as tabulated.
- 48 dp touch targets.
- Labels on every control and photo ("Photo of the problem, taken 3 Oct, 2:19 pm").
- Status and severity always shown as icon + word.
- Focus order equals visual order; the error summary receives focus.
- TalkBack reads "Step n of 3".
- Works at 2.0× font size.
- The language picker shows each language in its own script.
- Reduced motion is respected (DS §6).

## DS §8 Key flows (easy to use)

- **Report (3 steps):**
  1. *What is the problem?* A category grid of 14 large tiles, each with icon and label.
  2. *Photo and place.* Camera first, up to 3 photos, location filled in on a mini-map with "Adjust pin". Duplicate suggestions appear here.
  3. *Details and check.* Optional description with voice input, a summary with Change links, and the consent line.

  Then **Submit report** (in `sunrise`) and the success screen. Target: ≤ 4 taps after the photo for a typical issue.
- **Verify a fix:** notification → issue detail → "Is it fixed?" Yes / Still not fixed → photo at the spot → Send → toast with a drawn check.
- **Find my corporators:** My Ward tab → four corporators listed, each with a Message button.
- **Alert:** push → alert detail with what, where, when and the source → "Turn off alerts like this" link.

## DS §9 Screen inventory

**Citizen:**
- Onboarding (language, intro, ward); sign-in (phone, OTP, age).
- Home, Map, Report (3 steps + submitted), Issue detail, Verify, Escalate, Link CCRS.
- Alerts inbox, Alert detail, Alert settings.
- My Ward, Representative profile, Message representative, Ward scorecard.
- Services list, Service detail, Initiatives list/detail.
- Me, My reports, Following, Settings (including Animations on/off), Privacy & data, About.

**Staff** (web + app, side navigation on wide screens): Dashboard, Moderation queue, Issue tools, Alerts list + composer + approvals, Representatives, Claims, Services, Initiatives, Categories, Users & roles, Election mode, Exports.

**Representative:** Ward dashboard, Ward issues, Messages.
