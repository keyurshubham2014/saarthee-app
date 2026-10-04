# Saarthee v2 — code sweeps (TASK-14 steps 18 a–c and 21)

Run on branch `v2/task-14-sweeps` (from `main` @ `f563672`), 2026-10-04, with `rg` from the repo root. `node_modules`,
`build/`, `.dart_tool/` and the git-ignored generated `app_localizations*.dart` are not scanned. Every hit is either
fixed (commit named) or justified below.

## Summary

| Sweep | Hits | Fixed | Justified |
|---|---|---|---|
| 18a layout-animation (`AnimatedContainer|AnimatedSize|…`) | 3 | 0 | 3 |
| 18b loops (`.repeat(` …) | 2 | 0 | 2 |
| 18c tokens (`Duration(|Cubic(|Curves.` in features, excl. dev) | 0 | — | — |
| 21 TODO/placeholder (`TODO|FIXME|XXX|stub|mock|fake|placeholder|lorem|tbd`) | 33 code/doc lines + 182 data/metadata lines | 0 | all |
| 21 colours (`Color(0x|Colors.` outside theme) | 0 real (131 false positives on `SaartheeColors.`) | — | — |
| 21 widget string literals (`Text('…')`) | 14 | 0 | 14 |
| 21 `console.log` in `apps/api/src` | 0 | — | — |
| 21 AMC marks (`AMC logo|amc_logo|#9E6B22|1E3C72`) | 1 | 0 | 1 |
| 21 Neem: `Icons.` outside theme | 0 | — | — |
| 21 Neem: `_outlined|Outlined\b` outside theme | 1 | 0 | 1 |
| 21 Neem: `fontFamily: 'Noto` | 0 | — | — |
| 21 Neem: superseded tokens (`civic blue|indigo|marigold|secondaryContainer`) | 0 | — | — |
| 21 Neem: `sunrise` in features (review) | 6 | 0 | 6 |
| 21 gu ARB parity | en 1191 keys / gu 1191 keys, 0 missing, 0 extra | — | 52 English-looking gu values justified |

## Step 18 — safety sweeps

| Sweep | Hit | Decision | Reason |
|---|---|---|---|
| 18a | `apps/mobile/lib/features/initiatives/presentation/widgets/rsvp_button.dart:102` | justify | Fixed `height` and `width: double.infinity`; only `decoration` (fill colour, corner radius) animates — paint only, no layout pass per frame. |
| 18a | `apps/mobile/lib/features/report/presentation/motion/category_tile.dart:71` | justify | Constant padding/constraints; only the fill colour and a `foregroundDecoration` outline animate, so selecting never changes layout (comment in code). |
| 18a | `apps/mobile/lib/core/widgets/chips.dart:52` | justify | `const` padding; animates `ShapeDecoration` colour/border only (status chip tone change). |
| 18b | `apps/mobile/lib/core/widgets/states.dart:170` | justify | Skeleton shimmer; period `SaartheeMotion.shimmerPeriod` = 1200 ms (≥ 1 s); stops when content arrives or shimmer is off (reduced motion). |
| 18b | `apps/mobile/lib/features/discovery/presentation/widgets/chevron_refresh_indicator.dart:136` | justify | In-flight refresh chevron; same 1200 ms period; not started when motion is reduced. |
| 18c | — | — | 0 hits (T-03-22 guard still green). |

## Step 21 — placeholder / TODO sweep

Command: `rg -n "TODO|FIXME|XXX|stub|mock|fake|placeholder|lorem|tbd" apps/ --glob '!**/*.lock' --glob '!**/test/**' --glob '!**/integration_test/**'`.
There is **no** `TODO`, `FIXME`, `lorem` or `tbd` left in app code. All hits are domain words:

