# TASK-03: Mobile Foundation, Design System & Onboarding

| Field | Value |
|---|---|
| Task ID | TASK-03 |
| Status | In Progress |
| Priority | P0 |
| Size | L |
| Depends On | TASK-01, TASK-02 |
| Blocks | TASK-04, TASK-05 |
| Requirement IDs | REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008, REQ-F-009, REQ-F-010, REQ-F-011, REQ-F-012, REQ-F-013, REQ-N-001, REQ-N-002, REQ-N-003, REQ-N-004, REQ-N-005, REQ-N-006, REQ-N-007, REQ-N-008, REQ-N-009, REQ-N-010, REQ-N-011, REQ-N-012, REQ-N-013, REQ-N-014, REQ-N-015, REQ-N-020, REQ-N-021, REQ-N-022, REQ-S-014, REQ-S-022, REQ-S-028, REQ-O-011 |
| Primary Spec Refs | 02-frontend-spec.md §1, §2, §3, §4.1–4.3, §5, §7, §9; 03-backend-spec.md §2.1, §2.2, §10, §11; 05-devops-infrastructure.md §2.2, §4.6 |
| Last Updated | 2026-10-03 |

## 1. Objective

Create the Flutter app (`apps/mobile`) that every later feature plugs into: configuration, API client, router, localization, the "indigo and marigold" design system with all shared components, global error handling and the analytics event queue. On top of that foundation, deliver the first working citizen slice — welcome, install ID, invite code (with the backend `POST /invite-codes/validate`), Home and About — plus the backend `POST /events` endpoint. At the end, a citizen can install the app, join a group by code (or skip), and land on Home, and events reach the `events` table.

## 2. Scope

### In Scope
- Flutter project in `apps/mobile` (Android + iOS) with Riverpod, router (*candidate* go_router), HTTP client (*candidate* dio), `flutter_lints`, `dart format`.
- Feature-folder structure `lib/core/*`, `lib/features/<feature>/{data,application,presentation}`, `lib/router` (02 §1.2).
- Build-time config via `--dart-define` and committed run configurations per target.
- API client: base URL from config, standard headers, request ID, 15 s / 60 s timeouts, typed `AppError` from the backend error shape.
- Localization: `flutter_localizations` + ARB with code generation; English only; every string in ARB.
- Theme from design tokens; typography scale; bundled fonts (Anek after licence check, else Noto); spacing, radii, icon and motion rules.
- Shared components (02 §1.3) including `BeforeAfterCard` (full, compact, citizen-check variants; images passed in as `ImageProvider`s so later tasks supply them).
- Single route table matching 02 §3.1 for **all** routes; screens not built yet render a clearly labelled placeholder.
- Global error handler, offline banner, error-code → message mapping (incl. Retry-After).
- Platform config: debug-only cleartext exception (Android debug network security config; iOS ATS exception in Debug only); citizen flows portrait-locked.
- Onboarding: welcome + install ID, invite code screen (validate, skip, invalid/offline states), Home, About (incl. "Change group code" and operator-login link).
- Analytics: `eventQueueProvider` (batching, cap) and backend `POST /events` with allow-list.
- Backend `POST /invite-codes/validate`; rate limits for `/invite-codes/validate`, `/events`, `/health`, `/categories` route group.
- Mobile CI job (from TASK-01) runs green against the real app.

### Out of Scope
- Report flow screens, `GET /categories` handler, draft store, "Continue your report" behaviour — TASK-04 (rate limit for `/categories` is set here so the route group exists; handler lands in TASK-04).
- Admin login screen and admin shell — TASK-05 (About links to `/admin/login`, which is a placeholder until then).
- Verify screens including `/verify/enter-code` — TASK-07 (Home "Answer a follow-up" routes to the placeholder until then).
- Admin data sources for `BeforeAfterCard` images — TASK-06/07/08.
- Device runs on physical phones and accessibility audit with TalkBack/VoiceOver end to end — TASK-10.

