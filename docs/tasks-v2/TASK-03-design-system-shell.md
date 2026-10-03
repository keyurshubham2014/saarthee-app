# TASK-03: Civic Blue Design System, App Shell & Onboarding

| Field | Value |
|---|---|
| Task ID | TASK-03 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | None |
| Blocks | TASK-04, TASK-12 |
| Requirement IDs | REQ-F-004, REQ-F-005, REQ-F-006, REQ-N-001, REQ-N-002, REQ-N-003, REQ-N-004, REQ-N-005, REQ-N-006 |
| Primary Spec Refs | Spec §1, §2 (D1, D4, D11), §8; DS §1–§6, §8 |
| Last Updated | 2026-10-03 |

## 1. Objective

Give Saarthee its v2 look and skeleton. Replace the v1 "indigo and marigold" tokens with the Civic Blue semantic token set (DS §2), bundle Noto Sans and Noto Sans Gujarati as subset fonts (DS §3), and build the shared component library (DS §5) with a debug-only gallery and widget/golden tests. Replace the v1 single-stack router with a five-tab citizen shell (Home · Map · Report · Alerts · My Ward) whose tabs keep their own navigation state, and replace the v1 invite-code onboarding (retired by D11) with v2 onboarding: language first, one intro screen with the independence line, and home ward by GPS or picker. Make the whole app bilingual: a complete Gujarati ARB alongside English, an instant language switch, and no hard-coded strings. Later tasks fill the tab bodies; every placeholder this task leaves is listed in §5.4 so TASK-14 can confirm none remain.

## 2. Scope

### In Scope
- `lib/core/theme/`: semantic colour tokens (light + dark) as a `ThemeExtension`, status/severity/category palettes, spacing/radius/motion/elevation constants, `ThemeData` builders (`AppTheme.light()`, `AppTheme.dark()`), `ThemeMode` setting (system/light/dark).
- Fonts: Noto Sans + Noto Sans Gujarati, weights 400/500/600, subset TTFs with OFL licence files, subset script, `pubspec.yaml` font families, `fontFamilyFallback`.
- Component library in `lib/core/widgets/` per DS §5 (list in §5.4) and a debug-only gallery route `/dev/gallery`.
- Migration of every existing screen that stays (v1 admin console, About, global error) to the new tokens and components so the app compiles with no colour literals outside `lib/core/theme/`.
- New router: `StatefulShellRoute.indexedStack` with five branches; onboarding routes; `/me/settings` (language, theme, about); `/about` rewritten for v2 independence copy.
- Onboarding v2: `/onboarding/language`, `/onboarding/intro`, `/onboarding/ward` (GPS → `GET /geo/locate`, picker → `GET /wards`), graceful degradation when the API is unavailable.
- Locale and home-ward state: `localeProvider`, `homeWardProvider`, both persisted on device; a `PreferenceSync` port that TASK-04 implements to persist language and home ward on the account.
- `app_gu.arb` complete for every key; English ARB cleaned: retired v1 keys deleted, kept keys migrated, new keys added; parity test and untranslated-messages check in CI.
- Retirement (D11) of v1 citizen constructs in the app: invite-code onboarding (`features/onboarding/*invite*`, `welcome_screen.dart`), v1 WhatsApp-token verify flow (`features/verify/`, verify deep links), the v1 six-step CCRS-first report screens and draft (`features/report/`), and their keys. `lib/core/capture/` is kept for TASK-05.
- Flutter tests: theme/contrast unit tests, component widget tests, golden tests for components in light, dark, `gu` and 2.0× text scale, shell and onboarding widget tests, accessibility guideline tests.

### Out of Scope
- Sign-in, profile, account sync of language/home ward, push permission and topic subscription — TASK-04 (implements `PreferenceSync`).
- Ward data, `GET /wards` and `GET /geo/locate` server side — TASK-02 (this task builds against the contract in §5.3).
- Real tab content: Home feed and Map (TASK-07), Report flow (TASK-05), Alerts (TASK-08), My Ward (TASK-09), services and drives (TASK-12).
- Map pins and cluster rendering — TASK-07 (needs the map package; tokens for them are defined here).
- Staff console look and side navigation — TASK-10 (it reuses these tokens and components).
- Removing the v1 API endpoints for invite codes and verify tokens — API stays untouched in this task.
- Hindi / Noto Sans Devanagari — phase 3 (REQ-F-092 deferred).

## 3. Prerequisites

- Flutter SDK matching `apps/mobile/pubspec.yaml` (`sdk: ^3.13.1`); `flutter pub get` succeeds on the v1 tree.
- Python 3 with `fonttools` (`pip install fonttools brotli`) for the font subset script (developer machine only; the subset TTFs are committed).
- Noto Sans and Noto Sans Gujarati static TTFs (400/500/600) downloaded from the official Noto repository (`notofonts/latin-greek-cyrillic`, `notofonts/gujarati`) with their `OFL.txt`.
- Android emulator (API 34+) with a location set inside Ahmedabad (e.g. 23.0225, 72.5714) for M-03 checks.
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
| REQ-N-004 | Accessibility: 48 dp targets, labels on all controls, contrast AA, icon + text for every status, TalkBack order | DS §6 |
| REQ-N-005 | Complete Gujarati and English ARB translations for every string; no hard-coded strings | Spec D4 |
| REQ-N-006 | Dark theme from the same tokens | DS §2 |