| Hit (file:line) | Decision | Reason |
|---|---|---|
| `apps/api/package-lock.json` (8 lines) | justify | Third-party package names/fields (lockfile). |
| `apps/api/scripts/data/common-passwords-10k.txt` (2 lines) | justify | Password deny-list data (entries happen to contain the words). |
| `apps/mobile/ios/Runner/Base.lproj/{Main,LaunchScreen}.storyboard:1` | justify | Xcode XML `placeholderIdentifier` attributes. |
| `apps/mobile/lib/core/l10n/app_en.arb` (150), `app_gu.arb` (20) | justify | ICU `"placeholders": {…}` metadata blocks only (checked: no other match). |
| `apps/api/src/modules/representatives/phone.ts:3`, `apps/api/src/lib/validation/index.ts:6`, `apps/api/scripts/staff-grant-admin.ts:17` | justify | `+91XXXXXXXXXX` / `+9179XXXXXXXX` format masks in docs and usage text (no real numbers). |
| `apps/api/src/config/index.ts:56-57`, `apps/api/.env.example:51`, `apps/api/.env.test.example:33` | justify | `FIREBASE_AUTH_MODE=fake` is the documented test-only verifier mode; `config` `superRefine` requires `google` when `APP_ENV=production` (TASK-13). |
| `apps/api/src/lib/firebase/fake.ts:29,53,67`, `apps/api/src/lib/firebase/index.ts:3,8,20`, `apps/api/src/lib/firebase/types.ts:3,14` | justify | The in-process Firebase fake used by Vitest (TASK-04 design); never selected in staging/production. |
| `apps/api/src/lib/storage/r2.ts:27` | justify | Doc comment: narrow client surface so tests inject a fake. |
| `apps/api/prisma/seed/seed-photo.ts:6` | justify | Dev seed writes a generated placeholder JPEG (seed only, not shipped data). |
| `apps/mobile/env/README.md:10` | justify | `saarthee.example` domain is founder-blocked (TASK-13 §5.6, Deferred — needs domain). |
| `apps/mobile/lib/features/services/presentation/ward_services_section.dart:17`, `home_services_section.dart:14`, `shell/my_ward_screen.dart:89,103,106`, `me/presentation/me_row.dart:11`, `report/report_routes.dart:12` | justify | History comments "replaces placeholder P-0n" — the placeholders are gone. |
| `apps/mobile/lib/core/widgets/states.dart:26` | justify | Debug-only owner line of the shared empty state. |
| `apps/mobile/lib/core/widgets/photos.dart:28,45,50` | justify | Image loading/error placeholder widget (a real UI state). |
| `apps/mobile/lib/features/report/presentation/photo_strip.dart:12` | justify | The empty "add photo" slot (real UI). |
| `apps/mobile/lib/features/issue_actions/application/escalation.dart:47`, `discovery/data/discovery_api.dart:95`, `ward/data/ward_api.dart:94`, `core/wards/ward_providers.dart:61`, `me/application/me_controller.dart:108` | justify | Doc comments on ports that tests replace with fakes. |
| `apps/mobile/lib/features/staff/shell/session_storage_store.dart:2` | justify | Conditional import of the non-web storage stub (`session_storage_backend_stub.dart`), standard Dart pattern. |

## Step 21 — colours, literals, console, AMC marks

| Sweep | Hit (file:line) | Decision | Reason |
|---|---|---|---|
| colours | 131 matches of `SaartheeColors.` (e.g. `core/widgets/cards.dart:44`) | justify | Regex false positive: `Colors\.` matches inside the Neem token class. A word-bounded rerun (`\bColors\.` / `Color\(0x`) outside `theme/` returns 0. |
| literals | `apps/mobile/lib/features/dev/gallery_screen.dart:64,86,315,327,345,348,403,438` | justify | Debug-only component gallery (`/dev`, not routed in release); developer labels. |
| literals | `apps/mobile/lib/features/staff/content/presentation/content_form.dart:154` | justify | `'${i + 1}. ${step}'` — numbering of user-entered steps; no words. |
| literals | `apps/mobile/lib/features/inbox/presentation/inbox_bell.dart:54` | justify | Badge cap `'9+'` (numeral, same in both locales). |
| literals | `apps/mobile/lib/features/staff/alerts/presentation/staff_alert_composer_screen.dart:149` | justify | `'$label: $error'` joins two localised strings with a colon. |
| literals | `apps/mobile/lib/features/staff/settings/election_mode_section.dart:182` | justify | `'${l10n.staffSettingsTo}: $date'` — localised label + formatted date. |
| literals | `apps/mobile/lib/core/widgets/rolling_count.dart:60,69` | justify | Interpolated integers (rolling Me-too count). |
| console | — | — | 0 hits in `apps/api/src` (pino logger only). |
| AMC marks | `apps/api/prisma/data/geo/SOURCES.md:3` | justify | The sentence states that *no* AMC logo is committed. |

## Step 21 — Neem design sweep (DS v2.2)