## 3. Prerequisites

- TASK-01 complete: API skeleton (config validation, logger with redaction, error format, request ID, rate-limit middleware, `/health`), CI workflow with a mobile job.
- TASK-02 complete: `invite_codes` and `events` tables, seed with one invite code per source tag.
- Flutter SDK (stable), Android Studio with an emulator; `flutter doctor` passes for Android. Xcode only if checking iOS simulator now (optional here; required in TASK-10).
- Font licence decision: check Anek (Latin, Gujarati, Devanagari) licence (believed SIL OFL), coverage and size; fall back to Noto Sans family if unclear.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | Provides the Express app, error/rate-limit/validation middleware, logger redaction, `/health`, and the CI mobile job |
| TASK-02 | Provides the `invite_codes` and `events` tables and seeded invite codes used by the validate endpoint |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-001 | Welcome screen with the two-sentence purpose and independence notice on first launch | 02 §4.1 |
| REQ-F-002 | A random install ID (UUID) is generated and stored on first launch | 02 §4.1, 03 §2.1 |
| REQ-F-003 | Invite code screen: uppercase letters/digits 6–20, validates via API, stores code and group label locally, shows "You're part of {groupLabel}", handles invalid/offline states, emits `invite_code_entered {valid}` | 02 §4.2 |
| REQ-F-004 | `POST /invite-codes/validate` returns `{valid, groupLabel}`; case-insensitive lookup; inactive or unknown → 404 `INVITE_CODE_INVALID` | 03 §2.2 |
| REQ-F-005 | "I don't have a code" skips to Home with no code stored | 02 §4.2 |
| REQ-F-006 | "Change group code" from About re-runs the invite screen | 02 §4.2 |
| REQ-F-007 | Home: independence notice, "Record a complaint" (or "Continue your report" when a draft exists), "Answer a follow-up", About link | 02 §4.3, §3.3 |
| REQ-F-008 | About screen: about, privacy, independence and the operator login link (admin entry not on Home) | 02 §3.1, §3.2 |
| REQ-F-009 | `POST /events` accepts batches of ≤ 50, keeps only allow-listed names and properties, returns 202 `{accepted}` | 03 §2.2, §11 |
| REQ-F-010 | App event queue: flush at 20 events, on background, every 60 s; capped at 500 (oldest dropped); drops instead of retrying forever on 429 | 02 §7, 03 §10 |
| REQ-F-011 | Global error handler: uncaught errors show "Something went wrong" with "Go home"; never clears the report draft | 02 §9.1 |
| REQ-F-012 | API errors converted to a typed app error by backend `code`; messages from ARB keyed by code; rate-limit messages show the Retry-After wait | 02 §5.3, §9.2 |
| REQ-F-013 | Offline banner "You're offline. Your answers are saved." with retry where relevant | 02 §9.2, §4.3 |
| REQ-N-001 | Material 3 theme built from the design tokens; no hard-coded colours in screens | 02 §2.1 |
| REQ-N-002 | Typography scale; Anek (or Noto fallback) fonts bundled after licence/coverage check, only used weights | 02 §2.1, §8.2 |
| REQ-N-003 | Spacing (4-pt), radii hierarchy, no card shadows, Material Symbols Rounded with labels, motion respects reduce-motion | 02 §2.1 |
| REQ-N-004 | Layouts work 320–480 px; > 480 centered at max 560; citizen flows portrait-locked, admin rotates | 02 §2.2 |
| REQ-N-005 | Touch targets ≥ 48×48; primary buttons full-width ≥ 56 tall, pinned above keyboard | 02 §2.3, §3.3 |
| REQ-N-006 | Every screen works at the largest system text size; no fixed-height text containers | 02 §2.3 |
| REQ-N-007 | Screen-reader semantics: labels, photo descriptions, "Step n of N" announced, errors announced | 02 §2.3 |
| REQ-N-008 | Never colour alone: statuses, errors and selections always carry icon and/or text | 02 §2.1, §2.3 |
| REQ-N-009 | Focus order follows visual order; focus moves to the error summary on failed submit | 02 §2.3 |
| REQ-N-010 | All user-facing strings in ARB files with code generation (English v1); layouts tolerate ~40% longer text | 02 §2.4 |
| REQ-N-011 | Dates/times in IST in device-locale format; phone shown as +91 98765 43210 | 02 §2.4 |
| REQ-N-012 | HTTP timeouts: 15 s JSON, 60 s photo uploads | 02 §5.3 |
| REQ-N-013 | `StepScaffold` "one decision per screen" layout with Back and "Step n of N" | 02 §2.0, §3.3 |
| REQ-N-014 | Validation on "Continue", then live re-validation; inline errors in `notFixed` colour with icon; shared validators | 02 §6 |
| REQ-N-015 | Loading patterns: skeletons, button progress (disabled while sending), upload progress bar, no full-screen spinner except verify entry | 02 §9.3 |
| REQ-N-020 | Shared components: `StepScaffold`, `PrimaryButton`, `SecondaryButton`, `ChoiceCard`, `EvidencePhoto`, `StatusChip`, `ErrorSummary`, `InlineFieldError`, `IndependenceNotice`, `EmptyState`, `OfflineBanner` | 02 §1.3 |
| REQ-N-021 | `BeforeAfterCard` signature component (full, compact, citizen check variant) with status stamp; correct at 320 wide | 02 §2.5 |
| REQ-N-022 | Feature folders `data` / `application` / `presentation`; screens never call the API directly | 02 §1.2 |
| REQ-S-014 | Event properties never contain phone numbers, tokens, invite codes, coordinates or notes; unknown names/properties ignored | 03 §11, 04 §3.8 |
| REQ-S-022 | Rate limits: `/invite-codes/validate` 30/IP/h; `/events` 120/IP/min; `/health` + `/categories` 120/IP/min | 03 §10 |
| REQ-S-028 | Plain-HTTP exception only for the dev machine and only in debug builds; absent from release | 05 §4.6, 06 §4.1 |
| REQ-O-011 | Flutter build config via `--dart-define` plus committed run configurations per target | 05 §2.2, 01 §9.3 |