### 5.2 Data Contracts

No database changes. Device storage (`shared_preferences`, keys prefixed `v2.`):

| Key | Type | Meaning |
|---|---|---|
| `installId` | String (UUID v4) | Kept from v1 unchanged (TASK-04 uses it for `POST /devices`) |
| `v2.languageCode` | `gu` \| `en` | Chosen in onboarding or settings; absent → device locale if `gu`, else `en` |
| `v2.themeMode` | `system` \| `light` \| `dark` | Default `system` |
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
Default provider binds `NoopPreferenceSync`. TASK-04 overrides it to call `PATCH /me` when signed in and to re-subscribe FCM topics.

Token model (`lib/core/theme/tokens.dart`, replaces v1 file):
- `SaartheeColors extends ThemeExtension<SaartheeColors>` with fields named exactly as DS §2: `primary, primaryDark, primaryContainer, onPrimaryContainer, secondary, secondaryContainer, background, surface, surfaceAlt, border, borderStrong, textPrimary, textSecondary, textDisabled, success, successTint, warning, warningTint, error, errorTint, info, infoTint, focusRing, focusInner`; `static const light`, `static const dark`; `lerp` implemented.
- `IssueStatusStyle` enum-keyed map for `reported, acknowledged, inProgress, markedFixed, verified, reopened, rejected` → `{solid, tint, icon, l10nKey}` (DS §2 table). `sent` and `acknowledged` share one style.
- `AlertSeverityStyle` for `info, advisory, warning, critical` → `{solid, tint, icon, l10nKey}`.
- `CategoryStyle` map keyed by the 14 slugs → `{color, icon}` (DS §2), `fallback = other`.
- `AppSpacing` (4/8/12/16/24/32, `gutter 16`, `maxContent 600`, `staffMaxContent 1200`, `touchTarget 48`, `buttonHeight 48`, `pinnedButtonHeight 56`), `AppRadii` (8/12/16), `AppMotion` (150 ms, 200 ms, `Curves.easeInOut`), `AppElevation` (card 0, sheet 1, dialog 3).
- Dark palette per DS §2 dark row; dark status/severity use the tint colour as text on `surface` and the solid colour for dots/bars. Every pair is checked in T-03-02.

### 5.3 API Contracts

This task calls two TASK-02 endpoints (not built here). Shapes assumed (ASSUMPTION in §5.6); the mapper in `lib/core/wards/wards_repository.dart` is the only place to adapt if TASK-02 differs.

| Method | Path | Auth | Request | Expected response | Errors handled |
|---|---|---|---|---|---|
| GET | `/api/v1/wards` | None | — | 200 `{items:[{id, number, nameEn, nameGu, zone:{id, code, nameEn, nameGu}}]}` (48 items) | network/timeout, 5xx, 429, 404 (endpoint not deployed yet) → degrade |
| GET | `/api/v1/geo/locate?lat=&lng=` | None | lat/lng 6 dp | 200 `{ward:{…as above}, zone:{…}, confirm:boolean}` | 404 / network → "Choose from list"; 422 (outside city) → message + list |

Client rules: 8 s timeout; one automatic retry for idempotent GETs on network error; `Accept-Language` header set from `localeProvider`; results cached as `v2.wardsCache` (no expiry in this task; TASK-02 may add one).

### 5.4 UI Surfaces & States

Shell routes (`lib/router/app_router.dart`, `lib/router/shell_routes.dart`):