| Sweep | Hit (file:line) | Decision | Reason |
|---|---|---|---|
| `Icons.` outside theme | — | — | 0 (all icons via `SaartheeIcons`, Material Symbols Rounded). |
| `_outlined|Outlined\b` | `apps/mobile/lib/core/widgets/buttons.dart:156` | justify | Doc comment "Outlined secondary action" describes the button border, not an icon set. |
| `fontFamily: 'Noto` | — | — | 0 (Noto only in `fontFamilyFallback`). |
| superseded tokens | — | — | 0. |
| `sunrise` (review) | `features/discovery/presentation/widgets/chevron_refresh_indicator.dart:11` | justify | Comment: chevron is `primary`, never sunrise. |
| `sunrise` | `features/home/presentation/report_card_intro.dart:8,14,87` | justify | The one-time Report-card ring (report action, once per install). |
| `sunrise` | `features/issue_actions/presentation/motion/send_progress_button.dart:10` | justify | Comment: button is `primary`, never sunrise. |
| `sunrise` | `features/home/presentation/home_screen.dart:27` | justify | Comment naming the Report card (report action). |
| `sunrise` | `features/report/presentation/step_details.dart:18` | justify | Pinned "Submit report" (report action). |

## Step 21 — gu ARB parity

Script: parse both ARBs, compare non-`@` keys, flag gu values with no Gujarati script or with a ≥ 4-letter Latin word
outside `{placeholders}`. Result: **en 1191 = gu 1191, 0 missing, 0 extra** (after this branch: 1193 = 1193, the two
new `polish*` keys added to both with `"x-review": "pending"`). 52 gu values flagged, all justified:

| Hit (key) | Decision | Reason |
|---|---|---|
| `brandNameEn`, `repVerified`, `repNeutrality`, `relayConsentBody`, `scorecardMethodBody`, `configErrorBody` | justify | Brand/product names kept in Latin (Saarthee, Play) inside Gujarati sentences. |
| `languageNameEn`, `languageGlyphEn`, `languageSwitchToEnglish`, `onboardingLanguageTitleEn`, `accountLanguageEn`, `aboutIndependenceLineEn`, `staffAlertsFieldTitleEn`, `staffAlertsFieldBodyEn`, `staffCategoriesNameEn`, `staffSettingsNoteEn` | justify | Intentionally English: names the English language / English-content field, or shown to English readers. |
| `reportHandoffWhatsapp`, `linkCcrsWhatsapp`, `linkCcrsHelp`, `reportFlowMapAttribution`, `staffAlertsFromSachet` | justify | Proper nouns: WhatsApp, OpenStreetMap (licence attribution), NDMA SACHET. |
| `initiativesCancelRsvp`, `initiativesRsvpCancelled`, `initiativesNotOpen`, `initiativesRsvpError`, `staffContentNoRsvps` | justify | "RSVP" is the term used on the event cards in both languages. |
| `accountDeleteTypeLabel` | justify | The user must type the literal `DELETE` (matches the API confirmation). |
| `staffAlertsErrHttps`, `staffContentErrorHttps`, `staffContentFieldUrl`, `staffContentFieldSlug`, `staffContentFieldStart`, `staffContentFieldEnd`, `staffContentFieldActiveFrom`, `staffContentFieldActiveTo` | justify | Technical tokens (`https://`, `slug`, `YYYY-MM-DD HH:MM` input format) inside Gujarati labels. |
| `wardZone`, `repRoleLineArea`, `relayCounter`, `reportFlowCharCount`, `staffAlertsCounter`, `flagCounter`, `alertsValidityRange`, `initiativesTimeRange`, `moderationRowMeta`, `moderationFlagCount`, `discoveryMapPinLabel`, `discoveryMetaLine`, `reportHandoffCopyText` | justify | Placeholder-only / punctuation formats (or the copied handoff text's Google Maps URL). |
| `errorRateLimitedMinutes`, `componentMeTooCount`, `reportFlowPhotoCount`, `discoveryAgeDays` | justify | Gujarati ICU plurals; flagged only for the `plural`/`other` ICU keywords. |

Native Gujarati review of all `x-review: pending` strings stays **Deferred — needs native Gujarati reviewer** (TASK-14 §5.6).

## UI polish fixed on this branch (integrator emulator findings)

| Finding | Fix | Test |
|---|---|---|
| Issue card/detail subline repeated the ward (and category) already in the API title | `issueSubline()` drops parts the localised title contains; card shows "today", detail shows the age only | `test/discovery/subline_test.dart` |
| Home "All alerts" label 12 dp inside the gutter | start padding `gutter − s12` cancels the M3 text-button inset | `test/discovery/home_test.dart` ("All alerts" label sits on the gutter) |
| Hotspots showed raw coordinates | "N open issues in one spot" (`polishHotspotRow`); no locality in the payload and `/map` has no centre parameter, so no map link | `test/staff/ward_dashboard_test.dart` W-11-04 |
| Staff app bar "Saarthee s…" at phone width | < 600 dp: `polishStaffTitleShort` ("Staff"), icon-only Sign out with tooltip, role chip and ward switcher ellipsize instead of overflowing | `test/staff/staff_shell_test.dart` (360 dp short title; wide full title) |