### 5.2 Data Contracts

No schema changes. Reads/writes (tables from TASK-02, `docs/04-database-design.md §3.2, §3.8`):
- `invite_codes`: read `code` (stored uppercase; compare case-insensitively by uppercasing input), `group_label`, `is_active`.
- `events`: insert `name`, `install_id`, `admin_user_id` (null here), `complaint_id` (null for app events), `source_tag` (null), `properties` (JSONB, allow-listed), `platform`, `app_version`, `occurred_at` (device time), `received_at` (default NOW()).

Local device storage (shared_preferences *candidate*): `installId` (UUID v4), `inviteCode`, `groupLabel`, `onboardingDone`, and the capped event queue (JSON list, ≤ 500).

### 5.3 API Contracts

Common headers sent by the app on every citizen call (03 §2.1): `X-Install-Id`, app version header, platform header (`android`/`ios`), request-ID header. Error shape: `{error:{code,message,details?,requestId}}`.

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| POST | `/api/v1/invite-codes/validate` | None | `{code}` — 6–20 letters/digits | 200 `{valid:true, groupLabel}` | 400 `VALIDATION_FAILED`, 404 `INVITE_CODE_INVALID` (unknown **or** inactive), 429 `RATE_LIMITED` | 30 per IP per hour |
| POST | `/api/v1/events` | None | `{events:[{name, occurredAt, properties?, …}]}` max 50 | 202 `{accepted}` | 400, 429 | 120 per IP per minute |
| GET | `/api/v1/health` | None | — | `{status, db}` (TASK-01) | 503 | 120 per IP per minute (shared with `/categories`) |