| Branch | Route | Tab label (en / gu key) | Icon (outlined / selected filled) | Body in this task |
|---|---|---|---|---|
| 0 | `/` | Home / `navHome` | `home` | Ward header + "Report an issue" + placeholders P-01…P-03 |
| 1 | `/map` | Map / `navMap` | `map` | Placeholder P-04 |
| 2 | `/report` | Report / `navReport` | `add_circle` (filled always) | Placeholder P-05 |
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
| `/onboarding/language` | Title "Choose your language" + "ભાષા પસંદ કરો" (both always, each in its own script); two 72 dp tiles "ગુજરાતી" and "English"; tile matching device locale pre-highlighted; primary "Continue" / "આગળ વધો" in the selected language | Selection changes locale immediately (whole screen re-renders) |
| `/onboarding/intro` | Wordmark + mark; tagline "Report it. Track it. See it fixed."; three rows with icons: "Report any civic problem with a photo." / "Follow it until neighbours confirm the fix." / "Get alerts and reach your corporators."; independence line in an info banner: "Independent citizen app. Not run by or linked to AMC."; primary "Continue" | Back returns to language |
| `/onboarding/ward` | Title "Set your home ward"; helper "We use it to show issues, alerts and representatives near you. You can change it later."; primary "Use my location"; secondary "Choose from list"; tertiary "Skip for now" | Locating: in-button progress, "Finding your ward…"; result card "You're in Ward 12 · Paldi (West zone). Is this your home ward?" → "Yes, continue" / "Choose another"; `confirm:true` → "You seem to be just outside Ward 12 · Paldi. Is this right?"; permission denied → "Location is off. You can choose your ward from the list instead." + "Open settings"; outside city (422) → "You seem to be outside Ahmedabad. Choose your ward from the list."; API unavailable → "We couldn't load wards right now. Try again, or skip and set it later." + "Try again" + "Skip for now" |
| Ward picker (full-screen sheet, also used from settings) | Search field "Search ward name or number"; list grouped by zone headers (7); rows "12 · Paldi" with zone; selecting returns the ward | Loading: skeleton rows; offline with cache: list from cache + offline banner; offline without cache / error: error state "We couldn't load wards right now." + "Try again"; no search match: "No ward matches “{query}”." |
| `/me/settings` | Sections: Language (radio ગુજરાતી / English); Appearance (System / Light / Dark); Home ward (current + "Change" → picker); About link | Change applies instantly; account sync via `PreferenceSync` |
| `/about` | Wordmark, version, independence line (en + gu always), "Saarthee is an independent citizen project. It is not run by, funded by or linked to the Amdavad Municipal Corporation.", grievance contact placeholder line from config `GRIEVANCE_EMAIL` | — |
| `/dev/gallery` (debug builds only) | Every component in every state, with toggles for theme, locale and text scale 1.0/1.3/2.0 | Not registered when `kReleaseMode` or `kProfileMode` |

Components (`lib/core/widgets/`, exported from `widgets.dart`):

| Widget | Key behaviour |
|---|---|
| `SaartheeAppBar` | White surface, left title (headlineSmall), optional subtitle (ward name), actions: `LanguageToggle` ("અ" / "A", label "Switch to English" / "ગુજરાતીમાં બદલો"), optional bell slot with badge; 1 px bottom border when scrolled |
| `SaartheeNavigationBar` | M3 `NavigationBar`, labels always shown, `primaryContainer` indicator, filled icon for selected tab, Report icon always filled `add_circle` |
| `PrimaryButton` / `SecondaryButton` / `TertiaryButton` | 48 dp (pinned variant 56 dp), radius 8, sentence case, `isLoading` → in-button progress + disabled + semantics "Working" |
| `LabeledTextField` | Label above, "(optional)" suffix, helper below, error row with `error` icon, 1 px `borderStrong`, 2 px `primary` focus |
| `ErrorSummary` | Top-of-form box titled "There is a problem", list of links that move focus to fields; requests focus when shown |
| `AppFilterChip`, `StatusChip(IssueStatus)`, `SeverityChip(AlertSeverity)` | Status/severity = tint background + solid text + icon + word |
| `CategoryBadge(slug, size: 40)` | White glyph in a circle of the category colour; semantics = category name |
| `ListRow` | ≥ 56 dp (72 dp two-line), leading slot, trailing chip or chevron, whole row tappable |
| `IssueCard` | 4:3 thumbnail, badge, title, "Ward · age", status chip, Me-too count, overdue tag (data passed in; no API) |
| `StatusTimeline` | Vertical stepper, 12 dp dots, actor + date, future steps hollow grey, slot for after-photo and verify buttons |
| `AlertCard` | Severity icon + word, title, area, validity, source line "Source: {name} · Relayed by Saarthee", 4 dp left bar; critical = solid banner, white text |
| `NoticeBanner` variants `offline`, `electionMode`, `independence`, `info` | Offline copy: "You're offline. Your report is saved and will send automatically." |
| `EmptyState`, `SkeletonList`, `ErrorState`, `OfflineState` | Empty = 48 dp icon + one line + one action; error = cause + "Try again"; skeletons, never full-screen spinners |
| `StepHeader` | "Step {n} of {total}" + progress bar + Back; semantics announces the step |
| `RepresentativeRow` | Initials/photo avatar, name, role, ward, party as plain text, "Message" button (callback only) |
| `PhotoThumb` | 4:3, radius 8, 1 px border, required semantic label, optional "Faces and number plates blurred" caption |
| `BrandMark`, `Wordmark` | Mark per DS §1 drawn with `CustomPainter` in `primary`; wordmark swaps order by locale |
| `PlaceholderSection`, `PlaceholderScreen` | Temporary; `EmptyState` with `construction` icon and owner-task debug label (debug builds only) |

### 5.5 Permissions & Roles

