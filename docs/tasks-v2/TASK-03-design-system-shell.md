# TASK-03: Neem Design System, App Shell & Onboarding

| Field | Value |
|---|---|
| Task ID | TASK-03 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | None |
| Blocks | TASK-04, TASK-12 |
| Requirement IDs | REQ-F-004, REQ-F-005, REQ-F-006, REQ-N-001, REQ-N-002, REQ-N-003, REQ-N-004, REQ-N-005, REQ-N-006, REQ-N-012 |
| Primary Spec Refs | Spec §1, §2 (D1, D4, D11), §8; DS §1–§7, §9 |
| Last Updated | 2026-10-03 |

## 1. Objective

Give Saarthee its v2 look, feel and skeleton. Replace the v1 "indigo and marigold" tokens (and the superseded Civic Blue v2.0 draft) with the **Neem** semantic token set (DS §2: deep neem-green `primary` #14674A, `sunrise` #C24A1F for the report action only, leaf-tinted `background` #F3F6F1), bundle **Baloo Bhai 2** (headings and numbers) and **Mukta Vaani** (body) as subset fonts (DS §3), switch icons to Material Symbols **Rounded** (DS §4), and build the shared component library (DS §5) — including the green Home header band, the `sunrise` Report card and the toast — with a debug-only gallery and widget/golden tests. Add the **motion system** (DS §6): `SaartheeMotion` tokens, shared page/tab/sheet transitions, press feedback, skeleton shimmer, launch and onboarding motion, reusable motion widgets for later tasks, and reduced motion driven by the system setting and an in-app "Animations" switch. Replace the v1 single-stack router with a five-tab citizen shell (Home · Map · Report · Alerts · My Ward) whose tabs keep their own navigation state, and replace the v1 invite-code onboarding (retired by D11) with v2 onboarding: language first, one intro screen with the independence line, and home ward by GPS or picker. Make the whole app bilingual: a complete Gujarati ARB alongside English, an instant language switch, and no hard-coded strings. Later tasks fill the tab bodies; every placeholder this task leaves is listed in §5.4 so TASK-14 can confirm none remain.

**Design source:** the founder chose direction **B Neem** from the four directions in `docs/v2/design-options.html` and the Baloo Bhai 2 + Mukta Vaani pairing from the seven pairings in `docs/v2/font-options.html` on 2026-10-03. `docs/v2/design-system.md` v2.2 is the only normative source; the HTML files are visual reference for the gallery review (M-03-08).

## 2. Scope

### In Scope
- `lib/core/theme/`: Neem semantic colour tokens (light + dark) as a `ThemeExtension`, status/severity/category palettes, spacing/radius/elevation constants, `SaartheeMotion` tokens (`motion.dart`), Material Symbols Rounded icon map (`icons.dart`), `ThemeData` builders (`AppTheme.light()`, `AppTheme.dark()`), `ThemeMode` setting (system/light/dark).
- Fonts: Baloo Bhai 2 (600/700/800) and Mukta Vaani (400/500/600) from Google Fonts / Ek Type (OFL), bundled as subset TTFs with OFL licence files, subset script, `pubspec.yaml` font families; Noto Sans Gujarati / Noto Sans named only as `fontFamilyFallback`.
- Icons: Material Symbols Rounded (weight 400, 24 dp; filled variant for the selected nav tab and the Report "+") through one `SaartheeIcons` map; no `Icons.*` (Material Icons) in app code.
- Component library in `lib/core/widgets/` per DS §5 (list in §5.4) and a debug-only gallery route `/dev/gallery` with a Motion section.
- Motion system (REQ-N-012, DS §6) for the moments TASK-03 owns — app launch, onboarding, tab switch, push navigation, sheets, buttons and cards press, skeletons — plus reusable motion widgets (`Pressable`, `RiseIn`, `PopIn`, `StaggeredColumn`, `SeenOnce`, `MotionCheck`, `CountUp`, `RollingCount`), `StaffMotionScope` for the staff console, a haptics helper and reduced motion (system "Remove animations" + in-app "Animations" switch).
- Migration of every existing screen that stays (v1 admin console, About, global error) to the new tokens and components so the app compiles with no colour literals outside `lib/core/theme/`.
- New router: `StatefulShellRoute.indexedStack` with five branches; onboarding routes; `/me/settings` (language, theme, animations, home ward, about); `/about` rewritten for v2 independence copy.
- Onboarding v2: `/onboarding/language`, `/onboarding/intro`, `/onboarding/ward` (GPS → `GET /geo/locate`, picker → `GET /wards`), graceful degradation when the API is unavailable.
- Locale and home-ward state: `localeProvider`, `homeWardProvider`, both persisted on device; a `PreferenceSync` port that TASK-04 implements to persist language and home ward on the account.
- `app_gu.arb` complete for every key; English ARB cleaned: retired v1 keys deleted, kept keys migrated, new keys added; parity test and untranslated-messages check in CI.
- Retirement (D11) of v1 citizen constructs in the app: invite-code onboarding (`features/onboarding/*invite*`, `welcome_screen.dart`), v1 WhatsApp-token verify flow (`features/verify/`, verify deep links), the v1 six-step CCRS-first report screens and draft (`features/report/`), and their keys. `lib/core/capture/` is kept for TASK-05.
- Flutter tests: theme/contrast unit tests, motion token and literal-guard tests, component widget tests, motion widget tests that pump through the token durations, reduced-motion tests, golden tests for components in light, dark, `gu` and 2.0× text scale, shell and onboarding widget tests, accessibility guideline tests.

### Out of Scope
- Sign-in, profile, account sync of language/home ward, push permission and topic subscription — TASK-04 (implements `PreferenceSync`).
- Ward data, `GET /wards` and `GET /geo/locate` server side — TASK-02 (this task builds against the contract in §5.3).
- Real tab content: Home feed and Map (TASK-07), Report flow (TASK-05), Alerts (TASK-08), My Ward (TASK-09), services and drives (TASK-12).
- Catalogue moments owned by other tasks (DS §6): Home first-load stagger and Report-card first-launch pulse (TASK-07), report steps, photo fly-in, duplicate card and success screen (TASK-05), status chip cross-fade and timeline expand (TASK-06), feed → detail `Hero`, Me too, pull to refresh, map pins (TASK-07), alert banner and inbox (TASK-08), My Ward and scorecard (TASK-09), dashboards (TASK-11), RSVP (TASK-12), staff console fades (TASK-10). They reuse this task's tokens and widgets.
- Low-end-phone frame-budget evidence for every catalogue moment — TASK-14 (REQ-N-013). This task does a profile-mode pre-check of its own moments on the emulator only (M-03-10).
- Map pins and cluster rendering — TASK-07 (needs the map package; tokens for them are defined here).
- Staff console look and side navigation — TASK-10 (it reuses these tokens and components).
- Removing the v1 API endpoints for invite codes and verify tokens — API stays untouched in this task.
- Hindi / Noto Sans Devanagari — phase 3 (REQ-F-092 deferred).

## 3. Prerequisites

- Flutter SDK matching `apps/mobile/pubspec.yaml` (`sdk: ^3.13.1`); `flutter pub get` succeeds on the v1 tree.
- Python 3 with `fonttools` (`pip install fonttools brotli`) for the font instance and subset script (developer machine only; the subset TTFs are committed).
- Font sources with their `OFL.txt`: Baloo Bhai 2 (Google Fonts `ofl/baloobhai2`, upstream Ek Type `EkType/Baloo2`; variable `wght` font) and Mukta Vaani (Google Fonts `ofl/muktavaani`, upstream Ek Type; static Regular/Medium/SemiBold). Verify paths and licence text at download time.
- Package candidates — verify on pub.dev (null safety, Dart 3, maintenance, licence) and pin exact versions: `animations` (shared axis, fade-through, container transform), `flutter_animate` (stagger, rise, pop), `material_symbols_icons` (Material Symbols Rounded `IconData` with fill axis).
- Android emulator (API 34+) with a location set inside Ahmedabad (e.g. 23.0225, 72.5714) for M-03 checks; `adb` for screen recordings (`adb shell screenrecord`).
- Optional: a running API from TASK-02 to exercise the live ward path; without it the degrade path is tested.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| None | Mobile-only foundation; runs in parallel with TASK-01. Ward endpoints are consumed through a contract and a degrade path (§5.6). |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-004 | Onboarding: language first (ગુજરાતી / English), one intro screen with independence notice, set home ward by GPS or picker | Spec §8, D4 |
| REQ-F-005 | Citizen app shell with five tabs (Home, Map, Report, Alerts, My Ward), state kept per tab | Spec §8 |
| REQ-F-006 | Language switch in settings changes the whole app instantly; preference stored on device and on the account | Spec §8, D4 |
| REQ-N-001 | Design tokens per DS §2 replace v1 tokens; no colour literal outside the theme; semantic token names | DS §2 |
| REQ-N-002 | Typography per DS §3 with bundled Gujarati + Latin fonts (subset), Indic line heights, scale to 200% without clipping | DS §3 |
| REQ-N-003 | Component library per DS §5 (app bar, bottom nav, buttons, inputs, chips, list rows, cards, status timeline, banners, empty/loading/error/offline states) with a debug-only gallery | DS §5 |
| REQ-N-004 | Accessibility: 48 dp targets, labels on all controls, contrast AA, icon + text for every status, TalkBack order | DS §7 |
| REQ-N-005 | Complete Gujarati and English ARB translations for every string; no hard-coded strings | Spec D4 |
| REQ-N-006 | Dark theme from the same tokens | DS §2 |
| REQ-N-012 | Motion system per DS §6: `SaartheeMotion` tokens used by every animation (no `Duration(` literals in features, enforced by a test); shared transitions, press scale, skeleton shimmer, nav-pill slide, launch and onboarding motion; system "Remove animations" and an in-app Animations switch reduce all motion to instant/≤ 100 ms cross-fades | DS §6 |

### 5.2 Data Contracts

No database changes. Device storage (`shared_preferences`, keys prefixed `v2.`):

| Key | Type | Meaning |
|---|---|---|
| `installId` | String (UUID v4) | Kept from v1 unchanged (TASK-04 uses it for `POST /devices`) |
| `v2.languageCode` | `gu` \| `en` | Chosen in onboarding or settings; absent → device locale if `gu`, else `en` |
| `v2.themeMode` | `system` \| `light` \| `dark` | Default `system` |
| `v2.animationsEnabled` | bool | In-app "Animations" switch; default `true`. Effective motion is reduced when this is `false` **or** `MediaQuery.disableAnimations` is true |
| `v2.onboardingDone` | bool | Set after the ward step (also when the ward is skipped) |
| `v2.homeWard` | JSON `{id, number, nameEn, nameGu, zoneCode, zoneNameEn, zoneNameGu}` | Absent when skipped |
| `v2.wardsCache` | JSON `{fetchedAt, items:[…]}` | Last successful `GET /wards`, used offline by the picker |
| `inviteCode`, `groupLabel`, `onboardingDone` | — | v1 keys: deleted on first v2 launch (migration in `AppSettingsNotifier.build`) |

Dart models (`lib/core/wards/ward.dart`): `Ward {String id; int number; String nameEn; String nameGu; Zone zone}`, `Zone {String id; String code; String nameEn; String nameGu}`, `WardLocateResult {Ward ward; bool confirm}`. `Ward.displayName(locale)` returns "Ward 12 · Paldi" / "વોર્ડ 12 · પાલડી".

`PreferenceSync` port (`lib/core/settings/preference_sync.dart`):
```dart
abstract interface class PreferenceSync {
  Future<void> languageChanged(String languageCode);
  Future<void> homeWardChanged(Ward? ward);
}
```
Default provider binds `NoopPreferenceSync`. TASK-04 overrides it to call `PATCH /me` when signed in and to re-subscribe FCM topics. The Animations switch is device-only (not synced).

Token model (`lib/core/theme/tokens.dart`, replaces v1 file):
- `SaartheeColors extends ThemeExtension<SaartheeColors>` with fields named exactly as DS §2: `primary` #14674A, `onPrimary` #FFFFFF, `primaryDark` #0E4A35, `primaryContainer` #E1F0E7, `onPrimaryContainer` #0E4A35, `onPrimarySubtle` #BFE0CD, `sunrise` #C24A1F, `onSunrise` #FFFFFF, `sunrisePressed` #A33C17, `background` #F3F6F1, `surface` #FFFFFF, `surfaceAlt` #E8EFEA, `border` #DCE5DE, `borderStrong` #86978C, `textPrimary` #17251E, `textSecondary` #4E5E55, `textDisabled` #8A978F, `success`/`successTint` #1A7340/#E6F4EC, `warning`/`warningTint` #9A5B00/#FFF4E0, `error`/`errorTint` #B3261E/#FCEBEA, `info`/`infoTint` #1F5FAE/#E5EEFA, `focusRing` #FFDD00, `focusInner` #17251E, `shadow` #17251E; `static const light`, `static const dark`; `lerp` implemented. No `secondary`/`secondaryContainer` (Civic Blue v2.0) fields.
- `IssueStatusStyle` enum-keyed map for `reported, acknowledged, inProgress, markedFixed, verified, reopened, rejected` → `{solid, tint, icon, l10nKey}` (DS §2 status table, Rounded icons). `sent` and `acknowledged` share one style.
- `AlertSeverityStyle` for `info, advisory, warning, critical` → `{solid, tint, icon, l10nKey}` (DS §2 severity line).
- `CategoryStyle` map keyed by the 14 slugs → `{color, icon}` (DS §2) with derived `tint` = colour at 12% over `surface`; `fallback = other`. Glyph colours that fail 4.5:1 on their tint are darkened and the final hex recorded in T-03-02.
- `AppSpacing` (scale 4/8/12/14/16/20/24/32/40, `gutter 16`, `cardGap 14`, `sectionTitleTop 24`, `sectionTitleBottom 12`, `maxContent 600`, `staffMaxContent 1200`, `touchTarget 48`, `buttonHeight 50`, `pinnedButtonHeight 56`, `reportCardMinHeight 56`, `categoryBadge 40`), `AppRadii` (`control 14` buttons/inputs/stat tiles/badges/thumbnails, `card 18` cards/tiles/alert cards/toasts, `sheet 24` sheets + dialog top corners, `pill` = `StadiumBorder`; brand mark 28% of size), `AppElevation` (card = 1 px `border` + 1 dp shadow `shadow` at 5%; Report card glow `sunrise` 0 10 22 −10 at 70%; sheet/dialog/toast 3).
- Dark palette per DS §2 dark line: `background` #131C18, `surface` #1A2520, `border` #2A3830, `textPrimary` #E6EFE9, `textSecondary` #A9B9AF, `primary` #7BD3A6 / `onPrimary` #0F1A15, `sunrise` #FF9E78 / `onSunrise` #1B120D; remaining dark values derived and recorded in T-03-02. Dark status/severity use the tint colour as text on `surface` and the solid colour for dots/bars.

Motion model (`lib/core/theme/motion.dart`, DS §6):
- `SaartheeMotion` constants exactly as DS §6: `instant` 100 ms `Curves.easeOut`; `short` 180 ms `Cubic(0.2,0,0,1)`; `medium` 280 ms `Cubic(0.2,0,0,1)`; `springIn` 380 ms `Cubic(0.34,1.35,0.64,1)`; `long` 450 ms `Cubic(0.05,0.7,0.1,1)`; `stagger` 60 ms (lists), `tileStagger` 35 ms (tile grids, e.g. report step 1), `staggerMaxItems 6`; `mapPinStagger` 30 ms and `mapPinMaxAnimated` 20 (TASK-07 map pins); `riseOffset 14` dp; `drawCheck` 450 ms with `drawCheckDelay` 150 ms; `countUp` 600 ms `Curves.easeOutCubic`; `pressScale 0.97`; `shimmerPeriod` 1.2 s; `launchMarkScaleFrom 0.92`; `selectSpringScale 1.02`. Each token is a `MotionSpec {Duration duration; Curve curve}`.
- `reducedMotionProvider` (Riverpod, `lib/core/settings/motion_preference.dart`) = `systemDisableAnimationsProvider` (kept in sync by `MotionScope` from `MediaQuery.disableAnimationsOf(context)`) **or** `!animationsEnabled` (`motionPreferenceProvider`). It is the single source of truth for reduced motion.
- `SaartheeMotionScheme` resolved per context: `SaartheeMotion.of(context)` returns the full scheme, or the **reduced** scheme when `reducedMotionProvider` is true. Reduced scheme: transforms, staggers, springs, draws and counts → `Duration.zero` (end state on first frame); page, tab and sheet transitions and content swaps → a cross-fade of `instant` (100 ms). `scheme.isReduced` exposed for widgets.
- `motionPreferenceProvider` (Riverpod) reads/writes `v2.animationsEnabled`; a `MotionScope` widget above `MaterialApp.router` publishes the system flag into `systemDisableAnimationsProvider` and exposes the resolved scheme to descendants.
- `SaartheeHaptics` (`lib/core/motion/haptics.dart`): injectable class with `light()`, `selection()`, `success()`, provided by `saartheeHapticsProvider`; tests override it with `FakeSaartheeHaptics` (`test/helpers/fake_haptics.dart`) that records calls in order.

### 5.3 API Contracts

This task calls two TASK-02 endpoints (not built here). Shapes assumed (ASSUMPTION in §5.6); the mapper in `lib/core/wards/wards_repository.dart` is the only place to adapt if TASK-02 differs.

| Method | Path | Auth | Request | Expected response | Errors handled |
|---|---|---|---|---|---|
| GET | `/api/v1/wards` | None | — | 200 `{items:[{id, number, nameEn, nameGu, zone:{id, code, nameEn, nameGu}}]}` (48 items) | network/timeout, 5xx, 429, 404 (endpoint not deployed yet) → degrade |
| GET | `/api/v1/geo/locate?lat=&lng=` | None | lat/lng 6 dp | 200 `{ward:{…as above}, zone:{…}, confirm:boolean}` | 404 / network → "Choose from list"; 422 (outside city) → message + list |

Client rules: 8 s timeout; one automatic retry for idempotent GETs on network error; `Accept-Language` header set from `localeProvider`; results cached as `v2.wardsCache` (no expiry in this task; TASK-02 may add one).

### 5.4 UI Surfaces & States

Shell routes (`lib/router/app_router.dart`, `lib/router/shell_routes.dart`):

| Branch | Route | Tab label (en / gu key) | Icon (Rounded; filled when selected) | Body in this task |
|---|---|---|---|---|
| 0 | `/` | Home / `navHome` | `home` | `HomeHeader` band (ward line, greeting, language + bell buttons, `ReportCard`) + placeholders P-01…P-03 |
| 1 | `/map` | Map / `navMap` | `map` | Placeholder P-04 |
| 2 | `/report` | Report / `navReport` | `add_circle` (filled always, glyph in `sunrise`) | Placeholder P-05 |
| 3 | `/alerts` | Alerts / `navAlerts` | `notifications` | Placeholder P-06 |
| 4 | `/ward` | My Ward / `navMyWard` | `location_city` | Ward header + rows "Settings" (`/me/settings`), "About Saarthee" (`/about`) + placeholders P-07…P-09 |

Placeholder register (each is a `PlaceholderSection`/`PlaceholderScreen` widget with a `placeholderId` and `ownerTask`; TASK-14 checks `grep -rn "PlaceholderSection\|PlaceholderScreen" apps/mobile/lib/features` returns nothing):

| ID | Location | Copy shown (en) | Replaced by |
|---|---|---|---|
| P-01 | Home: nearby issues section | "Issues near you will appear here." | TASK-07 |
| P-02 | Home: alerts strip | "Alerts for your ward will appear here." | TASK-08 |
| P-03 | Home: upcoming drives + service shortcuts | "Drives and services are coming soon." | TASK-12 |
| P-04 | Map tab | "The issues map is coming soon." | TASK-07 |
| P-05 | Report tab | "Reporting is being rebuilt. It will be back in the next update." | TASK-05 |
| P-06 | Alerts tab | "Ward alerts are coming soon." | TASK-08 |
| P-07 | My Ward: representatives | "Your corporators, MLA and MP will appear here." | TASK-09 |
| P-08 | My Ward: services and drives for the ward | "Services and drives for your ward are coming soon." | TASK-12 |
| P-09 | My Ward: profile/sign-in row | "Your profile is coming soon." | TASK-04 |

Other routes:

| Route | Content | States |
|---|---|---|
| Launch | Native splash in `primary` with the mark; first Flutter frame shows `BrandMark` that scales 0.92 → 1 and fades in over `medium`, then the first screen (onboarding or Home) cross-fades in. Nothing loops | Reduced motion: mark shown at full size, first screen appears with a 100 ms fade |
| `/onboarding/language` | Title "Choose your language" + "ભાષા પસંદ કરો" (both always, each in its own script); two 72 dp tiles "ગુજરાતી" and "English" (radius 18); tile matching device locale pre-highlighted (`primaryContainer` fill, 2 px `primary` outline); primary "Continue" / "આગળ વધો" in the selected language | Selection changes locale immediately (whole screen re-renders); selected tile springs to 1.02 and back (`springIn`) with a selection haptic |
| `/onboarding/intro` | `BrandMark` + `Wordmark`; tagline "Report it. Track it. See it fixed."; three rows with Rounded icons: "Report any civic problem with a photo." / "Follow it until neighbours confirm the fix." / "Get alerts and reach your corporators."; independence line in an info banner: "Independent citizen app. Not run by or linked to AMC."; primary "Continue" | Back returns to language (shared-axis X reversed) |
| `/onboarding/ward` | Title "Set your home ward"; helper "We use it to show issues, alerts and representatives near you. You can change it later."; primary "Use my location"; secondary "Choose from list"; tertiary "Skip for now" | Locating: in-button progress, "Finding your ward…"; result card "You're in Ward 12 · Paldi (West zone). Is this your home ward?" → "Yes, continue" / "Choose another"; `confirm:true` → "You seem to be just outside Ward 12 · Paldi. Is this right?"; permission denied → "Location is off. You can choose your ward from the list instead." + "Open settings"; outside city (422) → "You seem to be outside Ahmedabad. Choose your ward from the list."; API unavailable → "We couldn't load wards right now. Try again, or skip and set it later." + "Try again" + "Skip for now" |
| Ward picker (full-screen sheet, radius 24, slides up with `springIn`; also used from settings) | Search field "Search ward name or number"; list grouped by zone headers (7); rows "12 · Paldi" with zone; selecting returns the ward | Loading: skeleton rows with shimmer, cross-fading to the list; offline with cache: list from cache + offline banner; offline without cache / error: error state "We couldn't load wards right now." + "Try again"; no search match: "No ward matches “{query}”." |
| `/me/settings` | Sections: Language (radio ગુજરાતી / English); Appearance (System / Light / Dark); **Animations** switch ("Animations" / "એનિમેશન", helper "Turn off to reduce movement on screen."); Home ward (current + "Change" → picker); About link | Change applies instantly; language and home ward sync via `PreferenceSync`; when the system "Remove animations" is on, the switch shows off and disabled with "Off because Remove animations is on in your phone settings." |
| `/about` | Wordmark, version, independence line (en + gu always), "Saarthee is an independent citizen project. It is not run by, funded by or linked to the Amdavad Municipal Corporation.", name origin line (neem tree, DS §1), grievance contact placeholder line from config `GRIEVANCE_EMAIL` | — |
| `/dev/gallery` (debug builds only) | Every component in every state, with toggles for theme, locale, text scale 1.0/1.3/2.0 and reduced motion; a **Motion** section with a "Replay" button per TASK-03 motion and per reusable motion widget | Not registered when `kReleaseMode` or `kProfileMode` |

Components (`lib/core/widgets/`, exported from `widgets.dart`):

| Widget | Key behaviour |
|---|---|
| `HomeHeader` | `primary` band overlapping the page: ward line (`onPrimarySubtle`, "Ward 12 · Paldi" or "Set your ward" → picker), greeting (displaySmall, white, "Namaste" / "નમસ્તે"), `LanguageToggle` and bell as 36 dp circles (white 14%) inside 48 dp targets, `ReportCard` below |
| `ReportCard` | `sunrise` fill (`sunrisePressed` when pressed), ≥ 56 dp, radius 14, white "+" (filled) in a 32 dp circle, title "Report a problem" + hint "Pothole, garbage, water, anything", trailing arrow, `sunrise` glow; springs in with `springIn`; tap → `goBranch(2)`. Only report actions may use `sunrise`, at most once per screen |
| `SaartheeAppBar` | Non-Home screens: white surface, left title (headlineSmall), optional subtitle (ward name), back arrow, actions: `LanguageToggle` ("અ" / "A", label "Switch to English" / "ગુજરાતીમાં બદલો"), optional bell slot with badge; 1 px bottom border once scrolled |
| `SaartheeNavigationBar` | M3 `NavigationBar` (semantics, labels always shown) with its own indicator replaced by an animated `primaryContainer` pill that slides and stretches between destinations (`short`, transform only); filled Rounded icon for the selected tab; Report icon always filled `add_circle` in `sunrise` |
| `PrimaryButton` / `SecondaryButton` / `TertiaryButton` | Filled `primary` 50 dp (pinned variant 56 dp), radius 14, sentence case; `SubmitReportButton` variant in `sunrise`; secondary = 1.5 px `borderStrong` outline with `primary` text; `isLoading` → in-button progress + disabled + semantics "Working"; wrapped in `Pressable` (scale 0.97 + light haptic for primary) |
| `LabeledTextField` | Label above, "(optional)" suffix, helper below, error row with `error` icon, 1 px `borderStrong`, radius 14, 2 px `primary` focus |
| `ErrorSummary` | Top-of-form box titled "There is a problem", list of links that move focus to fields; requests focus when shown |
| `AppFilterChip`, `StatusChip(IssueStatus)`, `SeverityChip(AlertSeverity)` | Pills. Status/severity = tint background + solid text + Rounded icon + word |
| `CategoryBadge(slug, size: 40)` | Glyph in the category colour on a 12% tint of it, in a 40 dp rounded square (radius 14); semantics = category name |
| `StatTile` | `surfaceAlt`, radius 14, number (numeric style, `CountUp` capable) + label (bodySmall) |
| `ListRow` | ≥ 56 dp (72 dp two-line), leading slot (40 dp category badge), trailing chip or chevron, whole row tappable |
| `IssueCard` | Radius 18, 1 px border + soft shadow; 4:3 thumbnail, badge, title (titleMedium, Mukta Vaani), "Ward · age", status chip, Me-too count, overdue tag (data passed in; no API); wrapped in `Pressable` |
| `StatusTimeline` | Vertical stepper, 14 dp dots in the status colour, actor + date, future steps hollow grey, slot for after-photo and verify buttons |
| `AlertCard` | Radius 18, tint of the severity, severity icon + word, title, area, validity, source line "Source: {name} · Relayed by Saarthee"; no side bar; critical = solid banner, white text |
| `NoticeBanner` variants `offline` (slate), `electionMode`, `independence`, `info` | Offline copy: "You're offline. Your report is saved and will send automatically." |
| `SaartheeToast` (`showSaartheeToast(context, message, kind)`) | `primaryDark` background, white text, radius 18, elevation 3, leading `MotionCheck` (success) or Rounded icon (info/error); slides up with `springIn`, holds `SaartheeMotion.toastHold` (4 s), announced via `SemanticsService.announce` |
| `EmptyState`, `SkeletonList`, `ErrorState`, `OfflineState` | Empty = 56 dp icon on a `primaryContainer` circle + one line + one action; error = cause in plain words + "Try again"; skeletons (`surfaceAlt`) with a low-contrast shimmer, never full-screen spinners; skeleton → content cross-fade (`medium`) |
| `StepHeader` | "Step {n} of {total}" + hint of the next step + progress bar that animates to its new value (`medium`, clipped) + Back; semantics announces the step |
| `RepresentativeRow` | Initials avatar, name (gu/en), role, ward, party as plain text, "Message" button (callback only) |
| `PhotoThumb` | 4:3, radius 14, no border, required semantic label, optional "Faces and number plates blurred" caption |
| `BrandMark`, `Wordmark` | Mark per DS §1 (rounded square, radius 28% of size, `primary`, white upward-right route chevron ending in a `sunrise` dot) drawn with `CustomPainter`; wordmark in Baloo Bhai 2 Bold, swaps order by locale (never stacked) |
| `PlaceholderSection`, `PlaceholderScreen` | Temporary; `EmptyState` with `construction` icon and owner-task debug label (debug builds only) |

Motion widgets and helpers (`lib/core/motion/`, exported from `motion_widgets.dart`; all read `SaartheeMotion.of(context)` and collapse to end state when reduced):

| Widget / helper | Behaviour | Reused by |
|---|---|---|
| `saartheePage(...)` / `SaartheeTransitions` | go_router `CustomTransitionPage` with `SharedAxisTransition` (horizontal, `medium`) for push/pop; `FadeThroughTransition` (`medium`) for tab switches via the shell's `navigatorContainerBuilder` (branch state kept); `showSaartheeSheet` with `springIn` slide-up | All tasks with routes or sheets |
| `Pressable` | Scale to 0.97 on press down (`instant`), back on release/cancel; optional `haptic: light` for primary actions; never blocks the tap | Buttons, cards, tiles everywhere |
| `RiseIn` | Fade + 14 dp translate-Y with `springIn`, optional delay | Content entering |
| `PopIn` | Scale 0.88 → 1 with `springIn`, stagger `SaartheeMotion.tileStagger` (35 ms) by default | TASK-05 category tiles |
| `StaggeredColumn` / `StaggeredSliverList` | Children `RiseIn` with 60 ms `stagger`, max 6 animated (items 7+ appear with item 6); takes a `seenOnceKey` and uses `SeenOnce` so a tab does not replay on return | TASK-07 Home, detail; TASK-09 My Ward |
| `MotionCheck` | `CustomPainter` check drawn over `drawCheck` (450 ms) starting 150 ms after build; size and colour params; semantics label passed in | Toasts; TASK-05 success; TASK-06 verify; TASK-09 message sent |
| `CountUp` | Integer count from previous (or 0 on first sight) to value over `countUp`; integers only; does not replay on rebuild with the same value; semantics always the final value | `StatTile`; TASK-09 scorecard; TASK-11 dashboard |
| `SeenOnce` | Runs its child's animation only on the first view of a given key in this app session (in-memory set behind `seenOnceProvider`); later views and rebuilds show the end state | TASK-07 Home first load, Report-card ring; TASK-09/TASK-11 bars and count-ups "when first seen" |
| `RollingCount` (`lib/core/widgets/rolling_count.dart`) | Digit rolls to the next value (`short`), for badges and small counters; semantics = final value | TASK-07 Me too; TASK-08 badge; TASK-12 attendees |
| `StaffMotionScope` | Wraps the staff console: forces `short` fades only (no staggers, springs, shared axis or rise) and disables `Pressable` scale inside it (DS §6 staff row) | TASK-10, TASK-11 |
| `SaartheeHaptics` via `saartheeHapticsProvider` | `light()` → `HapticFeedback.lightImpact`, `selection()` → `selectionClick`, `success()` → `mediumImpact`; follows the system haptics setting, independent of the Animations switch; `FakeSaartheeHaptics` records calls for tests | Every task (TASK-05/06 assert calls with the fake) |
| `reducedMotionProvider` | Combined reduced-motion flag (system `MediaQuery.disableAnimations` or in-app switch off); widgets and feature code read it instead of `MediaQuery` directly | Every task |

### 5.5 Permissions & Roles

| Action | Visitor (no account) | Signed-in citizen (TASK-04) | Notes |
|---|---|---|---|
| Onboarding, all five tabs, settings, about | ✅ | ✅ | D6: browse without account |
| Change language / theme / animations / home ward | ✅ (device) | ✅ (device; language + home ward also on account via `PreferenceSync`) | Animations is device-only |
| `/dev/gallery` | Debug builds only | Debug builds only | Route absent in profile/release |
| v1 `/admin/*` console | Unchanged (admin login) | Unchanged | Restyled only; TASK-10 replaces |

Device permission: location (when-in-use) requested only after the citizen taps "Use my location", with rationale "Saarthee uses your location once to find your ward. It is not stored."

### 5.6 Assumptions

- ASSUMPTION: `GET /wards` and `GET /geo/locate` return the shapes in §5.3 — TASK-02 is not written yet and TASK-03 must not depend on it — if TASK-02 differs, change only `WardsRepository` mapping and its fixture `test/fixtures/wards.json`.
- ASSUMPTION: No bundled ward list. When the API is unavailable and nothing is cached, the citizen can skip; Home and My Ward then show "Set your ward" — a bundled list would drift from TASK-02's boundary-versioned data.
- ASSUMPTION: The Report tab is a placeholder between TASK-03 and TASK-05 and the v1 six-step CCRS-first report flow is deleted now — D11 retires the v1 pilot constructs and Spec §8 replaces the flow; keeping it would force translating ~55 keys that TASK-05 deletes. The dev build cannot report in that window (milestone V2-M2).
- ASSUMPTION: The v1 admin console (`/admin/*`) stays, restyled to the new tokens, and its `admin*` keys are kept and translated to Gujarati — v1 admin email login stays (Spec §7) and REQ-N-005 says every string; TASK-10 may later delete keys it no longer uses.
- ASSUMPTION: Key retention rule — after the retired screens are deleted, a key is kept only if referenced in `lib/` (checked by `tool/l10n/unused_keys.dart`); expected outcome: ~105 retired keys deleted (`report*`, `verify*`, `invite*`, `welcome*`, v1 `home*`, v1 `status*` words), ~280 kept (`admin*`, `common*`, `error*`, `photo*`, `about*`, `global*`, `appTitle`), plus ~180 new v2 keys.
- ASSUMPTION: The account half of REQ-F-006 is delivered through the `PreferenceSync` port; this task verifies the port is called (T-03-14) and TASK-04 verifies `PATCH /me` is sent — the account does not exist before TASK-04.
- ASSUMPTION: Fonts are subset to Basic Latin, Latin-1 Supplement, General Punctuation, ₹ (U+20B9), Gujarati block U+0A80–U+0AFF, danda U+0964–U+0965, ZWJ/ZWNJ, with all OpenType layout features kept — Gujarati conjuncts need GSUB/GPOS; Devanagari is not bundled (phase 3).
- ASSUMPTION: Baloo Bhai 2 ships as a variable `wght` font; static 600/700/800 instances are cut with `fonttools varLib.instancer` before subsetting, because Flutter's `FontWeight` mapping to a variable font's axis is unreliable on older Android — if a static release is available upstream, use it instead.
- ASSUMPTION: Noto Sans Gujarati / Noto Sans are **not** bundled; they are named in `fontFamilyFallback` and resolve to the Android system Noto fonts for any glyph outside the subset — DS §3 lists Noto only as fallback and bundling it would break the ≤ 1.2 MB font budget.
- ASSUMPTION: The numeric role asks for tabular figures; if Baloo Bhai 2 has no `tnum` feature (checked in T-03-04), `CountUp`/`StatTile` lay digits out in fixed-width boxes instead — DS §3 requires steady numbers, not a specific mechanism.
- ASSUMPTION: Material Symbols Rounded comes from the `material_symbols_icons` package (const `IconData`, so release tree-shaking keeps only used glyphs), accessed only through `SaartheeIcons` — if the package fails the pub.dev check, bundle a subset of the official Material Symbols Rounded variable font instead.
- ASSUMPTION: The `Duration(` guard (DS §6) covers `lib/features/**`; non-motion durations (network timeouts, search debounce, retry back-off) live as named constants in `lib/core/config/timings.dart` (`AppTimings`), and toast hold time is `SaartheeMotion.toastHold` — so the guard needs no allow-list beyond `lib/features/dev/`.
- ASSUMPTION: The nav pill "slides and stretches" (DS §6) is drawn by an overlay behind a standard M3 `NavigationBar` with its own indicator made transparent — M3's indicator cannot move between destinations, and keeping `NavigationBar` keeps its semantics and 48 dp targets.
- ASSUMPTION: When the system "Remove animations" is on, the in-app switch is shown off and disabled (system wins); the stored `v2.animationsEnabled` value is kept and applies again when the system setting is turned off — DS §6 says either source reduces motion.
- ASSUMPTION: Golden tests run only on the CI image (Linux) and are tagged `golden`; developers on macOS update them with `--update-goldens` inside the same container — goldens differ across platforms. Goldens capture settled end states (and `MotionCheck` at fixed progress values), never mid-transition frames.
- ASSUMPTION: Gujarati copy (including the greeting "નમસ્તે", "Report a problem" and the Animations helper) is drafted by the implementer and marked `"x-review": "pending"` in `@` metadata for the native editor review (Open Question #5) — no Gujarati string blocks this task.

## 6. Implementation Steps

1. **Baseline and test setup.** Run `flutter analyze` and record the v1 baseline. Use plain `matchesGoldenFile` (no extra golden package); add `test/flutter_test_config.dart` that loads the bundled Baloo Bhai 2, Mukta Vaani and Material Symbols Rounded fonts with `FontLoader` so goldens render real glyphs. Add `test/helpers/motion.dart` (pumps a widget with `reducedMotionProvider` overridden true/false) and `test/helpers/fake_haptics.dart` (`FakeSaartheeHaptics`, records `light`/`selection`/`success` calls) for this and later tasks.
2. **Dependencies.** Check `animations`, `flutter_animate` and `material_symbols_icons` on pub.dev (latest stable, Dart 3, licence) and pin exact versions in `pubspec.yaml`; record the versions in §13.
3. **Fonts.** Add `apps/mobile/tool/fonts/subset_fonts.sh`: instance Baloo Bhai 2 at `wght=600/700/800` (`fonttools varLib.instancer`), then `pyftsubset` both families with the unicode ranges in §5.6, `--layout-features='*'`, output `assets/fonts/BalooBhai2-{SemiBold,Bold,ExtraBold}.ttf` and `MuktaVaani-{Regular,Medium,SemiBold}.ttf`; commit TTFs + `assets/fonts/BalooBhai2-OFL.txt`, `MuktaVaani-OFL.txt`; declare families `BalooBhai2` (600/700/800) and `MuktaVaani` (400/500/600) in `pubspec.yaml`; register both OFL licences (and the Material Symbols Apache 2.0 licence if the package does not) with `LicenseRegistry` in `main.dart`. Delete any v1/Noto font assets.
4. **Tokens.** Rewrite `lib/core/theme/tokens.dart` per §5.2 (Neem light + dark, status, severity, category with tints, spacing, radii, elevation). Delete v1 names (`ink`, `indigo`, `marigold`, …) and any Civic Blue v2.0 names (`secondary*`).
5. **Icons.** `lib/core/theme/icons.dart`: `SaartheeIcons` mapping every icon the app uses (nav, status, severity, category, actions) to Material Symbols Rounded, weight 400; `filled` variants for selected nav and Report "+". Replace every `Icons.*` use.
6. **Typography.** `lib/core/theme/typography.dart`: `TextTheme` with the DS §3 roles — Baloo Bhai 2 for displaySmall 28/700/36, headlineSmall 24/700/32, titleLarge 19/600/26, `numeric` 20/700/24 (tabular); Mukta Vaani for titleMedium 16/600/22, bodyLarge 16/400/24, bodyMedium 14/400/21, labelLarge 15.5/600/20, labelMedium 12/600/16, bodySmall 12/400/17 (`height = lineHeight / size`); `fontFamilyFallback: ['NotoSansGujarati', 'NotoSans']`; no letter-spacing; minimum 12 sp and "Baloo never below 16 sp" enforced by a test.
7. **Motion tokens.** `lib/core/theme/motion.dart` per §5.2: `SaartheeMotion`, `MotionSpec`, full and reduced `SaartheeMotionScheme`, `SaartheeMotion.of(context)`, including `stagger` 60 ms, `tileStagger` 35 ms, `staggerMaxItems` 6, `mapPinStagger` 30 ms and `mapPinMaxAnimated` 20 (the name is `SaartheeMotion`; no `AppMotion`); `lib/core/settings/motion_preference.dart` (`motionPreferenceProvider` for `v2.animationsEnabled`, `systemDisableAnimationsProvider`, `reducedMotionProvider` combining both); `MotionScope` above `MaterialApp.router`. Add `lib/core/config/timings.dart` (`AppTimings`) for non-motion durations.
8. **ThemeData.** Rewrite `app_theme.dart`: `AppTheme.light()` / `AppTheme.dark()` from the tokens — `ColorScheme` mapping (primary, onPrimary white, primaryContainer, surface, error…), `scaffoldBackgroundColor: background`, component themes (FilledButton 50 dp radius 14, OutlinedButton 1.5 px `borderStrong`, TextButton, InputDecoration radius 14, Chip as pill, NavigationBar with transparent indicator, AppBar white with scroll border, Card radius 18 with 1 px border + 1 dp shadow, BottomSheet radius 24, Dialog top radius 24, SnackBar → `SaartheeToast` style), `visualDensity: standard`, `materialTapTargetSize: padded`, focus colour `focusRing`. Add `themeModeProvider` persisted as `v2.themeMode`.
9. **Contrast tests first.** `test/theme/contrast_test.dart` computes WCAG ratios for every text/background pair in light and dark (text ≥ 4.5, large text and non-text UI ≥ 3.0) — including `onPrimarySubtle` on `primary`, white on `sunrise`, `textSecondary` on `background`, and each category glyph on its 12% tint — and fails with the pair name. Darken any failing category glyph or dark tint and record the final hex values in the test.
10. **No-literal guard.** `test/theme/no_color_literals_test.dart` scans `lib/**.dart` except `lib/core/theme/` for `Color(0x`, `Colors.` (except `Colors.transparent`), `fontSize:` and `Icons.` literals; fails listing file:line.
11. **Motion literal guard.** `test/theme/no_motion_literals_test.dart` scans `lib/features/**` (except `lib/features/dev/`) for `Duration(`, `Cubic(` and `Curves.`; fails listing file:line with "use SaartheeMotion / AppTimings".
12. **Components.** Build the §5.4 widgets in `lib/core/widgets/` (replace v1 `buttons.dart`, `errors.dart`, `notices.dart`, `offline_banner.dart`, `status_chip.dart`, `step_scaffold.dart`, `photos.dart`, `choice_card.dart` — keep file names where the API stays, delete the rest; add `home_header.dart`, `report_card.dart`, `toast.dart`, `stat_tile.dart`, `category_badge.dart`, `rolling_count.dart` (`RollingCount`)). Every interactive widget sets `Semantics(label:…)`/`tooltip` and ≥ 48 dp constraints. Animate only transform, opacity and colour (the `StepHeader` progress is painted, not laid out).
13. **Motion widgets.** Build `lib/core/motion/`: `transitions.dart` (`saartheePage`, `FadeThroughTransition` shell container, `showSaartheeSheet` using `animations`), `pressable.dart` (`Pressable`), `rise_in.dart` (`RiseIn`), `pop_in.dart` (`PopIn`, `tileStagger`), `staggered.dart` (`StaggeredColumn`, `StaggeredSliverList`; built on `flutter_animate` with token durations), `motion_check.dart` (`MotionCheck`: `CustomPainter`, `PathMetric` extract by progress), `count_up.dart` (`CountUp`), `seen_once.dart` (`SeenOnce`, `seenOnceProvider`), `staff_motion_scope.dart` (`StaffMotionScope`), `haptics.dart` (`SaartheeHaptics` + `saartheeHapticsProvider`); skeleton shimmer in `SkeletonList` as one `AnimationController` (`shimmerPeriod`) driving a low-contrast `LinearGradient` `ShaderMask` inside a `RepaintBoundary`, stopped and disposed when content arrives. No Lottie or Rive.
14. **Gallery.** `lib/features/dev/gallery_screen.dart` with sections per component, a Motion section (replay buttons for launch mark, shared axis, fade-through, sheet, press, shimmer, `RiseIn`, `PopIn`, `StaggeredColumn`, `SeenOnce`, `MotionCheck`, `CountUp`, `RollingCount`, toast, and a staff sample inside `StaffMotionScope`) and toolbar toggles (theme, `gu`/`en`, text scale 1.0/1.3/2.0, reduced motion). Register `/dev/gallery` only when `kDebugMode` (`if (kDebugMode) GoRoute(...)`).
15. **Restyle survivors.** Migrate `features/admin/**` (incl. `admin_tokens.dart` → semantic tokens), `about_screen.dart`, `global_error.dart` to the new tokens/components until T-03-03 passes.
16. **Retire v1 citizen constructs (D11).** Delete `features/onboarding/` (invite + welcome), `features/verify/`, `features/report/`, `router/citizen_routes.dart`, verify handling in `router/deep_links.dart` (keep the listener file only if another link type remains; otherwise delete it and its provider read in `app.dart`); remove `inviteCode`/`groupLabel` from `AppSettings` and the invite field from `event_queue.dart`; migrate stored prefs per §5.2. Keep `lib/core/capture/`.
17. **Locale.** `lib/core/settings/locale_controller.dart`: `localeProvider` (Notifier<Locale>) reading/writing `v2.languageCode`, calling `PreferenceSync.languageChanged`; `MaterialApp.router(locale: ref.watch(localeProvider), supportedLocales: [gu, en])`. Add `LanguageToggle` to `SaartheeAppBar` and `HomeHeader`.
18. **Home ward.** `lib/core/wards/`: models, `WardsRepository` (dio, `AppTimings` timeout, retry, cache), `homeWardProvider` (persisted, calls `PreferenceSync.homeWardChanged`), `wardsListProvider` (AsyncValue with cache fallback), `locateWardProvider` (geolocator → `/geo/locate`). Add `preferenceSyncProvider` bound to `NoopPreferenceSync`.
19. **Router + shell.** Replace `app_router.dart`: redirect to `/onboarding/language` until `v2.onboardingDone`; every route built with `saartheePage` (shared axis X); `StatefulShellRoute.indexedStack` with five `StatefulShellBranch`es each with its own `navigatorKey` and a `navigatorContainerBuilder` that fades through (`medium`) on index change while keeping every branch alive; `ShellScaffold` with `SaartheeNavigationBar` (pill slide `short`); re-tapping the current tab pops that branch to its root (`goBranch(i, initialLocation: i == current)`); `/admin/*` routes unchanged outside the shell; `/me/settings`, `/about`, `/error` as root-navigator routes. Keep the portrait lock for citizen routes.
20. **Launch motion.** Native splash (`primary` background + mark) via `flutter_native_splash` config or the Android 12 splash API; `LaunchGate` widget shows `BrandMark` scaling 0.92 → 1 with fade (`medium`) while the first route resolves, then cross-fades to it. It must not delay the first route beyond `medium` after first frame (cold-start budget, §7.2).
21. **Placeholders and Home.** `lib/features/shell/placeholders.dart` with `PlaceholderSection`/`PlaceholderScreen`; place P-01…P-09 exactly as in §5.4. Home: `HomeHeader` (`homeWardProvider`, or "Set your ward" → picker) with `ReportCard` → `goBranch(2)`; bell → `goBranch(3)`.
22. **Onboarding screens.** `lib/features/onboarding/presentation/{language,intro,ward}_screen.dart` and `ward_picker_sheet.dart` with every state in §5.4; language tiles with the 1.02 spring + selection haptic; shared-axis X between the three steps; location rationale; geolocator permission handling ("Open settings" via `Geolocator.openAppSettings()`); set `v2.onboardingDone` on finish or skip.
23. **Settings and About.** `lib/features/settings/presentation/settings_screen.dart` (language, appearance, Animations switch with system-disabled state, home ward); rewrite `about_screen.dart` with v2 copy.
24. **ARB.** Run `tool/l10n/unused_keys.dart` → delete unreferenced keys from `app_en.arb`; add all new keys (nav, Home header, Report card, onboarding, ward, settings incl. animations, about, components, toast, placeholders, errors for ward loading); create `app_gu.arb` with every key; set `l10n.yaml` `untranslated-messages-file: build/untranslated.json`, `preferred-supported-locales: [gu]`. Add `test/l10n/arb_parity_test.dart` (same key set and same placeholders in both files, no empty values) and CI step `flutter gen-l10n && test "$(cat build/untranslated.json)" = "{}"`.
25. **Hard-coded string guard.** `test/l10n/no_hardcoded_strings_test.dart`: scans `lib/features/**` and `lib/core/widgets/**` for `Text('` / `Text("` / `label: '` / `tooltip: '` string literals with letters; allow-list only `lib/features/dev/`.
26. **Widget, motion and golden tests.** Write T-03-04…T-03-28 (§8). Goldens under `test/goldens/` for each component in light/dark × en/gu (settled state), plus 2.0× scale for buttons, list rows, issue card, alert card, step header, Home header + Report card, toast; `MotionCheck` at progress 0, 0.5, 1.
27. **Static + CI.** `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` (and `--tags golden` on CI). Add the Flutter test job to the CI workflow from TASK-01 (or create `.github/workflows/mobile.yml` if TASK-01 has not landed).
28. **Manual checks** M-03-01…M-03-10 on the emulator; record screenshots in `docs/demo/evidence/v2/task-03/` and short screen recordings (`adb shell screenrecord --time-limit 10 /sdcard/<moment>.mp4`, then `adb pull`) in `docs/demo/evidence/v2/task-03/motion/`.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Language-first onboarding
- **Given** a fresh install with device locale `en-IN`
- **When** the app opens
- **Then** `/onboarding/language` shows both titles in their own scripts and "English" pre-highlighted (`primaryContainer` fill, 2 px `primary` outline); tapping "ગુજરાતી" re-renders the screen in Gujarati immediately; Continue leads to the intro in Gujarati

**AC-2** — Intro with independence line
- **Given** the intro screen in either language
- **When** it is shown
- **Then** the Neem mark (rounded `primary` square, white route chevron, `sunrise` dot), the Baloo Bhai 2 wordmark, tagline, three benefit rows and the independence line ("Independent citizen app. Not run by or linked to AMC." / Gujarati equivalent) are visible, with no AMC logo or AMC colours

**AC-3** — Home ward by GPS
- **Given** location permission granted and `/geo/locate` returning Ward 12 Paldi with `confirm:false`
- **When** the citizen taps "Use my location" and then "Yes, continue"
- **Then** `v2.homeWard` stores Ward 12, `v2.onboardingDone` is true, the shell opens on Home with "Ward 12 · Paldi" in the green `HomeHeader` ward line; with `confirm:true` the "just outside" wording is shown instead

**AC-4** — Home ward by picker and degrade path
- **Given** `/wards` returns 48 wards in 7 zones (then: the API unreachable with a cache; then unreachable without a cache)
- **When** the citizen opens "Choose from list" and searches "pal" / "12"
- **Then** results are grouped by zone and filtered by name or number; loading shows shimmering skeleton rows that cross-fade to the list; with a cache the list shows plus the offline banner; without a cache the error state offers "Try again" and "Skip for now", and skipping completes onboarding with no home ward and the Home header shows "Set your ward"

**AC-5** — Location denied
- **Given** location permission denied permanently
- **When** "Use my location" is tapped
- **Then** "Location is off. You can choose your ward from the list instead." appears with "Open settings" and "Choose from list"; no crash, onboarding can still finish

**AC-6** — Five-tab shell keeps state per tab
- **Given** onboarding done
- **When** the citizen scrolls Home, switches to Alerts, then back to Home; and pushes a child route in My Ward (`/me/settings` from the My Ward branch) then switches tabs and back
- **Then** Home keeps its scroll offset, My Ward still shows the pushed page, labels are always visible, the selected tab shows its filled Rounded icon on the `primaryContainer` pill, the Report tab icon is filled `add_circle` in `sunrise`, and re-tapping the active tab returns it to its root

**AC-7** — Instant language switch everywhere
- **Given** the app in English on the Alerts tab with `/me/settings` open in My Ward
- **When** the citizen selects ગુજરાતી in settings or taps the "અ" toggle (app bar or Home header)
- **Then** every visible string, the nav labels and date formats switch to Gujarati without restart or navigation loss; `v2.languageCode` = `gu` after relaunch; `PreferenceSync.languageChanged('gu')` was called once

**AC-8** — Tokens only
- **Given** the full `lib/` tree
- **When** T-03-01 and T-03-03 run
- **Then** every token equals its DS §2 v2.2 hex (`primary` #14674A, `sunrise` #C24A1F, `background` #F3F6F1 …); no `Color(0x…)`, `Colors.*` (except transparent), raw `fontSize` or `Icons.*` occurs outside `lib/core/theme/`; and no v1 token name (`indigo`, `marigold`, `ink`) or Civic Blue `secondary*` token remains

**AC-9** — Typography and 200 % text
- **Given** the gallery and the onboarding screens at text scale 2.0 on a 360×640 dp viewport in Gujarati
- **When** they render
- **Then** headings and numbers use Baloo Bhai 2 (never below 16 sp), body and card titles use Mukta Vaani, no overflow errors are thrown, no text is clipped, buttons grow in height rather than truncating, and Gujarati conjuncts render with the bundled fonts (golden)

**AC-10** — Component library and gallery
- **Given** a debug build
- **When** `/dev/gallery` is opened
- **Then** every component in §5.4 is shown in its states (default, pressed/selected, disabled, loading, error, empty, offline) and the Motion section replays each TASK-03 motion and motion widget; in a profile build the route is not registered and navigating to it shows the router's not-found page

**AC-11** — Status, severity and category never by colour alone
- **Given** `StatusChip` for each of the 7 statuses, `SeverityChip`/`AlertCard` for each of the 4 severities and `CategoryBadge` for each of the 14 categories
- **When** rendered in light and dark
- **Then** each status and severity shows its DS §2 Rounded icon and word in the current language with the DS §2 colours (tint/solid); alert cards are tinted with no side bar and the critical alert is a solid banner with white text; each category badge is its glyph in the category colour on a 12% tint inside a 40 dp rounded square (radius 14) with the category name as its label

**AC-12** — Accessibility guidelines
- **Given** the shell, onboarding screens and gallery
- **When** the Flutter accessibility guideline matchers run
- **Then** `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline` pass (including the 36 dp header buttons inside 48 dp targets); semantics traversal order equals visual order on onboarding; `StepHeader` announces "Step 2 of 3"; `ErrorSummary` takes focus when shown; toasts are announced

**AC-13** — Dark theme
- **Given** theme set to Dark (or System with the device in dark mode)
- **When** shell, onboarding and gallery render
- **Then** the DS §2 dark palette is used (`background` #131C18, `primary` #7BD3A6, `sunrise` #FF9E78 …), all contrast pairs pass T-03-02, and status/severity remain icon + word

**AC-14** — Complete bilingual ARB
- **Given** `app_en.arb` and `app_gu.arb`
- **When** `flutter gen-l10n` and T-03-17/T-03-18 run
- **Then** both files have identical key sets and placeholders, `build/untranslated.json` is `{}`, no retired v1 key (`invite*`, `welcome*`, `verify*`, v1 `report*`) remains, and no hard-coded user-facing string exists in `lib/features` or `lib/core/widgets`

**AC-15** — v1 constructs retired, admin intact
- **Given** an install upgraded from v1 with `inviteCode` stored and an unfinished v1 report draft
- **When** the v2 build starts
- **Then** the app opens onboarding (v2 flag absent), the v1 keys and draft are removed from storage, no invite/verify/report-v1 route exists, and `/admin/login` still works with the v1 admin credentials in the new style

**AC-16** — Neem signature components
- **Given** Home and the gallery in light theme
- **When** they render
- **Then** Home shows the green `primary` header band with ward line, greeting, language and bell buttons and the `sunrise` Report card (≥ 56 dp, radius 14, white "+" circle, title, hint, arrow, glow); `sunrise` appears on no other element of the screen; buttons are 50 dp (56 pinned) with radius 14, cards radius 18 with 1 px border and soft shadow, sheets radius 24, chips pills; `showSaartheeToast` shows a `primaryDark` toast with radius 18, white text and a drawn check for success, visible for 4 s

**AC-17** — Motion tokens everywhere
- **Given** the full `lib/` tree
- **When** T-03-21 and T-03-22 run
- **Then** `SaartheeMotion` values equal DS §6 (100/180/280/380/450 ms with their curves, stagger 60 ms max 6, rise 14 dp, drawCheck 450 ms after 150 ms, countUp 600 ms), every TASK-03 animation reads them through `SaartheeMotion.of(context)`, and no `Duration(`, `Cubic(` or `Curves.` literal exists under `lib/features/**` outside `lib/features/dev/`

**AC-18** — Navigation motion
- **Given** a fresh install with full motion
- **When** the app launches, the citizen moves language → intro → ward, switches tabs, pushes `/me/settings` and opens the ward picker
- **Then** the mark scales 0.92 → 1 and fades over 280 ms and the first screen cross-fades in with nothing looping; onboarding steps and pushes use shared-axis X (back reverses) over 280 ms; tab switches fade through over 280 ms while the nav pill slides and stretches to the new tab over 180 ms and each tab keeps its scroll; the picker sheet slides up with `springIn`; the chosen language tile springs to 1.02 and back

**AC-19** — Feedback motion and reusable widgets
- **Given** the gallery Motion section and the onboarding/Home screens
- **When** the citizen presses buttons and cards, a list loads, and each reusable motion widget is replayed
- **Then** pressed buttons/cards scale to 0.97 within 100 ms and primary actions give a light haptic; skeletons shimmer at one sweep per 1.2 s and stop and cross-fade (280 ms) as soon as content arrives; `MotionCheck` starts drawing 150 ms after it appears and completes 450 ms later; `CountUp` reaches its integer target in 600 ms showing only integers and does not replay on a rebuild with the same value; `StaggeredColumn` starts items 60 ms apart with items beyond the sixth entering with the sixth, and does not replay when the tab is revisited (`SeenOnce`); `RollingCount` rolls to the new digit; inside `StaffMotionScope` only `short` fades occur and nothing scales on press

**AC-20** — Reduced motion
- **Given** the system "Remove animations" setting on (`MediaQuery.disableAnimations`), and separately the in-app Settings → Animations switch off
- **When** the citizen repeats the AC-18 and AC-19 journeys
- **Then** every motion is an instant change or a ≤ 100 ms cross-fade (no scale, slide, stagger, spring, draw or count animation; shimmer static), the same content and text appear as with motion on, haptics still follow the system setting, `v2.animationsEnabled=false` survives relaunch, and with the system setting on the in-app switch shows off and disabled with its explanation

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-004, REQ-F-006 |
| AC-2 | REQ-F-004 |
| AC-3 | REQ-F-004 |
| AC-4 | REQ-F-004, REQ-N-003 |
| AC-5 | REQ-F-004 |
| AC-6 | REQ-F-005, REQ-N-003 |
| AC-7 | REQ-F-006, REQ-N-005 |
| AC-8 | REQ-N-001 |
| AC-9 | REQ-N-002 |
| AC-10 | REQ-N-003 |
| AC-11 | REQ-N-001, REQ-N-004 |
| AC-12 | REQ-N-004 |
| AC-13 | REQ-N-006 |
| AC-14 | REQ-N-005 |
| AC-15 | REQ-F-005, REQ-N-005 |
| AC-16 | REQ-N-001, REQ-N-003 |
| AC-17 | REQ-N-012 |
| AC-18 | REQ-N-012, REQ-F-004, REQ-F-005 |
| AC-19 | REQ-N-012, REQ-N-003 |
| AC-20 | REQ-N-012, REQ-N-004 |

### 7.2 Non-Functional Checklist

- [ ] All DS §2 token pairs (light and dark, incl. category glyph on tint) meet AA in T-03-02
- [ ] Every interactive element ≥ 48×48 dp and labelled; focus ring visible (`focusRing` + `focusInner`) on keyboard/switch access
- [ ] Every animation uses `SaartheeMotion` tokens; reduced motion (system or in-app) makes every motion instant or a ≤ 100 ms cross-fade
- [ ] Only transform, opacity and colour are animated in TASK-03 widgets (no `AnimatedContainer`/`AnimatedSize`/`AnimatedPadding` on layout); the `StepHeader` progress is painted and clipped
- [ ] Nothing loops except the skeleton shimmer while waiting; nothing flashes more than 3 times per second; no Lottie/Rive
- [ ] TASK-03 moments hold 60 fps on the emulator in profile mode (M-03-10); the low-end phone evidence is TASK-14's (REQ-N-013)
- [ ] No full-screen spinners; skeletons for lists
- [ ] Subset fonts (Baloo Bhai 2 ×3 + Mukta Vaani ×3) total ≤ 1.2 MB; release APK size increase (fonts + Material Symbols after tree-shaking) recorded in §13
- [ ] Cold start to onboarding/Home ≤ 3 s on the emulator in profile mode including the launch motion (measured; re-measured on a low-end phone in TASK-14)
- [ ] No AMC logo, seal, bronze/amber/navy-gradient/teal colours anywhere (visual check of gallery); `sunrise` only on report actions
- [ ] Location used once for ward lookup, not stored or sent anywhere except `/geo/locate`
- [ ] Screens import providers only; no dio calls in `presentation/`
- [ ] `dart format`, `flutter analyze` clean; `flutter test` green incl. goldens on CI

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-03-01 | `dart format --set-exit-if-changed .`, `flutter analyze` | Code quality gate |
| Unit | T-03-01 | Token values equal DS §2 v2.2 hex for every named token (light and dark), status, severity and category; radii 14/18/24/pill; spacing scale; button heights 50/56 | AC-8, AC-11, AC-16 |
| Unit | T-03-02 | WCAG contrast of every text/background and non-text pair, light and dark, incl. `onPrimarySubtle` on `primary`, white on `sunrise`, category glyph on 12% tint | AC-12, AC-13 |
| Unit | T-03-03 | No colour/font-size/`Icons.` literals or v1/Civic Blue token names outside `lib/core/theme/` | AC-8 |
| Unit | T-03-04 | `TextTheme` roles: family, size, weight, line height per DS §3; Baloo never < 16 sp; no size < 12; fallback lists Noto Sans Gujarati + Noto Sans; `tnum` present in Baloo or fixed-width digit fallback active | AC-9 |
| Widget | T-03-05 | Buttons: loading disables and shows progress; heights 50/56; radius 14; `SubmitReportButton` in `sunrise`; semantics label | AC-10, AC-12, AC-16 |
| Widget | T-03-06 | `LabeledTextField` optional suffix, helper, error row; `ErrorSummary` takes focus and links move focus | AC-10, AC-12 |
| Widget | T-03-07 | `StatusChip` × 7 and `SeverityChip` × 4: Rounded icon + localized word in en and gu | AC-11 |
| Widget | T-03-08 | `ListRow`, `IssueCard`, `StatusTimeline` (14 dp dots), `AlertCard` (tinted, no side bar), `CategoryBadge` × 14 (tinted rounded square), `StatTile`, `RepresentativeRow`, `PhotoThumb` render with required semantics | AC-10, AC-11 |
| Widget | T-03-09 | `EmptyState` (56 dp icon on `primaryContainer` circle), `SkeletonList`, `ErrorState` ("Try again" callback), `NoticeBanner` variants, `SaartheeToast` (colours, radius 18, 4 s hold, announcement) | AC-10, AC-16 |
| Golden | T-03-10 | Neem goldens for all components (settled state): light/dark × en/gu; 2.0× for buttons, rows, cards, step header, Home header + Report card, toast; `MotionCheck` at 0/0.5/1; v1/Civic Blue goldens deleted | AC-9, AC-11, AC-13, AC-16 |
| Widget | T-03-11 | Gallery route present with `kDebugMode`, absent when the gallery flag is false (router built with `enableGallery:false`); Motion section lists every replay | AC-10 |
| Widget | T-03-12 | Shell: 5 destinations with labels; filled icon on selected; Report glyph `sunrise`; tab state preserved (scroll offset, pushed child); re-tap pops to root | AC-6 |
| Widget | T-03-13 | Onboarding language: device-locale preselect, switching re-renders, persisted `v2.languageCode` | AC-1 |
| Widget | T-03-14 | Settings language switch + app-bar/header toggle: whole tree in gu, `PreferenceSync.languageChanged` called once (fake) | AC-7 |
| Widget | T-03-15 | Ward step with fake repository: GPS success (ward in Home header), `confirm:true`, denied, 422 outside city, API down with/without cache, skip | AC-3, AC-4, AC-5 |
| Widget | T-03-16 | Ward picker search by name/number, zone grouping, no-match message, skeleton → list cross-fade | AC-4 |
| Unit | T-03-17 | ARB parity: same keys, placeholders, non-empty values; no retired prefixes | AC-14 |
| Unit | T-03-18 | No hard-coded strings in `lib/features`, `lib/core/widgets` | AC-14 |
| Widget | T-03-19 | Accessibility guidelines (tap target, labelled targets, text contrast) on shell, Home header, onboarding, gallery; traversal order | AC-12 |
| Widget | T-03-20 | v1 prefs migration: `inviteCode`/draft keys removed, onboarding shown; admin login route resolves | AC-15 |
| Unit | T-03-21 | `SaartheeMotion` values and curves equal DS §6 (incl. `stagger` 60 ms, `tileStagger` 35 ms, `staggerMaxItems` 6, `mapPinStagger` 30 ms, `mapPinMaxAnimated` 20); no `AppMotion` symbol exists; reduced scheme maps transforms/draws/counts to zero and transitions to a 100 ms fade; `reducedMotionProvider` is true when either `systemDisableAnimationsProvider` is true or the Animations switch is off (truth table), and `SaartheeMotion.of` follows it | AC-17, AC-20 |
| Unit | T-03-22 | Guard: fails if `Duration(`, `Cubic(` or `Curves.` appears under `lib/features/**` (except `dev/`); proven by a fixture file that must fail | AC-17 |
| Widget | T-03-23 | Navigation motion pumped through token durations: launch mark scale 0.92 at t=0 and 1.0 at 280 ms, no running animations after; shared axis at 140 ms shows both pages, only the new one at 280 ms; tab fade-through at 280 ms with branch state kept; nav pill x-position interpolates during 180 ms; sheet uses `springIn` (overshoot ≤ 6%); language tile scale peaks at 1.02 | AC-18 |
| Widget | T-03-24 | `Pressable`: scale 0.97 after 100 ms held, 1.0 after release; tap still fires. With `saartheeHapticsProvider` overridden by `FakeSaartheeHaptics`: primary button records `light`, language tile records `selection`, success toast records `success`; real `SaartheeHaptics` sends `HapticFeedback.vibrate` on `SystemChannels.platform` | AC-19 |
| Widget | T-03-25 | Skeleton: shimmer period 1.2 s; when data arrives the shimmer controller stops and content cross-fades within 280 ms; `hasRunningAnimations` false afterwards (no other loops) | AC-19, AC-4 |
| Widget | T-03-26 | `MotionCheck` progress 0 at 149 ms, > 0 at 200 ms, 1 at 600 ms; `CountUp` 0 → 37 shows only integers and 37 at 600 ms, no replay on same-value rebuild; `StaggeredColumn` item i starts at i×60 ms, items 7–10 with item 6, rise 14 dp, no replay with the same `playOnceKey`; `PopIn` grid items start `tileStagger` (35 ms) apart; `SeenOnce` with the same key animates on the first mount only and shows the end state on the second mount and on rebuilds, a new key animates again; `RollingCount` (`lib/core/widgets/rolling_count.dart`) new digit at 180 ms with semantics = final value | AC-19 |
| Widget | T-03-27 | Reduced motion, run twice (`MediaQueryData(disableAnimations: true)` → `reducedMotionProvider` true; in-app switch off → `reducedMotionProvider` true): AC-18/AC-19 journeys reach their end state after one `pump(100 ms)`; `MotionCheck` drawn and `CountUp` final on first frame; all stagger items visible at once; shimmer static; rendered text identical to the full-motion run; `v2.animationsEnabled` persisted; switch disabled with explanation under the system flag | AC-20 |
| Widget | T-03-28 | `StaffMotionScope`: inside it a `saartheePage` push and a `StaggeredColumn` resolve to a `short` (180 ms) fade with no slide, stagger or spring, and `Pressable` does not scale; outside it the same widgets use full motion | AC-19 |
| Manual | M-03-01 | Fresh install on emulator: full onboarding in Gujarati with GPS (Ahmedabad location) against a TASK-02 API if available, else with API stopped (degrade + skip) | AC-1…AC-5 |
| Manual | M-03-02 | TalkBack on onboarding, Home header and shell: reading order, labels, "Step n of 3" in gallery, toast announced | AC-12 |
| Manual | M-03-03 | Settings → Font size largest + Display size largest: onboarding, Home, settings, gallery; no clipping | AC-9 |
| Manual | M-03-04 | Dark mode system toggle; theme setting overrides | AC-13 |
| Manual | M-03-05 | Upgrade install over a v1 build with an invite code and draft | AC-15 |
| Manual | M-03-06 | Profile build: `/dev/gallery` not reachable; release APK size noted | AC-10 |
| Manual | M-03-07 | Language switch on each tab with a pushed page; state kept | AC-6, AC-7 |
| Manual | M-03-08 | Visual review of gallery, Home and onboarding against `docs/v2/design-options.html` (direction B) and the Baloo Bhai 2 + Mukta Vaani sample in `docs/v2/font-options.html`; screenshots light/dark, en/gu | AC-2, AC-11, AC-16 |
| Manual | M-03-09 | Motion on the emulator: launch, onboarding, tab switch with pill, push, sheet, press, skeleton → content, toast; then with Accessibility → Remove animations on, and with the in-app switch off; recordings in `docs/demo/evidence/v2/task-03/motion/` | AC-18, AC-19, AC-20 |
| Manual | M-03-10 | Profile build on the emulator with the performance overlay / DevTools timeline: TASK-03 moments show no frame > 16 ms; findings passed to TASK-14 | AC-18, AC-19 |

## 9. Deliverables

- Neem tokens (light/dark), typography, `SaartheeIcons` (Material Symbols Rounded), `SaartheeMotion`, `AppTheme.light/dark`, theme-mode and animations settings.
- Subset Baloo Bhai 2 (600/700/800) and Mukta Vaani (400/500/600) TTFs, OFL licences, instance + subset script.
- Component library (§5.4) including `HomeHeader`, `ReportCard`, `SaartheeToast`, `CategoryBadge`, `StatTile`, `RollingCount`, and debug-only `/dev/gallery` with a Motion section.
- Motion layer in `lib/core/motion/`: shared transitions, `Pressable`, `RiseIn`, `PopIn`, `StaggeredColumn`, `SeenOnce`, `MotionCheck`, `CountUp`, `StaffMotionScope`, `SaartheeHaptics`, skeleton shimmer, launch motion, reduced motion.
- Five-tab `StatefulShellRoute` shell with fade-through and the placeholder register P-01…P-09.
- Onboarding v2 (language, intro, ward with GPS/picker/degrade), settings (incl. Animations switch), About.
- `localeProvider`, `homeWardProvider`, `motionPreferenceProvider`, `reducedMotionProvider`, `saartheeHapticsProvider`, `WardsRepository`, `PreferenceSync` port.
- Cleaned `app_en.arb`, complete `app_gu.arb`, l10n CI checks.
- Flutter unit, widget, motion, golden and accessibility tests T-03-01…T-03-28; CI job.
- Screenshots and motion recordings in `docs/demo/evidence/v2/task-03/`.
- Coverage matrix evidence for 10 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/mobile/pubspec.yaml` | Modified (fonts, assets, pinned `animations`, `flutter_animate`, `material_symbols_icons`) |
| `apps/mobile/assets/fonts/BalooBhai2-*.ttf`, `MuktaVaani-*.ttf`, `*-OFL.txt` | New (v1 font assets deleted) |
| `apps/mobile/tool/fonts/subset_fonts.sh`, `tool/l10n/unused_keys.dart` | New |
| `apps/mobile/l10n.yaml` | Modified |
| `apps/mobile/lib/core/theme/{tokens,typography,icons,motion,app_theme,theme_mode}.dart` | Rewritten / New |
| `apps/mobile/lib/core/motion/*.dart` | New |
| `apps/mobile/lib/core/config/timings.dart` | New |
| `apps/mobile/lib/core/widgets/*.dart` | Rewritten / New |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified / New |
| `apps/mobile/lib/core/settings/{app_settings,locale_controller,motion_preference,preference_sync}.dart` | Modified / New |
| `apps/mobile/lib/core/wards/` | New |
| `apps/mobile/lib/router/{app_router,shell_routes}.dart` | Rewritten / New |
| `apps/mobile/lib/router/{citizen_routes,deep_links}.dart` | Deleted (deep_links if no link type remains) |
| `apps/mobile/lib/features/{onboarding,shell,settings,dev,launch}/` | Rewritten / New |
| `apps/mobile/lib/features/{verify,report}/`, `features/onboarding/*invite*` | Deleted |
| `apps/mobile/lib/features/home/presentation/` | Rewritten (Home header + placeholders, About) |
| `apps/mobile/lib/features/admin/presentation/**` | Modified (tokens only) |
| `apps/mobile/lib/app.dart`, `lib/main.dart` | Modified (locale, theme mode, `MotionScope`, licences) |
| `apps/mobile/android/app/src/main/res/**` (splash), splash config | Modified |
| `apps/mobile/test/**`, `test/goldens/**`, `test/flutter_test_config.dart`, `test/helpers/{motion,fake_haptics}.dart`, `test/fixtures/wards.json` | New |
| `.github/workflows/mobile.yml` (or TASK-01 CI file) | New / Modified |
| `docs/demo/evidence/v2/task-03/**` | New (screenshots, motion recordings) |

## 11. Related Documentation

- `docs/v2/design-system.md` v2.2 ("Neem") DS §1 (identity, mark, independence line), §2 (colour tokens, status, severity, category, dark), §3 (typography), §4 (shape, spacing, elevation, icons, photos), §5 (components), §6 (motion tokens, catalogue, rules, libraries), §7 (accessibility), §9 (screen inventory)
- `docs/v2/design-options.html` (direction B Neem) and `docs/v2/font-options.html` (Baloo Bhai 2 + Mukta Vaani) — founder choice 2026-10-03; visual reference only
- `docs/v2/saarthee-v2-spec.md` §2 D1, D4, D6, D11; §8 routes and navigation
- `docs/tasks-v2/TASK-02-*.md` — ward endpoints (contract consumer)
- `docs/tasks-v2/TASK-04-accounts-privacy-push.md` — `PreferenceSync` implementation
- `docs/tasks-v2/TASK-14-e2e-launch.md` — REQ-N-013 motion performance evidence on the low-end phone
- `docs/02-frontend-spec.md` — v1 frontend (superseded where v2 differs)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Gujarati shaping wrong after instancing/subsetting (missing GSUB features) | Broken conjuncts, unreadable text | Keep all layout features; golden with conjunct test strings ("ક્ષ", "દ્ર", "શ્રી") in both families |
| Baloo Bhai 2 too heavy at small sizes or in long Gujarati titles | Hard to read | DS §3 rule enforced by T-03-04 (Baloo ≥ 16 sp, card titles in Mukta Vaani) |
| Golden tests flaky across OS | CI noise | Linux-only goldens, bundled fonts loaded in test config, settled states only |
| Motion janks on low-end phones (shimmer, fade-through over heavy tabs) | Feels slow; REQ-N-013 fails in TASK-14 | Transform/opacity only, `RepaintBoundary` around shimmer and pill, profile pre-check M-03-10, reduced scheme as fallback |
| Motion package API change or abandonment | Rework | Pin exact versions; all use goes through `lib/core/motion/` wrappers so a package can be replaced in one place |
| Custom nav pill breaks `NavigationBar` semantics | TalkBack regression | Pill is a decorative overlay; semantics and targets stay on `NavigationBar`; T-03-19 |
| TASK-02 ward contract differs | Onboarding ward step breaks | Single mapper + fixture; degrade path always available |
| Deleting the v1 report flow leaves dev builds without reporting until TASK-05 | Demo gap | Documented; TASK-05 is next on the core lane |
| Large ARB rewrite causes missed strings | Mixed-language screens | Parity + untranslated + hard-coded-string tests in CI |
| Machine-quality Gujarati copy | Trust and comprehension | `x-review: pending` metadata; native editor before TASK-14 |
| Dark-theme tints or category glyphs fail AA | Accessibility regression | T-03-02 blocks merge; adjust and record |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Automated tests added and passing
- [ ] Static checks pass and every AC verified by the checks in §8
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Neem tokens, Baloo Bhai 2 + Mukta Vaani fonts and Material Symbols Rounded in use; no Noto primary font, no `Icons.*`, no Civic Blue or v1 tokens left
- [ ] Motion tokens guard (T-03-22) and reduced-motion test (T-03-27) green; Settings → Animations switch verified on the emulator
- [ ] Motion recordings (full and reduced) saved in `docs/demo/evidence/v2/task-03/motion/`; profile pre-check M-03-10 findings recorded in §13 and passed to TASK-14
- [ ] Reusable motion API for TASK-05…TASK-12 in place and shown in the gallery: `Pressable`, `RiseIn`, `PopIn`, `StaggeredColumn`, `SeenOnce`, `MotionCheck`, `CountUp`, `RollingCount`, `StaffMotionScope`, `SaartheeMotion.tileStagger`, `SaartheeMotion.mapPinStagger`, `SaartheeMotion.mapPinMaxAnimated`, `reducedMotionProvider`, `SaartheeHaptics` / `saartheeHapticsProvider` with `FakeSaartheeHaptics`
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed (package versions, Baloo `tnum`, Material Symbols source)
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-03` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-03: …`
- [ ] Validator passes