Event allow-list (03 §11). App-sent names accepted here: `invite_code_entered {valid}`, `report_opened` (no props), `ccrs_handoff_clicked {target: web|whatsapp|call}`, `deep_link_failed {reason}`. Server-only names (`report_submitted`, `reminder_sent`, `verify_opened`, `verify_submitted`, `record_flagged`) must be **ignored** if sent by the app. Unknown names and unlisted properties are dropped silently; `accepted` = count actually stored. Install ID, platform and app version come from headers.

### 5.4 UI Surfaces & States

Design tokens (02 §2.1) — the only colour source:

| Token | Hex | Token | Hex |
|---|---|---|---|
| `ink` | #1B2433 | `fieldBorder` | #7A849B |
| `inkMuted` | #55607A | `divider` | #C9CEDB (decorative only) |
| `indigo` | #2B3F87 | `marigold` | #F2B233 (fill with `ink` text, never as text) |
| `indigoDark` | #1E2C61 | `fixed` / `fixedTint` | #1D6B43 / #E2F1E8 |
| `indigoTint` | #E6E9F5 | `notFixed` / `notFixedTint` | #A8321F / #F8E4E0 |
| `surface` | #F6F7FB | `waitingTint` | #FDF1D6 |
| `white` | #FFFFFF | | |

Type scale: Display 28/34 Semibold · Title 22/28 Semibold · Body large 18/26 · Body 16/24 · Label 16/20 Medium · Caption 14/20 (never smaller). Sentence case. Spacing 4/8/12/16/24/32/48; screen padding 20. Radii: inputs/buttons 12, cards/photos 16, bottom sheets 24 top, chips fully rounded. No card shadows. Material Symbols Rounded 24 px with text labels in citizen flows.

| Screen / component | States |
|---|---|
| `/welcome` (02 §4.1) | Static. Copy: "Check that complaints to AMC really get fixed." / "You file your complaint with AMC as usual. This app records it, and in about a week asks you whether it was fixed. This is an independent app. It is not run by or linked to AMC." "Continue" → `/invite` |
| `/invite` (02 §4.2) | Default; checking (button progress, disabled); invalid → inline "That code didn't work. Check it with whoever shared it."; offline → `OfflineBanner` with retry or skip; rate-limited → wait message from Retry-After; success → "You're part of {groupLabel}" briefly → Home. Secondary "I don't have a code" |
| `/` Home (02 §4.3) | `IndependenceNotice`; card "Record a complaint" (→ `/report/category` placeholder until TASK-04); card "Answer a follow-up" (→ `/verify/enter-code` placeholder until TASK-07); About link; offline banner |
| `/about` | About text, privacy summary, independence notice, "Change group code" (→ `/invite`), "Operator login" (→ `/admin/login`, placeholder until TASK-05) |
| Global error screen | "Something went wrong" + "Go home"; draft storage untouched |
| `BeforeAfterCard` | full / compact thumbnail pair / citizen-check; "before only" variant; status stamp in status colour + icon + word (✓ Fixed, ✕ Not fixed, ⏳ Waiting); placeholder when a photo is missing/deleted |
| `StatusChip` | fixed / not fixed / waiting / filed / reminded — always icon + word |
| Placeholder screen (temporary) | "Coming in TASK-NN" label, Back; must be removed by the named task |

### 5.5 Permissions & Roles

| Action | Citizen (no token) | Admin | Unauthorized behaviour |
|---|---|---|---|
| Validate invite code | ✅ | ✅ | — (public, rate-limited) |
| Send analytics events | ✅ | ✅ | — (public, rate-limited, allow-listed) |
| Reach admin screens | Link only (About) | ✅ (TASK-05) | Router guard added in TASK-05 |

### 5.6 Assumptions