| Action | Visitor (no account) | Signed-in citizen (TASK-04) | Notes |
|---|---|---|---|
| Onboarding, all five tabs, settings, about | ✅ | ✅ | D6: browse without account |
| Change language / theme / home ward | ✅ (device) | ✅ (device + account via `PreferenceSync`) | |
| `/dev/gallery` | Debug builds only | Debug builds only | Route absent in profile/release |
| v1 `/admin/*` console | Unchanged (admin login) | Unchanged | Restyled only; TASK-10 replaces |

Device permission: location (when-in-use) requested only after the citizen taps "Use my location", with rationale "Saarthee uses your location once to find your ward. It is not stored."

### 5.6 Assumptions

- ASSUMPTION: `GET /wards` and `GET /geo/locate` return the shapes in §5.3 — TASK-02 is not written yet and TASK-03 must not depend on it — if TASK-02 differs, change only `WardsRepository` mapping and its fixture `test/fixtures/wards.json`.
- ASSUMPTION: No bundled ward list. When the API is unavailable and nothing is cached, the citizen can skip; Home and My Ward then show "Set your ward" — a bundled list would drift from TASK-02's boundary-versioned data.
- ASSUMPTION: The Report tab is a placeholder between TASK-03 and TASK-05 and the v1 six-step CCRS-first report flow is deleted now — D11 retires the v1 pilot constructs and Spec §8 replaces the flow; keeping it would force translating ~55 keys that TASK-05 deletes. The dev build cannot report in that window (milestone V2-M2).
- ASSUMPTION: The v1 admin console (`/admin/*`) stays, restyled to the new tokens, and its `admin*` keys are kept and translated to Gujarati — v1 admin email login stays (Spec §7) and REQ-N-005 says every string; TASK-10 may later delete keys it no longer uses.
- ASSUMPTION: Key retention rule — after the retired screens are deleted, a key is kept only if referenced in `lib/` (checked by `tool/l10n/unused_keys.dart`); expected outcome: ~105 retired keys deleted (`report*`, `verify*`, `invite*`, `welcome*`, v1 `home*`, v1 `status*` words), ~280 kept (`admin*`, `common*`, `error*`, `photo*`, `about*`, `global*`, `appTitle`), plus ~170 new v2 keys.
- ASSUMPTION: The account half of REQ-F-006 is delivered through the `PreferenceSync` port; this task verifies the port is called (T-03-14) and TASK-04 verifies `PATCH /me` is sent — the account does not exist before TASK-04.
- ASSUMPTION: Fonts are subset to Basic Latin, Latin-1 Supplement, General Punctuation, ₹ (U+20B9), Gujarati block U+0A80–U+0AFF, danda U+0964–U+0965, ZWJ/ZWNJ, with all OpenType layout features kept — Gujarati conjuncts need GSUB/GPOS; Devanagari is not bundled (phase 3).
- ASSUMPTION: Golden tests run only on the CI image (Linux) and are tagged `golden`; developers on macOS update them with `--update-goldens` inside the same container — goldens differ across platforms.
- ASSUMPTION: Gujarati copy is drafted by the implementer and marked `"x-review": "pending"` in `@` metadata for the native editor review (Open Question #5) — no Gujarati string blocks this task.

## 6. Implementation Steps

1. **Baseline and test setup.** Run `flutter analyze` and record the v1 baseline. Use plain `matchesGoldenFile` (no extra golden package); add `test/flutter_test_config.dart` that loads the bundled fonts with `FontLoader` so goldens render real glyphs.
2. **Fonts.** Add `apps/mobile/tool/fonts/subset_fonts.sh` (pyftsubset with the unicode ranges in §5.6, `--layout-features='*' --flavor=` none, output `assets/fonts/NotoSans-{Regular,Medium,SemiBold}.ttf`, `NotoSansGujarati-{Regular,Medium,SemiBold}.ttf`); commit TTFs + `assets/fonts/OFL.txt`; declare families `NotoSans` and `NotoSansGujarati` with weights 400/500/600 in `pubspec.yaml`; register the OFL licence with `LicenseRegistry` in `main.dart`.
3. **Tokens.** Rewrite `lib/core/theme/tokens.dart` per §5.2 (light + dark, status, severity, category, spacing, radii, motion, elevation). Delete v1 names (`ink`, `indigo`, `marigold`, …).
4. **Typography.** `lib/core/theme/typography.dart`: `TextTheme` with the DS §3 roles (size, weight, `height = lineHeight / size`), `fontFamily: 'NotoSans'`, `fontFamilyFallback: ['NotoSansGujarati']`; no letter-spacing; minimum 12 sp enforced by a test.
5. **ThemeData.** Rewrite `app_theme.dart`: `AppTheme.light()` / `AppTheme.dark()` from the tokens — `ColorScheme` mapping (primary, onPrimary white, surface, error…), component themes (FilledButton, OutlinedButton, TextButton, InputDecoration, Chip, NavigationBar, AppBar, Card with 0 elevation + 1 px border, BottomSheet radius 16, Dialog, SnackBar), `visualDensity: standard`, `materialTapTargetSize: padded`, focus colour `focusRing`. Add `themeModeProvider` persisted as `v2.themeMode`.
6. **Contrast tests first.** `test/theme/contrast_test.dart` computes WCAG ratios for every text/background pair in light and dark (text ≥ 4.5, large text and non-text UI ≥ 3.0) and fails with the pair name. Adjust dark tints if any pair fails and record the final hex values in the test.
7. **No-literal guard.** `test/theme/no_color_literals_test.dart` scans `lib/**.dart` except `lib/core/theme/` for `Color(0x`, `Colors.` (except `Colors.transparent`) and `fontSize:` literals; fails listing file:line.
8. **Components.** Build the §5.4 widgets in `lib/core/widgets/` (replace v1 `buttons.dart`, `errors.dart`, `notices.dart`, `offline_banner.dart`, `status_chip.dart`, `step_scaffold.dart`, `photos.dart`, `choice_card.dart` — keep file names where the API stays, delete the rest). Every interactive widget sets `Semantics(label:…)`/`tooltip` and ≥ 48 dp constraints.
9. **Gallery.** `lib/features/dev/gallery_screen.dart` with sections per component and toolbar toggles (theme, `gu`/`en`, text scale 1.0/1.3/2.0). Register `/dev/gallery` only when `kDebugMode` (`if (kDebugMode) GoRoute(...)`).
10. **Restyle survivors.** Migrate `features/admin/**` (incl. `admin_tokens.dart` → semantic tokens), `about_screen.dart`, `global_error.dart` to the new tokens/components until T-03-03 passes.
11. **Retire v1 citizen constructs (D11).** Delete `features/onboarding/` (invite + welcome), `features/verify/`, `features/report/`, `router/citizen_routes.dart`, verify handling in `router/deep_links.dart` (keep the listener file only if another link type remains; otherwise delete it and its provider read in `app.dart`); remove `inviteCode`/`groupLabel` from `AppSettings` and the invite field from `event_queue.dart`; migrate stored prefs per §5.2. Keep `lib/core/capture/`.
12. **Locale.** `lib/core/settings/locale_controller.dart`: `localeProvider` (Notifier<Locale>) reading/writing `v2.languageCode`, calling `PreferenceSync.languageChanged`; `MaterialApp.router(locale: ref.watch(localeProvider), supportedLocales: [gu, en])`. Add `LanguageToggle` to `SaartheeAppBar`.
13. **Home ward.** `lib/core/wards/`: models, `WardsRepository` (dio, timeout, retry, cache), `homeWardProvider` (persisted, calls `PreferenceSync.homeWardChanged`), `wardsListProvider` (AsyncValue with cache fallback), `locateWardProvider` (geolocator → `/geo/locate`). Add `preferenceSyncProvider` bound to `NoopPreferenceSync`.
14. **Router + shell.** Replace `app_router.dart`: redirect to `/onboarding/language` until `v2.onboardingDone`; `StatefulShellRoute.indexedStack` with five `StatefulShellBranch`es each with its own `navigatorKey`; `ShellScaffold` with `SaartheeNavigationBar`; re-tapping the current tab pops that branch to its root (`goBranch(i, initialLocation: i == current)`); `/admin/*` routes unchanged outside the shell; `/me/settings`, `/about`, `/error` as root-navigator routes. Keep the portrait lock for citizen routes.
15. **Placeholders.** `lib/features/shell/placeholders.dart` with `PlaceholderSection`/`PlaceholderScreen`; place P-01…P-09 exactly as in §5.4. Home: ward header (`homeWardProvider`, or "Set your ward" row → picker), "Report an issue" primary button → `goBranch(2)`.
16. **Onboarding screens.** `lib/features/onboarding/presentation/{language,intro,ward}_screen.dart` and `ward_picker_sheet.dart` with every state in §5.4; location rationale; geolocator permission handling ("Open settings" via `Geolocator.openAppSettings()`); set `v2.onboardingDone` on finish or skip.
17. **Settings and About.** `lib/features/settings/presentation/settings_screen.dart` (language, appearance, home ward); rewrite `about_screen.dart` with v2 copy.
18. **ARB.** Run `tool/l10n/unused_keys.dart` → delete unreferenced keys from `app_en.arb`; add all new keys (nav, onboarding, ward, settings, about, components, placeholders, errors for ward loading); create `app_gu.arb` with every key; set `l10n.yaml` `untranslated-messages-file: build/untranslated.json`, `preferred-supported-locales: [gu]`. Add `test/l10n/arb_parity_test.dart` (same key set and same placeholders in both files, no empty values) and CI step `flutter gen-l10n && test "$(cat build/untranslated.json)" = "{}"`.
19. **Hard-coded string guard.** `test/l10n/no_hardcoded_strings_test.dart`: scans `lib/features/**` and `lib/core/widgets/**` for `Text('` / `Text("` / `label: '` / `tooltip: '` string literals with letters; allow-list only `lib/features/dev/`.
20. **Widget and golden tests.** Write T-03-04…T-03-20 (§8). Goldens under `test/goldens/` for each component in light/dark × en/gu, plus 2.0× scale for buttons, list rows, issue card, alert card, step header.
21. **Static + CI.** `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` (and `--tags golden` on CI). Add the Flutter test job to the CI workflow from TASK-01 (or create `.github/workflows/mobile.yml` if TASK-01 has not landed).
22. **Manual checks** M-03-01…M-03-07 on the emulator; record screenshots in `docs/demo/evidence/v2/task-03/`.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Language-first onboarding
- **Given** a fresh install with device locale `en-IN`
- **When** the app opens
- **Then** `/onboarding/language` shows both titles in their own scripts and "English" pre-highlighted; tapping "ગુજરાતી" re-renders the screen in Gujarati immediately; Continue leads to the intro in Gujarati

**AC-2** — Intro with independence line
- **Given** the intro screen in either language
- **When** it is shown
- **Then** the wordmark, tagline, three benefit rows and the independence line ("Independent citizen app. Not run by or linked to AMC." / Gujarati equivalent) are visible, with no AMC logo or AMC colours

**AC-3** — Home ward by GPS
- **Given** location permission granted and `/geo/locate` returning Ward 12 Paldi with `confirm:false`
- **When** the citizen taps "Use my location" and then "Yes, continue"
- **Then** `v2.homeWard` stores Ward 12, `v2.onboardingDone` is true, the shell opens on Home with "Ward 12 · Paldi" in the app bar subtitle; with `confirm:true` the "just outside" wording is shown instead

**AC-4** — Home ward by picker and degrade path
- **Given** `/wards` returns 48 wards in 7 zones (then: the API unreachable with a cache; then unreachable without a cache)
- **When** the citizen opens "Choose from list" and searches "pal" / "12"
- **Then** results are grouped by zone and filtered by name or number; with a cache the list shows plus the offline banner; without a cache the error state offers "Try again" and "Skip for now", and skipping completes onboarding with no home ward and Home shows "Set your ward"

**AC-5** — Location denied
- **Given** location permission denied permanently
- **When** "Use my location" is tapped
- **Then** "Location is off. You can choose your ward from the list instead." appears with "Open settings" and "Choose from list"; no crash, onboarding can still finish

**AC-6** — Five-tab shell keeps state per tab
- **Given** onboarding done
- **When** the citizen scrolls Home, switches to Alerts, then back to Home; and pushes a child route in My Ward (`/me/settings` from the My Ward branch) then switches tabs and back
- **Then** Home keeps its scroll offset, My Ward still shows the pushed page, labels are always visible, the Report tab icon is filled, and re-tapping the active tab returns it to its root

**AC-7** — Instant language switch everywhere
- **Given** the app in English on the Alerts tab with `/me/settings` open in My Ward
- **When** the citizen selects ગુજરાતી in settings or taps the app-bar "અ" toggle
- **Then** every visible string, the nav labels and date formats switch to Gujarati without restart or navigation loss; `v2.languageCode` = `gu` after relaunch; `PreferenceSync.languageChanged('gu')` was called once

**AC-8** — Tokens only
- **Given** the full `lib/` tree
- **When** T-03-03 runs
- **Then** no `Color(0x…)`, `Colors.*` (except transparent) or raw `fontSize` occurs outside `lib/core/theme/`, and no v1 token name (`indigo`, `marigold`, `ink`) remains

**AC-9** — Typography and 200 % text
- **Given** the gallery and the onboarding screens at text scale 2.0 on a 360×640 dp viewport in Gujarati
- **When** they render
- **Then** no overflow errors are thrown, no text is clipped, buttons grow in height rather than truncating, and Gujarati conjuncts render with the bundled Noto Sans Gujarati (golden)

**AC-10** — Component library and gallery
- **Given** a debug build
- **When** `/dev/gallery` is opened
- **Then** every component in §5.4 is shown in its states (default, pressed/selected, disabled, loading, error, empty, offline); in a profile build the route is not registered and navigating to it shows the router's not-found page

**AC-11** — Status and severity never by colour alone
- **Given** `StatusChip` for each of the 7 statuses and `SeverityChip`/`AlertCard` for each of the 4 severities
- **When** rendered in light and dark
- **Then** each shows its DS §2 icon and word in the current language, with the DS §2 colours (tint/solid) and the critical alert as a solid banner with white text

**AC-12** — Accessibility guidelines
- **Given** the shell, onboarding screens and gallery
- **When** the Flutter accessibility guideline matchers run
- **Then** `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline` pass; semantics traversal order equals visual order on onboarding; `StepHeader` announces "Step 2 of 3"; `ErrorSummary` takes focus when shown

**AC-13** — Dark theme
- **Given** theme set to Dark (or System with the device in dark mode)
- **When** shell, onboarding and gallery render
- **Then** the DS §2 dark palette is used, all contrast pairs pass T-03-02, and status/severity remain icon + word

**AC-14** — Complete bilingual ARB
- **Given** `app_en.arb` and `app_gu.arb`
- **When** `flutter gen-l10n` and T-03-17/T-03-18 run
- **Then** both files have identical key sets and placeholders, `build/untranslated.json` is `{}`, no retired v1 key (`invite*`, `welcome*`, `verify*`, v1 `report*`) remains, and no hard-coded user-facing string exists in `lib/features` or `lib/core/widgets`

**AC-15** — v1 constructs retired, admin intact
- **Given** an install upgraded from v1 with `inviteCode` stored and an unfinished v1 report draft
- **When** the v2 build starts
- **Then** the app opens onboarding (v2 flag absent), the v1 keys and draft are removed from storage, no invite/verify/report-v1 route exists, and `/admin/login` still works with the v1 admin credentials in the new style

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

### 7.2 Non-Functional Checklist

- [ ] All DS §2 token pairs (light and dark) meet AA in T-03-02
- [ ] Every interactive element ≥ 48×48 dp and labelled; focus ring visible (`focusRing`) on keyboard/switch access
- [ ] Motion 150–200 ms; all transitions disabled when "Remove animations" is on (`MediaQuery.disableAnimations`)
- [ ] No full-screen spinners; skeletons for lists
- [ ] Subset fonts total ≤ 1.2 MB; APK size increase recorded in §13
- [ ] Cold start to onboarding/Home ≤ 3 s on the emulator in profile mode (measured; re-measured on a low-end phone in TASK-14)
- [ ] No AMC logo, seal, bronze/amber/navy-gradient colours anywhere (visual check of gallery)
- [ ] Location used once for ward lookup, not stored or sent anywhere except `/geo/locate`
- [ ] Screens import providers only; no dio calls in `presentation/`
- [ ] `dart format`, `flutter analyze` clean; `flutter test` green incl. goldens on CI

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-03-01 | `dart format --set-exit-if-changed .`, `flutter analyze` | Code quality gate |
| Unit | T-03-01 | Token values equal DS §2 hex for every named token, status, severity and category | AC-8, AC-11 |
| Unit | T-03-02 | WCAG contrast of every text/background and non-text pair, light and dark | AC-12, AC-13 |
| Unit | T-03-03 | No colour/font-size literals or v1 token names outside `lib/core/theme/` | AC-8 |
| Unit | T-03-04 | `TextTheme` roles: sizes, weights, line heights per DS §3; no size < 12; fallback includes Gujarati | AC-9 |
| Widget | T-03-05 | Buttons: loading disables and shows progress; heights 48/56; semantics label | AC-10, AC-12 |
| Widget | T-03-06 | `LabeledTextField` optional suffix, helper, error row; `ErrorSummary` takes focus and links move focus | AC-10, AC-12 |
| Widget | T-03-07 | `StatusChip` × 7 and `SeverityChip` × 4: icon + localized word in en and gu | AC-11 |
| Widget | T-03-08 | `ListRow`, `IssueCard`, `StatusTimeline`, `AlertCard`, `RepresentativeRow`, `PhotoThumb` render with required semantics | AC-10 |
| Widget | T-03-09 | `EmptyState`, `SkeletonList`, `ErrorState` ("Try again" callback), `NoticeBanner` variants | AC-10 |
| Golden | T-03-10 | Goldens for all components: light/dark × en/gu; 2.0× for buttons, rows, cards, step header | AC-9, AC-11, AC-13 |
| Widget | T-03-11 | Gallery route present with `kDebugMode`, absent when the gallery flag is false (router built with `enableGallery:false`) | AC-10 |
| Widget | T-03-12 | Shell: 5 destinations with labels; tab state preserved (scroll offset, pushed child); re-tap pops to root | AC-6 |
| Widget | T-03-13 | Onboarding language: device-locale preselect, switching re-renders, persisted `v2.languageCode` | AC-1 |
| Widget | T-03-14 | Settings language switch + app-bar toggle: whole tree in gu, `PreferenceSync.languageChanged` called once (fake) | AC-7 |
| Widget | T-03-15 | Ward step with fake repository: GPS success, `confirm:true`, denied, 422 outside city, API down with/without cache, skip | AC-3, AC-4, AC-5 |
| Widget | T-03-16 | Ward picker search by name/number, zone grouping, no-match message | AC-4 |
| Unit | T-03-17 | ARB parity: same keys, placeholders, non-empty values; no retired prefixes | AC-14 |
| Unit | T-03-18 | No hard-coded strings in `lib/features`, `lib/core/widgets` | AC-14 |
| Widget | T-03-19 | Accessibility guidelines (tap target, labelled targets, text contrast) on shell, onboarding, gallery; traversal order | AC-12 |
| Widget | T-03-20 | v1 prefs migration: `inviteCode`/draft keys removed, onboarding shown; admin login route resolves | AC-15 |
| Manual | M-03-01 | Fresh install on emulator: full onboarding in Gujarati with GPS (Ahmedabad location) against a TASK-02 API if available, else with API stopped (degrade + skip) | AC-1…AC-5 |
| Manual | M-03-02 | TalkBack on onboarding and shell: reading order, labels, "Step n of 3" in gallery | AC-12 |
| Manual | M-03-03 | Settings → Font size largest + Display size largest: onboarding, Home, settings, gallery; no clipping | AC-9 |
| Manual | M-03-04 | Dark mode system toggle; theme setting overrides | AC-13 |
| Manual | M-03-05 | Upgrade install over a v1 build with an invite code and draft | AC-15 |
| Manual | M-03-06 | Profile build: `/dev/gallery` not reachable; release APK size noted | AC-10 |
| Manual | M-03-07 | Language switch on each tab with a pushed page; state kept | AC-6, AC-7 |

## 9. Deliverables

- Civic Blue tokens, typography, `AppTheme.light/dark`, theme-mode setting.
- Subset Noto Sans + Noto Sans Gujarati TTFs, OFL licence, subset script.
- Component library (§5.4) and debug-only `/dev/gallery`.
- Five-tab `StatefulShellRoute` shell with the placeholder register P-01…P-09.
- Onboarding v2 (language, intro, ward with GPS/picker/degrade), settings, About.
- `localeProvider`, `homeWardProvider`, `WardsRepository`, `PreferenceSync` port.
- Cleaned `app_en.arb`, complete `app_gu.arb`, l10n CI checks.
- Flutter unit, widget, golden and accessibility tests T-03-01…T-03-20; CI job.
- Coverage matrix evidence for 9 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/mobile/pubspec.yaml` | Modified (fonts, assets) |
| `apps/mobile/assets/fonts/*.ttf`, `assets/fonts/OFL.txt` | New |
| `apps/mobile/tool/fonts/subset_fonts.sh`, `tool/l10n/unused_keys.dart` | New |
| `apps/mobile/l10n.yaml` | Modified |
| `apps/mobile/lib/core/theme/{tokens,typography,app_theme,theme_mode}.dart` | Rewritten / New |
| `apps/mobile/lib/core/widgets/*.dart` | Rewritten / New |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified / New |
| `apps/mobile/lib/core/settings/{app_settings,locale_controller,preference_sync}.dart` | Modified / New |
| `apps/mobile/lib/core/wards/` | New |
| `apps/mobile/lib/router/{app_router,shell_routes}.dart` | Rewritten / New |
| `apps/mobile/lib/router/{citizen_routes,deep_links}.dart` | Deleted (deep_links if no link type remains) |
| `apps/mobile/lib/features/{onboarding,shell,settings,dev}/` | Rewritten / New |
| `apps/mobile/lib/features/{verify,report}/`, `features/onboarding/*invite*` | Deleted |
| `apps/mobile/lib/features/home/presentation/` | Rewritten (Home placeholder, About) |
| `apps/mobile/lib/features/admin/presentation/**` | Modified (tokens only) |
| `apps/mobile/lib/app.dart`, `lib/main.dart` | Modified (locale, theme mode, licence) |
| `apps/mobile/test/**`, `test/goldens/**`, `test/flutter_test_config.dart`, `test/fixtures/wards.json` | New |
| `.github/workflows/mobile.yml` (or TASK-01 CI file) | New / Modified |

## 11. Related Documentation

- `docs/v2/design-system.md` DS §1 (identity, independence line), §2 (tokens), §3 (type), §4 (shape, spacing, icons, motion), §5 (components), §6 (accessibility), §8 (screen inventory)
- `docs/v2/saarthee-v2-spec.md` §2 D1, D4, D6, D11; §8 routes and navigation
- `docs/tasks-v2/TASK-02-*.md` — ward endpoints (contract consumer)
- `docs/tasks-v2/TASK-04-accounts-privacy-push.md` — `PreferenceSync` implementation
- `docs/02-frontend-spec.md` — v1 frontend (superseded where v2 differs)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Gujarati shaping wrong after subsetting (missing GSUB features) | Broken conjuncts, unreadable text | Keep all layout features; golden with conjunct test strings ("ક્ષ", "દ્ર", "શ્રી") |
| Golden tests flaky across OS | CI noise | Linux-only goldens, bundled fonts loaded in test config |
| TASK-02 ward contract differs | Onboarding ward step breaks | Single mapper + fixture; degrade path always available |
| Deleting the v1 report flow leaves dev builds without reporting until TASK-05 | Demo gap | Documented; TASK-05 is next on the core lane |
| Large ARB rewrite causes missed strings | Mixed-language screens | Parity + untranslated + hard-coded-string tests in CI |
| Machine-quality Gujarati copy | Trust and comprehension | `x-review: pending` metadata; native editor before TASK-14 |
| Dark-theme tints fail AA | Accessibility regression | T-03-02 blocks merge; adjust tints and record |

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
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-03` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-03: …`
- [ ] Validator passes
