# Saarthee v2 — Design System ("Civic Blue")

**Version:** 2.0 · **Date:** 2026-10-03 · Replaces the v1 indigo/marigold tokens and the rejected "Pol Sunset" proposal.
**Principles:** professional, calm, easy to use. One primary colour with one job (actions). Neutral everywhere else. Every status and severity carries an icon and a word, never colour alone. Plain language in Gujarati and English. Inspired by GOV.UK, USWDS, Singapore SGDS and India's UX4G/GIGW 3.0, and deliberately distinct from AMC's own branding.

## DS §1 Identity and independence

- Name: **Saarthee · સારથી**. Wordmark in Noto Sans SemiBold, sentence case, `textPrimary` or `primary`. English and Gujarati sit side by side or swap by locale (never stacked English-over-blue-Gujarati, which is AMC's lockup).
- Mark: rounded square (corner radius 28% of size) in `primary` with a white upward-right route chevron ending in a dot ("the way forward"). No seal, no circle emblem, no architecture, no wheel/chakra, no AMC colours (bronze `#9E6B22`, amber, navy gradient `#1E3C72→#2A5298`, teal).
- Tagline: "Report it. Track it. See it fixed." · "ફરિયાદ કરો. ફોલો કરો. ઉકેલ જુઓ." (Gujarati to be checked by a native copy editor.)
- Independence line, shown in onboarding, About, alert footers, services and every AMC hand-off: "Independent citizen app. Not run by or linked to AMC." · "નાગરિકોની સ્વતંત્ર એપ. AMC દ્વારા ચલાવાતી કે તેની સાથે જોડાયેલી નથી."
- Never "AMC" in the app name, icon or store title (Google Play government-information policy).

## DS §2 Colour tokens

Contrast = (L₁+0.05)/(L₂+0.05), WCAG 2.2; all pairs computed. Light theme:

| Token | Hex | Use | Contrast |
|---|---|---|---|
| `primary` | #0B57A4 | Filled buttons, links, selected nav, focus | white on it 7.21; on background 6.77 |
| `primaryDark` | #08437F | Pressed state | white 9.91 |
| `primaryContainer` | #E3EEF9 | Selected nav indicator, tonal buttons, info tint | `onPrimaryContainer` #06315C on it 11.15 |
| `secondary` | #3B5266 | Tonal buttons, selected filter chips (sparingly) | white 8.12 |
| `secondaryContainer` | #E4EAF0 | Chip backgrounds | secondary on it 6.70 |
| `background` | #F6F8FA | Page background | – |
| `surface` | #FFFFFF | Cards, sheets, app bar | – |
| `surfaceAlt` | #EEF2F6 | Section bands, skeletons | – |
| `border` | #D3DAE2 | Card borders, dividers | decorative |
| `borderStrong` | #8794A3 | Input borders, non-text UI | 3.09 on white |
| `textPrimary` | #16202B | Body text | 16.46 on white |
| `textSecondary` | #4A5664 | Metadata, helper text | 7.48 on white |
| `textDisabled` | #8A95A3 | Disabled | exempt |
| `success` / `successTint` | #1A7340 / #E6F4EC | Success | 5.88 / 5.19 |
| `warning` / `warningTint` | #9A5B00 / #FFF4E0 | Warnings | 5.43 / 4.98 |
| `error` / `errorTint` | #B3261E / #FCEBEA | Errors | 6.54 / 5.67 |
| `info` / `infoTint` | #0B57A4 / #E3EEF9 | Info | 7.21 / 6.13 |
| `focus` | #FFDD00 ring + #16202B inner | Keyboard/TalkBack focus only | – |

**Issue status** (solid = white text; tint = solid-colour text; icon is Material Symbols Outlined):

| Status | Solid | Tint | Icon | Word (en / gu) |
|---|---|---|---|---|
| Reported (open) | #4B5768 | #EDF0F4 | `radio_button_unchecked` | Reported / નોંધાયેલ |
| Sent / Acknowledged | #1F5FAE | #E5EEFA | `mark_email_read` | Acknowledged / સ્વીકારાયેલ |
| In progress | #8A5300 | #FFF3DC | `construction` | In progress / કામ ચાલુ |
| Marked fixed | #1A7340 | #E6F4EC | `check_circle` | Fixed / ઉકેલાયેલ |
| Verified | #0E5233 | #DDEFE5 | `verified` | Verified / ચકાસાયેલ |
| Reopened | #B4400F | #FDEDE4 | `replay` | Reopened / ફરી ખોલાયેલ |
| Rejected | #8A2234 | #F8E7EA | `block` | Not accepted / સ્વીકાર્ય નથી |

**Alert severity:** Info #1F5FAE/#E5EEFA (`info`) · Advisory #6F5A00/#FBF5D9 (`campaign`) · Warning #A34A00/#FFEEDD (`warning`) · Critical #B3261E/#FCEBEA (`emergency`, solid banner, white text). Non-critical alerts are tinted cards with a 4 dp left bar.

**Categories** (white glyph in a 40 dp circle badge and map pins only; never large fills):

| Slug | Hex | White on it | Icon |
|---|---|---|---|
| roads | #5A5F66 | 6.43 | `road` |
| water | #1D5E9E | 6.67 | `water_drop` |
| drainage | #3F5E73 | 6.86 | `water_damage` |
| garbage | #5C6B2E | 5.84 | `delete` |
| streetlight | #8A5F00 | 5.65 | `lightbulb` |
| trees | #2E6B45 | 6.35 | `park` |
| animals | #7A4E2D | 7.11 | `pets` |
| health | #7A3F6B | 7.63 | `pest_control` |
| toilets | #2F6670 | 6.45 | `wc` |
| encroachment | #8C3B2E | 7.55 | `do_not_step` |
| traffic | #9C3D1A | 6.78 | `traffic` |
| property | #4F5A7A | 6.83 | `receipt_long` |
| building | #6B4F3A | 7.49 | `apartment` |
| other | #66707C | 5.03 | `more_horiz` |

**Dark theme (P1):** background #0F1620, surface #17212C, border #2A3746, textPrimary #E8EEF4, textSecondary #A9B6C4, primary #8EC1F5 (onPrimary #04203D), status/severity use tints as text on surface; every pair re-checked to AA in TASK-03.

## DS §3 Typography

Family: **Noto Sans** + **Noto Sans Gujarati** (+ Noto Sans Devanagari for phase 3), OFL, bundled as subset TTFs in weights 400/500/600. `fontFamilyFallback: [NotoSansGujarati, NotoSansDevanagari]`.

| Role | sp | Weight | Line height |
|---|---|---|---|
| displaySmall | 28 | 600 | 36 |
| headlineSmall (screen title) | 22 | 600 | 30 |
| titleLarge (section) | 19 | 600 | 28 |
| titleMedium (card title) | 17 | 600 | 24 |
| bodyLarge (default) | 16 | 400 | 24 |
| bodyMedium | 14 | 400 | 21 |
| labelLarge (buttons) | 15 | 600 | 20 |
| labelMedium (chips, nav) | 13 | 500 | 18 |
| bodySmall (metadata, minimum) | 12.5 | 400 | 18 |

No size below 12 sp, no letter-spacing or ALL CAPS on Indic text, layouts tested at 1.3× and 2.0× font scale.

## DS §4 Shape, spacing, elevation, icons

- Radius 8 (buttons, chips, inputs, thumbnails), 12 (cards), 16 (bottom sheets, dialogs top corners).
- 8 dp grid; spacing 4/8/12/16/24/32; page gutter 16 dp; content max width 600 dp on tablets/web (staff console uses 1,200 dp with side navigation).
- Elevation 0 for cards (1 px `border`), elevation only for sheets, dialogs and the snackbar.
- Icons: Material Symbols **Outlined**, weight 400, 24 dp; filled variant only for the selected bottom-nav tab. No illustrations, mascots or clip art; empty states use a 48 dp monoline icon.
- Photos: 4:3 thumbnails, radius 8, 1 px border; "Faces and number plates blurred" caption where applied.
- Motion: 150–200 ms standard easing; no decorative animation; respect "remove animations".

## DS §5 Components

| Component | Spec |
|---|---|
| App bar | White, left-aligned title (headlineSmall), ward name as subtitle on Home; actions: language switch (અ/A), notifications bell with badge; 1 px bottom border on scroll |
| Bottom navigation | M3 `NavigationBar`, 5 destinations Home / Map / Report / Alerts / My Ward, labels always visible, `primaryContainer` indicator, Report uses a filled `add_circle` icon (no floating bulge) |
| Primary button | Filled `primary`, height 48 dp (56 dp when pinned at the bottom of a step), radius 8, sentence case, verb first ("Submit report"); one per screen; shows in-button progress and disables while working |
| Secondary / tertiary | Outlined (1 px `borderStrong`) / text button |
| Inputs | Label above field, outlined 1 px `borderStrong`, 2 px `primary` on focus, helper text below, error text with icon below, "(optional)" suffix on optional fields |
| Error summary | Top-of-form box on submit with links to each error; focus moves there |
| Chips | Filter chips radius 8; status chips = tint background + solid text + leading icon |
| List rows | ≥ 56 dp (72 dp two-line); leading 40 dp category badge; trailing status chip or chevron |
| Issue card | Photo thumbnail, category badge, title, ward · age, status chip, "Me too" count, overdue tag |
| Status timeline | Vertical stepper, 12 dp dots in status colour, actor + date per step, future steps hollow grey; after-photos attached to Fixed; "Verify fix" / "Still not fixed" buttons when Fixed |
| Alert card | Severity icon + word, title, area, validity ("Today 10:00–16:00"), source line, left bar (critical = solid banner) |
| Banners | Offline (slate): "You're offline. Your report is saved and will send automatically." · Election mode · Independence notice |
| Empty / loading / error | Skeleton rows (never full-screen spinners); empty = icon + one line + one action; error = plain cause + "Try again" |
| Map | Muted basemap; teardrop pins in category colour with white glyph and status ring; slate cluster bubbles with counts; filters as chips; bottom-sheet preview |
| Representative row | Photo or initials avatar, name (gu/en), role, ward, party as plain text, "Message" button; phone only if published office number |
| Step header (report) | "Step 2 of 3" + progress bar + Back; title states the one question |

## DS §6 Accessibility

WCAG 2.2 AA / GIGW 3.0: contrast as tabulated; 48 dp targets; labels on every control and photo ("Photo of the problem, taken 3 Oct, 2:19 pm"); status and severity always icon + word; focus order equals visual order; error summary receives focus; TalkBack reads "Step n of 3"; works at 2.0× font; language picker shows each language in its own script.

## DS §7 Key flows (easy to use)

- **Report (3 steps):** 1 *What is the problem?* (category grid, 14 large tiles with icon + label) → 2 *Photo and place* (camera first, up to 3 photos, auto location on a mini-map with "Adjust pin", duplicate suggestions appear here) → 3 *Details and check* (optional description with voice, summary with Change links, consent line) → **Submit report**. Target: ≤ 4 taps after the photo for a typical issue.
- **Verify a fix:** notification → issue detail → "Is it fixed?" Yes / Still not fixed → photo at the spot → Send.
- **Find my corporators:** My Ward tab → four corporators listed with Message buttons.
- **Alert:** push → alert detail with what, where, when, source; "Turn off alerts like this" link.

## DS §8 Screen inventory

Citizen: onboarding (language, intro, ward), sign-in (phone, OTP, age), Home, Map, Report (3 steps + submitted), Issue detail, Verify, Escalate, Link CCRS, Alerts inbox, Alert detail, Alert settings, My Ward, Representative profile, Message representative, Ward scorecard, Services list, Service detail, Initiatives list/detail, Me, My reports, Following, Settings, Privacy & data, About.
Staff (web + app, side navigation on wide screens): Dashboard, Moderation queue, Issue tools, Alerts list + composer + approvals, Representatives, Claims, Services, Initiatives, Categories, Users & roles, Election mode, Exports; Representative: Ward dashboard, Ward issues, Messages.