- ASSUMPTION: Header names `X-App-Version`, `X-Platform`, `X-Request-Id` — 03 §2.1 names `X-Install-Id` only and describes the others generically — must match whatever TASK-01 implemented; align with TASK-01 if different.
- ASSUMPTION: Event item shape `{name, occurredAt, properties?, complaintId?}` — 03 §2.2 says only `{events:[…]}` — adjust both sides together if the backend task chose otherwise.
- ASSUMPTION: Placeholder screens for routes owned by later tasks — keeps a single route table now — each owning task replaces them; TASK-10 greps for remaining placeholders.
- ASSUMPTION: Invite code is uppercased in the field as typed, non-alphanumerics rejected client-side — 02 §4.2 "shown uppercase" — loosen if real codes contain other characters (they cannot per 04 §3.2).
- ASSUMPTION: Network connectivity detection via a connectivity plugin (*candidate*) plus request failures — spec specifies the banner, not the mechanism — swap if unreliable.

## 6. Implementation Steps

1. **Backend: invite validate.** Add module `src/modules/public` route `POST /invite-codes/validate`: Zod schema (`code` 6–20 alnum), service uppercases input and looks up `invite_codes` where `is_active = true`; unknown/inactive → `INVITE_CODE_INVALID` 404; return `{valid:true, groupLabel}`. Apply 30/IP/h limiter.
2. **Backend: events.** Add module `src/modules/events` `POST /events`: schema max 50 items; service filters by the app-sent allow-list and per-event property allow-list (`valid` boolean, `target` enum, `reason` short string); reads install ID/platform/version from headers; bulk insert; returns 202 `{accepted}`. Apply 120/IP/min limiter. Never log properties.
3. **Backend: limiters** for `/health` and the `/categories` path (120/IP/min) using the TASK-01 rate-limit middleware.
4. **Flutter project.** `flutter create` in `apps/mobile` (org id per founder), add Riverpod, *candidates* go_router, dio, shared_preferences, uuid, connectivity — verify each on pub.dev; enable `flutter_lints` (or stricter); create the 02 §1.2 folder tree.
5. **Config.** `lib/core/config`: read `APP_ENV`, `API_BASE_URL`, `DEEP_LINK_SCHEME`, `CCRS_WEB_URL`, `CCRS_WHATSAPP_NUMBER`, `AMC_HELPLINE` from `String.fromEnvironment`; fail fast in debug if `API_BASE_URL` empty. Commit run configurations (VS Code `launch.json` and/or scripts) for Android emulator (`http://10.0.2.2:4000/api/v1`), iOS simulator (`http://localhost:4000/api/v1`) and LAN phone (`http://<LAN-IP>:4000/api/v1` placeholder).
6. **Platform config.** Android: `res/xml/network_security_config.xml` permitting cleartext only for `10.0.2.2` and the dev LAN IP, referenced from the **debug** manifest only. iOS: ATS exception for the dev address in the Debug configuration only. Lock citizen routes to portrait (orientation set per route; admin routes allow rotation).
7. **Localization.** Enable `flutter_localizations` + `generate: true`, `lib/core/l10n/app_en.arb`; add every string for this task plus a message for each backend error code in 03 §9.1. Set up IST date formatting and `+91 98765 43210` phone display helpers in `core/utils`.
8. **Theme.** `lib/core/theme`: token constants, `ColorScheme`/`ThemeData` (Material 3) from tokens, text theme from the scale, radii and spacing constants, `NoShadow` card theme; reduced-motion aware page transitions. Bundle fonts (Regular, Medium, Semibold only) after the licence check; record the choice in §13.
9. **API client.** `lib/core/api`: dio instance, interceptor adding standard headers (install ID from settings, app version, platform, fresh request ID), timeouts 15 s JSON / 60 s multipart, converter from error JSON → `AppError(code, message, details, requestId, retryAfter)`; network failure → `AppError.offline`.
10. **Shared components.** Build all REQ-N-020 widgets plus `BeforeAfterCard` with semantics (labels, photo descriptions, "Step n of N" live region, error announcements), 48 px targets, primary button full width ≥ 56 pinned above keyboard, no fixed-height text containers. Add shared form validators and the "validate on Continue, then live" behaviour helper.
11. **Error handling.** `FlutterError.onError` + `PlatformDispatcher.instance.onError` + zone: debug logs, release → global error screen with "Go home". Never touches draft storage. Error-code → ARB mapping with Retry-After wait formatting.
12. **Router.** `lib/router`: one route table with every route of 02 §3.1; placeholders for routes owned by TASK-04/05/07/08/09; first-launch redirect (`onboardingDone` false → `/welcome`).
13. **Settings provider.** `appSettingsProvider` (installId, inviteCode, groupLabel, onboardingDone; `setInviteCode`, `clearInviteCode`, `completeOnboarding`). Generate installId on first launch.
14. **Event queue.** `eventQueueProvider` with `track` and `flush`: persisted, capped at 500 (drop oldest), flush at 20 queued, on app background, every 60 s while open; on 429 drop the batch (no infinite retry); on network error keep.
15. **Onboarding screens.** Welcome, Invite (data layer → notifier → screen), success flash, skip; `invite_code_entered {valid}` tracked.
16. **Home and About** with `IndependenceNotice`, action cards, offline banner, "Change group code", "Operator login" link.
17. **CI.** Ensure the TASK-01 mobile job (`flutter pub get`, `dart format --set-exit-if-changed`, `dart analyze`) passes on the real project.
18. **Manual verification** per §8; record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — First launch onboarding
- **Given** a fresh install
- **When** the app opens
- **Then** `/welcome` shows the draft copy and independence notice, a UUID install ID is stored, and "Continue" opens `/invite`

**AC-2** — Valid invite code
- **Given** seeded active code `RWA…` (any case typed)
- **When** the citizen enters it and taps Continue
- **Then** the button shows progress and is disabled, the API returns 200 `{valid:true, groupLabel}`, "You're part of {groupLabel}" appears, code and label are stored, Home opens, and `invite_code_entered {valid:true}` is queued

**AC-3** — Invalid or inactive code
- **Given** an unknown code or a code with `is_active=false`
- **When** it is submitted
- **Then** the API returns 404 `INVITE_CODE_INVALID` and the screen shows "That code didn't work. Check it with whoever shared it." inline with an icon, announced to the screen reader

**AC-4** — Skip and change code
- **Given** the invite screen
- **When** "I don't have a code" is tapped
- **Then** Home opens with no code stored; and **when** About → "Change group code" is used later, **then** the invite screen runs again and replaces the stored code

**AC-5** — Home and About
- **Given** onboarding is complete
- **When** Home is shown
- **Then** it shows the independence notice, "Record a complaint", "Answer a follow-up" and an About link, with no admin entry; About shows privacy/independence text and an "Operator login" link

**AC-6** — Offline and rate-limited
- **Given** the device is offline (or the API returns 429 with `Retry-After`)
- **When** the citizen submits a code
- **Then** the offline banner "You're offline. Your answers are saved." with retry/skip appears (or the wait time from Retry-After is shown), never a blank screen

**AC-7** — Events endpoint allow-list
- **Given** a batch of 3 events: `invite_code_entered {valid:true, phone:"+91…"}`, `report_submitted`, `made_up_event`
- **When** posted to `/events`
- **Then** response is 202 `{accepted:1}`, the stored row has properties `{valid:true}` only, and a batch of 51 returns 400 `VALIDATION_FAILED`

**AC-8** — Event queue behaviour
- **Given** the queue holds events
- **When** 20 accumulate, the app is backgrounded, or 60 s elapse
- **Then** a flush is sent; the queue never exceeds 500 (oldest dropped); a 429 drops the batch rather than retrying forever

**AC-9** — Typed errors and global handler
- **Given** any API error response or an uncaught exception
- **When** it reaches the app
- **Then** API errors surface as the ARB message for their `code`, and uncaught errors show "Something went wrong" with "Go home" without clearing local storage

**AC-10** — Rate limits
- **Given** one IP
- **When** it sends 31 validate requests in an hour (or 121 `/events` / `/health` requests in a minute)
- **Then** the extra request returns 429 `RATE_LIMITED` with a `Retry-After` header

**AC-11** — Config and debug-only cleartext
- **Given** the committed run configurations
- **When** the app is run on the Android emulator with the emulator configuration
- **Then** it reaches `http://10.0.2.2:4000/api/v1/health`; and a release build's merged manifest / Info.plist contains no cleartext exception

**AC-12** — Design system and components
- **Given** the component gallery (debug-only route) or the onboarding screens
- **When** viewed at 320 px width, at the largest system text size, and in grayscale
- **Then** nothing is cut off, every status/selection/error shows an icon or word, all colours come from tokens, targets are ≥ 48 px, and `BeforeAfterCard` renders all variants correctly at 320 wide

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-001, REQ-F-002 |
| AC-2 | REQ-F-003, REQ-F-004, REQ-N-015 |
| AC-3 | REQ-F-003, REQ-F-004, REQ-N-007, REQ-N-008, REQ-N-014 |
| AC-4 | REQ-F-005, REQ-F-006 |
| AC-5 | REQ-F-007, REQ-F-008 |
| AC-6 | REQ-F-013, REQ-F-012 |
| AC-7 | REQ-F-009, REQ-S-014 |
| AC-8 | REQ-F-010 |
| AC-9 | REQ-F-011, REQ-F-012 |
| AC-10 | REQ-S-022 |
| AC-11 | REQ-O-011, REQ-S-028, REQ-N-012 |
| AC-12 | REQ-N-001, REQ-N-002, REQ-N-003, REQ-N-004, REQ-N-005, REQ-N-006, REQ-N-007, REQ-N-008, REQ-N-009, REQ-N-010, REQ-N-011, REQ-N-013, REQ-N-020, REQ-N-021, REQ-N-022 |

### 7.2 Non-Functional Checklist

- [ ] No `Color(0x…)` or `Colors.*` literals outside `lib/core/theme` (grep check)
- [ ] No user-facing string literals in `lib/features/**` or `lib/core/widgets/**` (grep for quoted text in `Text(`)
- [ ] Fonts bundled with only Regular/Medium/Semibold; licence recorded in §13
- [ ] Every screen in this task usable at 320 px and at the largest text size; citizen screens portrait-locked
- [ ] Touch targets ≥ 48×48; primary button ≥ 56 tall, pinned above keyboard
- [ ] TalkBack reads labels for every control on welcome, invite, home, about; error announced on invalid code
- [ ] Screens import only providers — no `dio`/API client imports in `presentation/` (grep check)
- [ ] Event payloads never contain phone, token, invite code, coordinates or notes (server allow-list verified)
- [ ] Validate and events handlers log nothing beyond the request line; redaction from TASK-01 intact
- [ ] Invite button disabled while checking (no double submit)
- [ ] Release build contains no cleartext exception
- [ ] Reduced-motion setting disables step transitions

## 8. Validation & Testing

| Level | What to test | ACs |
|---|---|---|
| Static | `npm run typecheck && npm run lint` in `apps/api`; `dart format --set-exit-if-changed .` and `dart analyze` in `apps/mobile`; CI both jobs green | all |
| API manual M-03-01 | `curl -X POST $API/invite-codes/validate -H 'Content-Type: application/json' -d '{"code":"<seeded code lowercase>"}'` → 200 `{valid:true,groupLabel}`; unknown → 404 `INVITE_CODE_INVALID`; `{"code":"ab"}` → 400 with `details` | AC-2, AC-3 |
| DB manual M-03-02 | `UPDATE invite_codes SET is_active=false WHERE code='…'` then repeat validate → 404 | AC-3 |
| API manual M-03-03 | POST `/events` with the mixed batch of AC-7 → 202 `{accepted:1}`; 51-event batch → 400; `SELECT name, properties FROM events ORDER BY id DESC LIMIT 3` shows only allowed props | AC-7 |
| API manual M-03-04 | Loop 31 validate calls / 121 `/health` calls → last returns 429 + `Retry-After` | AC-10, AC-6 |
| App manual M-03-05 | Fresh emulator install → welcome → invite valid code → Home; check shared_preferences has installId/inviteCode | AC-1, AC-2, AC-5 |
| App manual M-03-06 | Invalid code; skip; About → Change group code; About → Operator login reaches placeholder | AC-3, AC-4, AC-5 |
| App manual M-03-07 | Airplane mode at invite step → banner + retry/skip; restore network → retry works | AC-6 |
| App manual M-03-08 | Trigger a debug-only throw button (removed before commit or debug-gated) → global error screen; trigger events, background app → `events` rows appear | AC-8, AC-9 |
| App manual M-03-09 | Component gallery at 320 px, largest font, grayscale (Android developer option), TalkBack pass on onboarding | AC-12 |
| Build manual M-03-10 | `flutter build apk --release` and inspect merged manifest (no cleartext config); iOS Release Info.plist has no ATS exception | AC-11 |
| Optional automated | Not applicable — no 06 §8.1 test targets this task | — |

## 9. Deliverables

- Flutter app scaffold in `apps/mobile` with config, router, API client, l10n, theme, fonts, shared components, error handling, event queue.
- Onboarding, Home and About screens; placeholders for later routes.
- Backend `POST /invite-codes/validate`, `POST /events`, rate limits for public route groups.
- Run configurations for emulator, simulator and LAN phone.
- Android debug network security config; iOS Debug ATS exception.
- Green mobile CI job.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/mobile/` (pubspec, `analysis_options.yaml`, `l10n.yaml`, `assets/fonts/`) | New |
| `apps/mobile/lib/core/{config,api,theme,l10n,analytics,widgets,utils}/` | New |
| `apps/mobile/lib/features/{onboarding,home}/` and `lib/features/about` (or within home) | New |
| `apps/mobile/lib/router/` | New |
| `apps/mobile/android/app/src/debug/` (manifest, `res/xml/network_security_config.xml`) | New |
| `apps/mobile/ios/Runner/` (Info.plist / Debug xcconfig) | Modified |
| `.vscode/launch.json` or `apps/mobile/scripts/run-*.sh` | New |
| `apps/api/src/modules/public/`, `apps/api/src/modules/events/` | New / Modified |
| `apps/api/src/app.ts` (route + limiter registration) | Modified |
| `.github/workflows/*` | Modified only if the mobile job needs fixes |

## 11. Related Documentation

- `docs/02-frontend-spec.md §1.1–1.3` — stack, folder structure, component list
- `docs/02-frontend-spec.md §2.1–2.5` — tokens, sizes, accessibility, i18n, `BeforeAfterCard`
- `docs/02-frontend-spec.md §3.1–3.3` — route table, navigation, layouts
- `docs/02-frontend-spec.md §4.1–4.3` — welcome, invite, home copy and states
- `docs/02-frontend-spec.md §5.2–5.3, §7, §9` — providers, data fetching, analytics batching, error UX
- `docs/03-backend-spec.md §2.1–2.2, §9.1, §10, §11` — conventions, endpoints, error codes, rate limits, events
- `docs/05-devops-infrastructure.md §2.2, §4.6` — dart-defines and platform config

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Candidate packages outdated or unmaintained | Rework later | Verify each on pub.dev before adding; record versions |
| Anek licence/coverage unclear | Font swap later | Decide now; Noto fallback is safe |
| Design system scope grows into polish | Task overruns | Build only the listed components; gallery is debug-only |
| Placeholders forgotten | Broken paths in pilot | Placeholders labelled with owning task; TASK-10 grep |
| Event schema mismatch with TASK-01 conventions | Events dropped | Align header names with TASK-01 before wiring |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-03` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-03: …`
- [ ] Validator passes
