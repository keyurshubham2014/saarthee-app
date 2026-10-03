# TASK-04: Citizen Accounts, Privacy & Push Foundation

| Field | Value |
|---|---|
| Task ID | TASK-04 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-01, TASK-03 |
| Blocks | TASK-05, TASK-08, TASK-09, TASK-10, TASK-12 |
| Requirement IDs | REQ-F-007, REQ-F-008, REQ-F-009, REQ-F-010, REQ-F-011, REQ-S-001, REQ-S-003, REQ-S-004, REQ-S-005, REQ-S-015, REQ-O-003 |
| Primary Spec Refs | Spec §2 (D6, D8, D9), §3, §6 (`users`, `consents`, `devices`, `notifications`), §7 (Auth & me), §9, §11; DS §5, §8 |
| Last Updated | 2026-10-03 |

## 1. Objective

Give citizens an identity only when they need one, and give the platform a way to reach them. A visitor browses freely; the moment they tap an action that needs an account (report, Me too, follow, verify, message, RSVP — D6) the app asks for their phone, verifies it with a Firebase OTP, confirms they are 18 or older, and returns them to the exact action. The API verifies the Firebase ID token and issues its own session JWT carrying a token version. Citizens can see and edit their profile, give and withdraw purpose-specific consents, export their data and delete their account (issues anonymised, their photos deleted). Each install registers its FCM token, subscribes to its home-ward and city topics, and the API gets one push service (FCM HTTP v1) with a delivery log that every later task uses. Logs never contain OTPs, Firebase tokens, FCM tokens or message bodies.

## 2. Scope

### In Scope
- Firebase setup documentation `docs/v2/firebase-setup.md` (project, Android app, SHA-1/SHA-256, phone auth, test numbers, service account, FCM) — no secrets in git.
- API: `firebase-admin` integration behind a `FirebaseGateway` interface (verify ID token, delete user, send messages); `POST /auth/firebase`, `POST /auth/logout`; citizen session JWT; `requireUser`, `optionalUser`, `requireRole(...)` middleware; `GET/PATCH /me`; `POST /me/consents`; `GET /me/export`; `DELETE /me`; `POST /devices`; push service (`notifyTopic`, `notifyUser`) with drivers `fcm`, `log`, `memory`; `notifications` table and `push:flush` script; export/erasure section registries for later tasks.
- Migration adding auth columns to `users`, constraints on `devices`, and the `notifications` table.
- Logger redaction extended (REQ-S-015) and a redaction test.
- App: `firebase_core`, `firebase_auth`, `firebase_messaging`, `flutter_local_notifications`; session store; dio auth interceptor with silent re-exchange; `ensureSignedIn()` "sign in when needed" helper with return-to-action; `/sign-in`, `/sign-in/otp`, `/sign-in/age`, `/sign-in/blocked`; `/me` profile; `/me/privacy` (consents, export, delete, grievance contact); `PreferenceSync` implementation (language + home ward → `PATCH /me`, topic re-subscription); FCM token registration and topic subscriptions; notification channels, foreground display and tap routing; replaces placeholder P-09.
- Vitest + Supertest tests for every endpoint in this task; Flutter widget tests for sign-in, profile and privacy screens.

### Out of Scope
- Notification inbox UI, read state, alert kinds, quiet-hour policy and alert subscriptions — TASK-08 (extends `notifications`).
- Staff role management UI and authorisation of staff endpoints — TASK-10 (this task only provides `requireRole`).
- Issue, verification, message and RSVP data in export/erasure — each owning task registers its section (§5.2).
- Retention jobs (notifications 90 days etc.) — TASK-13.
- Moving admins from email/password to OTP — v1 admin login stays (Spec §7).
- iOS APNs key setup — REQ-O-090 deferred; iOS kept buildable only.

## 3. Prerequisites

- TASK-01: `users`, `consents`, `devices` tables (REQ-D-003), role enum, Vitest + Supertest harness with a test database (`npm test`), v2 seed.
- TASK-03: tokens/components, five-tab shell, `localeProvider`, `homeWardProvider`, `PreferenceSync` port, placeholder P-09.
- Founder action (Open Question #3): Firebase project created by the project owner; Android app `in.saarthee.app` (or the current `applicationId`) registered with debug and release SHA-1/SHA-256; Phone sign-in enabled; two Firebase test phone numbers configured.
- Local files (git-ignored): `apps/mobile/android/app/google-services.json`, `apps/mobile/lib/firebase_options.dart` (from `flutterfire configure`), `apps/api/secrets/firebase-service-account.json`.
- API env: `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (path to the service account JSON), `USER_JWT_AUDIENCE=saarthee-app`, `USER_JWT_EXPIRES_IN=30d`, `PUSH_DRIVER=log|fcm|memory`, `CONSENT_TEXT_VERSIONS_V2=v2-1`, `GRIEVANCE_EMAIL`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | `users`/`consents`/`devices` tables, Prisma v2 schema, test harness, seed with sample citizens |
| TASK-03 | Design system components, shell and placeholder P-09, locale and home-ward providers, `PreferenceSync` port |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-007 | Phone OTP sign-in (Firebase Authentication) shown only when an action needs an account; returns to the action after sign-in | Spec D6, D8 |
| REQ-F-008 | `POST /auth/firebase` exchanges a verified Firebase ID token for a Saarthee session JWT; `POST /auth/logout` | Spec §7 |
| REQ-F-009 | `GET/PATCH /me` (display name, language, home ward); profile screen | Spec §7, §8 |
| REQ-F-010 | `POST /devices` registers the FCM token per install and user; topic subscription for home ward and `city_all` | Spec §9 |
| REQ-F-011 | Server push service (FCM HTTP v1) for topics and individual tokens, with a delivery log in `notifications` | Spec §9 |
| REQ-S-001 | Firebase ID tokens verified server-side (signature, audience, issuer, expiry); session JWT with token version | Spec D8 |
| REQ-S-003 | Purpose-specific consent records (core, share with representatives, AMC hand-off, notifications) with withdrawal | Spec §11 |
| REQ-S-004 | Data export (`GET /me/export`) and account deletion (`DELETE /me`) that anonymises issues and deletes the person's photos | Spec §11 |
| REQ-S-005 | Under-18 users blocked with an age confirmation at sign-in | Spec §11 |
| REQ-S-015 | v1 logging redaction extended to OTP, Firebase tokens, FCM tokens and message bodies | Spec §11 |
| REQ-O-003 | Firebase project configuration documented (Android app, SHA fingerprints, service account for the API) without committing secrets | Spec D8 |

### 5.2 Data Contracts

Migration `apps/api/prisma/migrations/<ts>_v2_auth_push_foundation/` (new; never edit TASK-01's migrations):

- `users`: add `token_version INT NOT NULL DEFAULT 0`, `age_confirmed_at TIMESTAMPTZ NULL`, `deleted_at TIMESTAMPTZ NULL`; make `phone_e164` and `firebase_uid` nullable if TASK-01 created them NOT NULL (UNIQUE stays; NULLs allowed for deleted users); CHECK `status <> 'deleted' OR (phone_e164 IS NULL AND firebase_uid IS NULL)`.
- `devices`: UNIQUE `install_id`; index `(user_id)`; `fcm_token` nullable; add `language VARCHAR(2) NOT NULL DEFAULT 'gu'` CHECK in (`gu`,`en`); `topics TEXT[] NOT NULL DEFAULT '{}'` (last reported by the app, diagnostic only).
- `consents`: index `(user_id, purpose)`; CHECK purpose in (`core_service`,`share_with_representatives`,`share_with_amc_handoff`,`notifications`) if not already an enum.
- `notifications` (new, created here — see §5.6):

| Column | Type | Notes |
|---|---|---|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID NULL → users ON DELETE SET NULL | per-user sends |
| device_id | UUID NULL → devices ON DELETE SET NULL | single-device sends (rare) |
| topic | TEXT NULL | base topic (`ward_12`, `city_all`) for topic sends |
| kind | TEXT NOT NULL CHECK in (`alert`,`issue_update`,`initiative`,`system`) | |
| ref_id | TEXT NULL | id of alert/issue/initiative |
| route | TEXT NULL | in-app route opened on tap, e.g. `/issues/<id>` |
| title_en, title_gu | TEXT NOT NULL (≤ 120) | |
| body_en, body_gu | TEXT NOT NULL (≤ 400) | never logged |
| status | TEXT NOT NULL CHECK in (`queued`,`sent`,`partial`,`failed`,`no_device`) | |
| send_after | TIMESTAMPTZ NULL | deferred sends (quiet-hour policy set by caller) |
| sent_at | TIMESTAMPTZ NULL | |
| provider_message_ids | TEXT[] NOT NULL DEFAULT '{}' | FCM message names |
| error_code | TEXT NULL | e.g. `messaging/registration-token-not-registered` |
| read_at | TIMESTAMPTZ NULL | used by TASK-08 |
| created_at | TIMESTAMPTZ NOT NULL DEFAULT now() | |

Indexes: `(user_id, created_at DESC)`, `(status, send_after) WHERE status = 'queued'`, `(kind, ref_id)`.

Session JWT (HS256, `JWT_SECRET`): claims `sub` = user id, `tv` = token_version, `role`, `typ: "user"`, `iss` = `JWT_ISSUER`, `aud` = `USER_JWT_AUDIENCE` (different from the admin audience so admin and citizen tokens are never interchangeable), `exp` = `USER_JWT_EXPIRES_IN`.

Export/erasure registries (`src/modules/me/privacy.registry.ts`): `registerExportSection(name, (userId, tx) => Promise<unknown>)` and `registerErasureStep(name, (userId, tx, ctx) => Promise<void>)`. This task registers `profile`, `consents`, `devices` (no tokens), `notifications`; and, because TASK-01 creates them, `issues` (own reports: id, category, status, created_at, ward, description), `me_toos`, `follows`, `issue_verifications`. Later tasks register theirs (TASK-09 `rep_messages`, TASK-12 `rsvps`).

Erasure workflow (`DELETE /me`, one transaction, then storage deletions after commit):
1. Collect photo ids uploaded by the user (report photos of their issues, their verification photos).
2. Issues they reported: `description = NULL`, photos detached (`issue_photos` rows of kind `report` removed), `reporter_id` kept pointing at the anonymised user row; status, category, location, ward and counts kept (aggregate kept, Spec §11).
3. Delete their `me_toos`, `follows` (counts on issues unchanged — aggregate), `devices`; verifications: keep answer/distance/time, set photo NULL.
4. Consents: set `withdrawn_at = now()` where null (records kept as evidence of past consent).
5. `users`: `phone_e164 = NULL`, `firebase_uid = NULL`, `display_name = NULL`, `home_ward_id = NULL`, `status = 'deleted'`, `deleted_at = now()`, `token_version = token_version + 1`.
6. Run registered erasure steps; write audit entry `user.deleted` (actor = self, no PII).
7. After commit: `storage.delete(key)` for each photo (missing key = success), mark `photos.deleted_at`; `FirebaseGateway.deleteUser(uid)`; failures logged with photo id only and retried by `photos:cleanup`.

### 5.3 API Contracts

New error codes in `src/lib/errors`: `AUTH_REQUIRED` 401 "Please sign in to continue.", `FIREBASE_TOKEN_INVALID` 401 "We couldn't confirm your sign-in. Please try again.", `AGE_CONFIRMATION_REQUIRED` 403 "You need to be 18 or older to use an account.", `CONSENT_REQUIRED` 422 "Please agree to the terms to continue.", `CORE_CONSENT_REQUIRED` 409 "This consent is needed for your account. To withdraw it, delete your account.", `ACCOUNT_SUSPENDED` 403 "This account is suspended.", `FORBIDDEN` 403 "You don't have permission to do this.", `WARD_NOT_FOUND` 422 "Please choose your ward again.", `FIREBASE_UNAVAILABLE` 503. Existing `TOKEN_EXPIRED`/`TOKEN_REVOKED` reused.

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| POST | `/api/v1/auth/firebase` | None | `{idToken, ageConfirmed, consents:[{purpose,textVersion}], language, homeWardId?, installId?}` | 201 new / 200 existing `{accessToken, expiresAt, user:Me, isNew}` | 400, 401 `FIREBASE_TOKEN_INVALID`, 403 `AGE_CONFIRMATION_REQUIRED`/`ACCOUNT_SUSPENDED`, 422 `CONSENT_REQUIRED`/`WARD_NOT_FOUND`, 429, 503 | 10/IP/min, 30/IP/h |
| POST | `/api/v1/auth/logout` | User | `{installId?}` | 204 | 401 | 30/user/h |
| GET | `/api/v1/me` | User | — | 200 `Me` | 401 | 120/user/min |
| PATCH | `/api/v1/me` | User | `{displayName?, language?, homeWardId?}` (at least one) | 200 `Me` | 400, 401, 422 `WARD_NOT_FOUND` | 30/user/h |
| POST | `/api/v1/me/consents` | User | `{purpose, granted, textVersion}` | 200 `{consents:[…]}` | 400, 401, 409 `CORE_CONSENT_REQUIRED` | 30/user/h |
| GET | `/api/v1/me/export` | User | — | 200 JSON, `Content-Disposition: attachment; filename="saarthee-my-data-<yyyy-mm-dd>.json"` | 401 | 3/user/day |
| DELETE | `/api/v1/me` | User | `{confirm:"DELETE"}` | 204 | 400, 401 | 3/user/day |
| POST | `/api/v1/devices` | Optional user | `{installId, fcmToken?, platform, appVersion, language, topics?[]}` | 200 `{deviceId}` | 400, 429 | 30/IP/h |

`Me` = `{id, displayName|null, phoneMasked ("+91 ••••• ••210"), language, role, homeWard:{id, number, nameEn, nameGu}|null, consents:[{purpose, granted, textVersion, grantedAt, withdrawnAt}], createdAt}`. Phone is never returned unmasked.

`POST /auth/firebase` workflow:
1. Zod: `idToken` string ≤ 4,096; `ageConfirmed` boolean; `consents` must include `core_service` with `textVersion` in `CONSENT_TEXT_VERSIONS_V2`; `language` `gu|en`.
2. `FirebaseGateway.verifyIdToken(idToken, checkRevoked=true)` — signature against Google certs, `aud` = `FIREBASE_PROJECT_ID`, `iss` = `https://securetoken.google.com/<project>`, `exp`/`iat`/`auth_time` sane; require `firebase.sign_in_provider = 'phone'` and `phone_number` present. Any failure → 401 `FIREBASE_TOKEN_INVALID` (cause logged as code only). Firebase unreachable → 503.
3. Find user by `firebase_uid`; else by `phone_e164` (relink uid); else new.
4. Existing suspended → 403. New user and `ageConfirmed !== true` → 403 `AGE_CONFIRMATION_REQUIRED`, nothing stored. Existing user without `age_confirmed_at` → same rule.
5. Transaction: create/update user (`language`, optional `home_ward_id` validated, `age_confirmed_at` on first confirm, `last_seen_at`); insert consent rows for purposes granted and not currently active; link `devices.user_id` by `installId` if present.
6. Sign session JWT; return 201/200. Audit `user.signed_in` with user id only.

`POST /auth/logout`: increments `token_version` (signs out every device — §5.6), sets `devices.user_id = NULL` for `installId`; 204.

`requireUser`: Bearer → verify HS256 + `iss` + `aud = USER_JWT_AUDIENCE` + `typ = user` → load user → `status = active` and `tv` equal → `req.user = {id, role, language, homeWardId}`; expired → 401 `TOKEN_EXPIRED`; version mismatch or deleted → 401 `TOKEN_REVOKED`; suspended → 403. `optionalUser` sets `req.user` when a valid token is present, ignores a missing one, and rejects an invalid one with 401. `requireRole(...roles)` → 403 `FORBIDDEN`.

`POST /me/consents`: `granted:false` sets `withdrawn_at` on the active row; `granted:true` inserts a new row; `core_service` withdrawal → 409. Withdrawing `notifications` also clears `fcm_token` on the user's devices server-side (app unsubscribes topics, §5.4).

Push service (`src/lib/push/`):
```ts
interface PushMessage { kind: 'alert'|'issue_update'|'initiative'|'system'; refId?: string; route?: string;
  title: { en: string; gu: string }; body: { en: string; gu: string };
  channel: 'critical_alerts'|'alerts'|'updates'; sendAfter?: Date }
notifyTopic(baseTopic: string, msg: PushMessage): Promise<NotificationRow>   // sends to `${base}__gu` and `${base}__en`
notifyUser(userId: string, msg: PushMessage): Promise<NotificationRow>      // all devices with fcm_token; user's language
flushQueued(now: Date): Promise<number>                                      // used by `npm run push:flush`
```
- Topic names: `ward_<number>`, `zone_<code>`, `cat_<slug>`, `city_all` (D9) with a language suffix `__gu` / `__en` (§5.6). Base topic validated `^[a-z0-9_]{1,60}$`.
- FCM driver uses `firebase-admin` `messaging().send()` / `sendEach()` (HTTP v1). Android: `priority: high` for `critical_alerts` and `alerts`, `notification.channelId` = channel, `data = {kind, refId, route}`.
- `sendAfter` in the future → row `queued`; `push:flush` (cron every 5 min, configured in TASK-13) sends due rows.
- Token errors `registration-token-not-registered` / `invalid-argument` → set that device's `fcm_token = NULL`.
- Row status: `sent` (all ok), `partial`, `failed`, `no_device` (user has no token; row kept so the inbox still shows it). Log line: `{notificationId, kind, topic|userId, status, okCount, failCount}` — never title/body/tokens.
- Drivers: `fcm` (staging/production), `log` (local default, records rows only), `memory` (tests; exposes `sent[]`).

Redaction (REQ-S-015): extend `SENSITIVE` in `src/lib/logger` with `idToken`, `accessToken`, `refreshToken`, `fcmToken`, `otp`, `code`, `verificationId`, `body`, `body_en`, `body_gu`, `message`, `phone_e164`, `phoneNumber`; redact headers `authorization`, `x-firebase-token`; firebase-admin errors logged as `{code}` only.

### 5.4 UI Surfaces & States

| Route | Content | States |
|---|---|---|
| `/sign-in?from=<location>` | Title "Sign in with your phone"; reason line from caller, e.g. "To report an issue, please sign in."; field "Mobile number" with fixed "+91" prefix, numeric keypad; helper "We'll send a 6-digit code by SMS."; primary "Send code" | Invalid number → inline "Enter a valid 10-digit Indian mobile number."; sending → in-button progress; `too-many-requests` → "Too many attempts. Please try again later."; offline → offline banner, button disabled |
| `/sign-in/otp` | "Enter the 6-digit code sent to +91 98765 43210"; 6-digit field (autofill `oneTimeCode`, SMS auto-retrieval on Android); "Resend code" enabled after 30 s countdown; "Change number" | Wrong code → "That code is not right. Check the SMS and try again."; expired → "This code has expired. Send a new one."; verifying → progress |
| `/sign-in/age` (new account only) | "Are you 18 or older?" + "Saarthee accounts are for adults (18+)." Buttons "Yes, I am 18 or older" / "No"; consent box: "I agree that Saarthee stores my phone number and the reports I make to run this service." with link "Privacy notice"; primary "Create account" disabled until ticked | Server 403/422 mapped to inline errors |
| `/sign-in/blocked` | "Sorry, you need to be 18 or older to have an account. You can still browse issues, alerts and services." primary "Back to browsing" | Firebase user signed out, nothing stored |
| `/me` (from My Ward row, replaces P-09) | Signed out: row "Sign in" + why. Signed in: display name (editable, "(optional)", 1–40 chars), masked phone, home ward (Change → picker), language, links "Privacy and your data", "Settings", "Sign out" | Loading skeleton; error + "Try again"; save in progress; offline: read-only with banner |
| `/me/privacy` | Notice summary (en/gu); consent switches: "Share my reports with representatives", "Hand-off details when I file with AMC", "Notifications" (core consent shown as fixed "Needed for your account"); "Download my data" (shares the JSON file via share sheet); "Delete my account" (red, secondary); grievance contact "Questions or complaints about your data: {GRIEVANCE_EMAIL}"; independence line | Toggle in flight → disabled; export generating → progress; error → snackbar + retry |
| Delete dialog | "Delete your account?" body: "Your phone number and name are removed, your photos are deleted and your reports stay public without your details. This cannot be undone." Type "DELETE" field; buttons "Delete account" / "Cancel" | Deleting → progress; success → signed out, Home, snackbar "Your account was deleted." |

"Sign in when needed" (`lib/features/auth/application/ensure_signed_in.dart`):
```dart
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref, {required SignInReason reason});
```
Returns immediately `true` if a valid session exists; otherwise pushes `/sign-in?from=<current location>` on the root navigator and awaits the result; on success pops back to the caller's route with state intact so the calling action continues (e.g. Me too is sent). Deep-linked routes that need an account use a router redirect to `/sign-in?from=` and `context.go(from)` after success. `from` must be an in-app path (starts with `/`, no scheme) — otherwise `/`.

Session handling: access token in `flutter_secure_storage`; dio interceptor adds `Authorization`; on 401 `TOKEN_EXPIRED` it calls `FirebaseAuth.currentUser.getIdToken(true)` and re-exchanges once, then retries; `TOKEN_REVOKED` or failed re-exchange → session cleared, Firebase signed out, current action asks to sign in again.

Push on device:
- Android 13+: `POST_NOTIFICATIONS` asked from a soft prompt card on Home after onboarding: "Get alerts for Ward 12?" "Turn on" / "Not now" (not at first launch).
- Channels: `critical_alerts` (max importance), `alerts` (high), `updates` (default), names localized.
- On start and on `onTokenRefresh`: `POST /devices` with current topics. Topics subscribed: `ward_<home>__<lang>` and `city_all__<lang>`; on home-ward or language change: unsubscribe old, subscribe new, re-post device (via `PreferenceSync`). Notifications consent withdrawn or permission denied → unsubscribe all.
- Foreground messages shown via `flutter_local_notifications`; taps (foreground, background, terminated via `getInitialMessage`) route to `data.route` only if it matches the allow-list `^/(issues|alerts|initiatives|me/notifications)(/[A-Za-z0-9-]+)?$`, else Home.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator / Admin / Representative | Notes |
|---|---|---|---|---|
| `POST /auth/firebase`, `POST /devices` | ✅ | ✅ | ✅ | devices links user when token present |
| `GET/PATCH /me`, consents, export, delete, logout | ❌ 401 | ✅ own only | ✅ own only | No user id in paths — cannot target others |
| Receive topic push | ✅ (device) | ✅ | ✅ | |
| Call `notifyTopic` / `notifyUser` | — | — | Server code only | No public endpoint |
| Change `users.role` | ❌ | ❌ | Admin only, TASK-10 | `PATCH /me` ignores `role` (strict Zod) |
| v1 `/admin/login` (email/password) | — | — | Admins | Unchanged (Spec §7) |

### 5.6 Assumptions

- ASSUMPTION: notifications table created here as push foundation; TASK-08 extends it (alerts kind, read state) — REQ-D-009 (TASK-08) owns the table but the push service (REQ-F-011) needs the delivery log first.
- ASSUMPTION: Topics carry a language suffix (`ward_12__gu`, `city_all__en`) — FCM notification messages cannot be localized on the device and data-only messages are dropped by aggressive OEM battery managers common in India; this keeps D9 base names and reliable delivery.
- ASSUMPTION: Logout increments `token_version`, signing out all devices — conservative for shared phones; a per-device session table can be added later if citizens complain.
- ASSUMPTION: Age check is a self-declaration (no birth date stored); answering "No" is not remembered, so a person could go back — Spec §11 asks for an age confirmation, not verification.
- ASSUMPTION: Session JWT lifetime 30 days with silent re-exchange of a fresh Firebase ID token on expiry — Firebase keeps the device signed in; shorter sessions would force OTP repeatedly (SMS cost).
- ASSUMPTION: Visitors receive ward topic pushes without an account once the OS permission is granted; a `notifications` consent row is created when they sign in — D6 lets visitors browse, and alerts are public information.
- ASSUMPTION: `google-services.json`, `firebase_options.dart` and the service-account JSON are git-ignored and distributed out of band (CI secrets in TASK-13); `firebase_options.example.dart` documents the shape — the brief forbids secrets in git and the API key, while not secret, ties builds to the project.
- ASSUMPTION: Consent text version `v2-1`; wording drafted here, legal review pending (Open Question #6).
- ASSUMPTION: Display name is never shown publicly (REQ-S-006); it is used only for staff views and representative relay when the citizen opts in.
- ASSUMPTION: If TASK-01 already created `token_version` or the devices constraints, the migration uses `ADD COLUMN IF NOT EXISTS` / `CREATE UNIQUE INDEX IF NOT EXISTS` and records which parts were no-ops in §13.

## 6. Implementation Steps

1. **Firebase setup doc.** Write `docs/v2/firebase-setup.md`: create project (owner = founder), add Android app with `applicationId`, add debug SHA-1/SHA-256 (`./gradlew signingReport`) and release/Play App Signing fingerprints (TASK-13), enable Phone provider, add test numbers, set SMS region policy to India only, create a service account with "Firebase Authentication Admin" + "Firebase Cloud Messaging API Admin", enable FCM HTTP v1 API, `flutterfire configure`, where each file lives locally, which env vars point to them, rotation, and the `.gitignore` entries. Add the entries to `.gitignore` and a CI check that fails if those files are tracked.
2. **Migration** `<ts>_v2_auth_push_foundation` per §5.2; update `schema.prisma`; `prisma generate`; typecheck.
3. **Errors and config.** Add error codes and env vars (Zod config, refuse to start with `PUSH_DRIVER=fcm` and no credentials).
4. **FirebaseGateway.** `src/lib/firebase/`: interface + `firebase-admin` implementation (pin exact version) + `FakeFirebaseGateway` for tests (issues fake tokens for given uid/phone/provider, can simulate revoked/expired/wrong audience).
5. **Session tokens.** `src/lib/tokens`: `signUserToken`, `verifyUserToken` (aud `USER_JWT_AUDIENCE`, `typ`). Make `verifyAdminToken` reject `typ:"user"` tokens; test both directions.
6. **Middleware.** `src/middleware/requireUser.ts` (`requireUser`, `optionalUser`), `requireRole.ts`.
7. **Auth module** `src/modules/auth`: `POST /auth/firebase` workflow §5.3, `POST /auth/logout`, rate limits.
8. **Me module** `src/modules/me`: `GET/PATCH /me` (ward existence check via `wards` when TASK-02 tables exist; until then `homeWardId` validated as UUID and FK enforced by DB), consents, export (registry), delete (erasure workflow §5.2 + post-commit storage/Firebase deletion).
9. **Devices module** `src/modules/devices`: upsert by `install_id`; clear the same `fcm_token` on other rows; link user when `optionalUser` present.
10. **Push service** `src/lib/push/` + drivers + `scripts/push-flush.ts` (`npm run push:flush`) + `scripts/push-test.ts` (`npm run push:test -- --topic ward_12` for manual checks, staff-only use).
11. **Redaction.** Extend logger paths per §5.3; add `test/logging.redaction.test.ts` that captures pino output during auth, devices and push calls and asserts no token, phone or body value appears.
12. **API tests** T-04-01…T-04-16 with Vitest + Supertest and the fake gateway / memory push driver.
13. **App packages.** Add `firebase_core`, `firebase_auth`, `firebase_messaging`, `flutter_local_notifications`, `share_plus` (pin exact versions); Gradle `google-services` plugin; `Firebase.initializeApp` in `main.dart` guarded so a missing config shows a developer error screen in debug and never crashes release.
14. **Auth feature** `lib/features/auth/`: data (`AuthApi`, `SessionStore`), application (`sessionProvider`, `phoneAuthController` wrapping `verifyPhoneNumber` with `codeSent`, `verificationCompleted`, `verificationFailed`, `codeAutoRetrievalTimeout`, resend token), `ensureSignedIn`, router redirect for account-only routes; screens `/sign-in`, `/sign-in/otp`, `/sign-in/age`, `/sign-in/blocked`. Reuse the v1 phone rule from `core/utils/validators.dart`.
15. **Dio interceptor** for Bearer + silent re-exchange; error mapping to ARB keys by code.
16. **Profile and privacy** `lib/features/me/`: `/me`, `/me/privacy`, delete dialog, export via `share_plus` (temp file in app cache, deleted after share). Replace placeholder P-09 with the `/me` row.
17. **PreferenceSync implementation** `AccountPreferenceSync`: when signed in `PATCH /me {language|homeWardId}`; always updates topic subscriptions and re-posts the device; override the TASK-03 provider. On sign-in, push device language and home ward if the account has none.
18. **Push client** `lib/core/push/`: permission soft prompt on Home, channels, token registration, topic manager, foreground display, tap routing with allow-list, background handler (top-level function).
19. **ARB** en + gu for every new string; parity test from TASK-03 passes.
20. **Flutter tests** T-04-17…T-04-22 with fakes for `FirebaseAuth` wrapper and API.
21. **Manual checks** M-04-01…M-04-07 on the emulator with a Firebase test number and a real FCM send; evidence to `docs/demo/evidence/v2/task-04/`.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Sign in when needed and return to the action
- **Given** a visitor on a screen with an account-only action (test harness button "Follow" calling `ensureSignedIn`)
- **When** they tap it, enter a Firebase test number and code, confirm age and consent
- **Then** they return to the same screen with its state intact and the action proceeds; browsing screens never asked for sign-in

**AC-2** — Firebase token exchange
- **Given** a valid Firebase ID token for a phone user
- **When** `POST /auth/firebase` is called with `ageConfirmed:true` and core consent `v2-1`
- **Then** 201 with `accessToken`, `user.phoneMasked`, `isNew:true`; a `users` row with `phone_e164`, `firebase_uid`, `age_confirmed_at`, a `consents` row; repeating returns 200 `isNew:false` and no duplicate user

**AC-3** — Invalid Firebase tokens rejected
- **Given** tokens that are expired, for another project (wrong `aud`), wrong `iss`, revoked, non-phone provider, or malformed
- **When** each is posted to `/auth/firebase`
- **Then** each returns 401 `FIREBASE_TOKEN_INVALID`, no user is created, and the log line has only the error code

**AC-4** — Under-18 blocked
- **Given** a new phone number
- **When** the citizen answers "No" to "Are you 18 or older?" (and separately when the API receives `ageConfirmed:false`)
- **Then** the app shows `/sign-in/blocked`, signs out of Firebase and creates nothing; the API returns 403 `AGE_CONFIRMATION_REQUIRED` and stores nothing

**AC-5** — Session JWT with token version
- **Given** a signed-in citizen
- **When** they call `POST /auth/logout`, then reuse the old token; and when an admin token is sent to `/me` or a user token to `/admin/*`
- **Then** logout returns 204 and the old token gets 401 `TOKEN_REVOKED`; cross-use of admin/user tokens is rejected with 401

**AC-6** — Profile read and edit
- **Given** a signed-in citizen
- **When** `GET /me` then `PATCH /me {displayName:"Asha", language:"en", homeWardId:<ward>}` (and an unknown ward, a 41-char name, a `role` field)
- **Then** `Me` reflects the change with masked phone; unknown ward → 422 `WARD_NOT_FOUND`; long name → 400; `role` → 400 (strict schema); the `/me` screen shows and edits the same fields

**AC-7** — Language and home ward reach the account
- **Given** a signed-in citizen
- **When** they switch language in settings or change home ward
- **Then** `PATCH /me` is sent once with the new value, the FCM topics switch (old unsubscribed, new subscribed) and `POST /devices` is re-sent with `language` and `topics`

**AC-8** — Consents with withdrawal
- **Given** a citizen with core and notifications consents
- **When** they switch off "Notifications" then on again, and try to withdraw `core_service` via the API
- **Then** the first sets `withdrawn_at` and unsubscribes topics, the second inserts a new row, history is kept; core withdrawal → 409 `CORE_CONSENT_REQUIRED`

**AC-9** — Data export
- **Given** a citizen with consents, a device and (seeded) issues, me-toos and follows
- **When** they tap "Download my data"
- **Then** `GET /me/export` returns a JSON attachment with sections `profile, consents, devices, notifications, issues, me_toos, follows, issue_verifications`, no FCM tokens, no other user's data; the share sheet opens; a 4th export in one day → 429

**AC-10** — Account deletion anonymises
- **Given** a citizen who reported an issue with two photos, follows another issue and has a device
- **When** they confirm "Delete account" with "DELETE"
- **Then** 204; user row has null phone/uid/name and status `deleted`; their issue remains public with no description and no report photos; photo files are gone from storage; follows and devices are removed; consents are withdrawn; the Firebase user is deleted; the old session gets 401; signing in again with the same phone creates a fresh account

**AC-11** — Device registration
- **Given** an install with an FCM token, signed out, then signed in
- **When** the app starts and later signs in, and when the token refreshes
- **Then** one `devices` row per `install_id` with the latest token, `user_id` set after sign-in and cleared on logout; topics `ward_<n>__<lang>` and `city_all__<lang>` are subscribed (visible in `topics`)

**AC-12** — Push to topic and user with delivery log
- **Given** `PUSH_DRIVER=fcm` on a staging Firebase project and the emulator subscribed to `ward_12__en`
- **When** `npm run push:test -- --topic ward_12` and `notifyUser(<user>)` are run
- **Then** the notification appears on the emulator in English; tapping opens the allowed route; `notifications` has one row per call with status `sent` and provider ids; a user with no token yields `no_device`; an unregistered token is cleared from `devices`

**AC-13** — Deferred sends
- **Given** a message with `sendAfter` 10 minutes ahead
- **When** `notifyUser` is called and `push:flush` runs before and after that time
- **Then** the row is `queued` first and `sent` only after the time passes, exactly once

**AC-14** — Logs are redacted
- **Given** the redaction test and a manual run of sign-in, device registration and a push
- **When** the API log is searched for the ID token, session token, FCM token, phone digits, OTP and the push body text
- **Then** none appear (count 0)

**AC-15** — Firebase setup reproducible without secrets
- **Given** a fresh clone and `docs/v2/firebase-setup.md`
- **When** a developer follows it
- **Then** they can build the app and run the API against their own Firebase project; `git ls-files` shows no `google-services.json`, `firebase_options.dart` or service-account JSON, and the CI secret check passes

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-007 |
| AC-2 | REQ-F-008, REQ-S-001, REQ-S-003 |
| AC-3 | REQ-S-001, REQ-S-015 |
| AC-4 | REQ-S-005, REQ-F-007 |
| AC-5 | REQ-F-008, REQ-S-001 |
| AC-6 | REQ-F-009 |
| AC-7 | REQ-F-009, REQ-F-010 |
| AC-8 | REQ-S-003 |
| AC-9 | REQ-S-004 |
| AC-10 | REQ-S-004 |
| AC-11 | REQ-F-010 |
| AC-12 | REQ-F-011, REQ-O-003 |
| AC-13 | REQ-F-011 |
| AC-14 | REQ-S-015 |
| AC-15 | REQ-O-003 |

### 7.2 Non-Functional Checklist

- [ ] Every new endpoint Zod-validated (strict objects), uniform error shape, rate-limited as in §5.3
- [ ] Handlers thin; rules in services; all SQL parameterised (Prisma or tagged `$queryRaw`)
- [ ] Erasure runs in one transaction; storage and Firebase deletions only after commit, retried by cleanup
- [ ] Phone never returned unmasked by any endpoint; display name never in public responses
- [ ] No secrets or Firebase config files tracked by git; CI check in place
- [ ] Sign-in screens: loading, error, offline states; 48 dp targets; OTP field announces digits count; works at 2.0× text in Gujarati
- [ ] Push taps only open allow-listed in-app routes
- [ ] Notification permission never requested at first launch
- [ ] p95 of `GET /me` < 200 ms locally on seed data
- [ ] `npm run typecheck`, `npm run lint`, `npm test`, `dart analyze`, `flutter test` green

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-04-01 | API typecheck + lint; `dart format` + `flutter analyze`; git secret-file check | AC-15 |
| API integration | T-04-01 | `/auth/firebase` new user 201, repeat 200, relink by phone with new uid | AC-2 |
| API integration | T-04-02 | Expired / wrong aud / wrong iss / revoked / non-phone provider / malformed → 401, no row | AC-3 |
| API integration | T-04-03 | `ageConfirmed:false` new user → 403, nothing stored; missing core consent → 422; bad version → 422 | AC-4, AC-2 |
| API integration | T-04-04 | Suspended user → 403; deleted user's phone signs up fresh | AC-10 |
| API integration | T-04-05 | Logout increments `token_version`; old token 401 `TOKEN_REVOKED`; expired → `TOKEN_EXPIRED` | AC-5 |
| API integration | T-04-06 | Admin token on `/me` and user token on `/admin/complaints` rejected; `requireRole` 403 | AC-5 |
| API integration | T-04-07 | `GET/PATCH /me`: masking, valid edits, unknown ward 422, 41-char name 400, `role` 400 | AC-6 |
| API integration | T-04-08 | Consents grant/withdraw/regrant history; core withdrawal 409; notifications withdrawal clears tokens | AC-8 |
| API integration | T-04-09 | Export sections present, no tokens, only own data; 4th call 429 | AC-9 |
| API integration | T-04-10 | Delete: anonymised user, issue kept without description/photos, storage files deleted (local driver), follows/devices removed, Firebase delete called, old token 401 | AC-10 |
| API integration | T-04-11 | Delete transaction rollback when a registered erasure step throws: nothing changed | AC-10 |
| API integration | T-04-12 | `/devices` upsert by install, token moved between installs cleared, user linked/unlinked | AC-11 |
| API integration | T-04-13 | Push memory driver: topic sends to `__gu` and `__en`, row `sent`; user with no device `no_device`; unregistered token cleared; partial | AC-12 |
| API integration | T-04-14 | `sendAfter` → `queued`; `flushQueued` sends once | AC-13 |
| API integration | T-04-15 | Redaction: captured logs contain no token/phone/OTP/body values | AC-14 |
| API integration | T-04-16 | Rate limits: 11th `/auth/firebase` per IP/min → 429 with `Retry-After` | AC-2 |
| Widget | T-04-17 | `ensureSignedIn`: signed-in returns true without navigation; signed-out pushes sign-in and resumes caller on success, returns false on cancel | AC-1 |
| Widget | T-04-18 | Phone screen validation; OTP screen wrong/expired code messages; resend countdown | AC-1 |
| Widget | T-04-19 | Age screen: "No" → blocked screen and fake Firebase sign-out; consent box gates "Create account" | AC-4 |
| Widget | T-04-20 | `/me` edit flow and `/me/privacy` toggles call the API fakes; delete dialog requires "DELETE" | AC-6, AC-8, AC-10 |
| Widget | T-04-21 | `AccountPreferenceSync`: language/ward change → PATCH once + topic switch | AC-7 |
| Unit | T-04-22 | Push tap route allow-list accepts `/issues/abc`, rejects `https://x`, `/admin`, `//evil` | AC-12 |
| Manual | M-04-01 | Emulator: browse as visitor; tap an account-only action; full OTP with Firebase test number; return to action | AC-1, AC-4 |
| Manual | M-04-02 | Real SMS on a physical phone once (cost noted) incl. Android auto-retrieval | AC-1 |
| Manual | M-04-03 | Profile edit, language/ward change; `SELECT` user + devices rows | AC-6, AC-7, AC-11 |
| Manual | M-04-04 | Export → open JSON; delete account → check DB, storage folder, Firebase console | AC-9, AC-10 |
| Manual | M-04-05 | `PUSH_DRIVER=fcm` staging: `push:test` topic and user sends; foreground, background, terminated taps | AC-12 |
| Manual | M-04-06 | `grep -c -E '<idToken prefix>|<fcm prefix>|98765' api.log` = 0 after M-04-01…05 | AC-14 |
| Manual | M-04-07 | Fresh clone following `firebase-setup.md`; `git ls-files | grep -E 'google-services|firebase_options.dart|service-account'` empty | AC-15 |

## 9. Deliverables

- `docs/v2/firebase-setup.md`; `.gitignore` entries and CI secret-file check.
- Migration `<ts>_v2_auth_push_foundation` (users auth columns, devices constraints, `notifications`).
- API: `lib/firebase`, `lib/push` (+ drivers), tokens update, `requireUser`/`optionalUser`/`requireRole`, modules `auth`, `me`, `devices`; privacy registries; scripts `push:flush`, `push:test`; redaction update.
- App: auth feature (4 screens, `ensureSignedIn`, session store, interceptor), `/me`, `/me/privacy`, `AccountPreferenceSync`, push client; ARB keys in gu + en.
- Tests T-04-01…T-04-22; coverage matrix evidence for 11 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `docs/v2/firebase-setup.md` | New |
| `.gitignore`, CI workflow (secret-file check) | Modified |
| `apps/api/prisma/migrations/<ts>_v2_auth_push_foundation/migration.sql`, `prisma/schema.prisma` | New / Modified |
| `apps/api/src/config/index.ts`, `src/lib/errors/index.ts`, `src/lib/logger/index.ts`, `src/lib/tokens/index.ts` | Modified |
| `apps/api/src/lib/{firebase,push}/` | New |
| `apps/api/src/middleware/{requireUser,requireRole}.ts` | New |
| `apps/api/src/modules/{auth,me,devices}/` | New |
| `apps/api/src/routes.ts` | Modified |
| `apps/api/scripts/{push-flush,push-test}.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/test/{auth,me,devices,push,logging}.*.test.ts` | New |
| `apps/mobile/pubspec.yaml`, `android/app/build.gradle*`, `android/settings.gradle*`, `AndroidManifest.xml` | Modified |
| `apps/mobile/lib/main.dart`, `lib/firebase_options.example.dart` | Modified / New |
| `apps/mobile/lib/features/{auth,me}/` | New |
| `apps/mobile/lib/core/{push,api}/` | New / Modified |
| `apps/mobile/lib/core/settings/preference_sync.dart`, `lib/router/app_router.dart` | Modified |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified |
| `apps/mobile/test/{auth,me,push}/` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §2 D6, D8, D9; §3 roles; §6 `users`, `consents`, `devices`, `notifications`; §7 Auth & me, rate limits; §9 notifications; §11 privacy (DPDP)
- `docs/v2/design-system.md` DS §5 inputs, error summary; DS §8 sign-in screens
- `docs/tasks-v2/TASK-01-*.md` — tables and test harness
- `docs/tasks-v2/TASK-03-design-system-shell.md` — `PreferenceSync`, placeholder P-09
- `docs/tasks-v2/TASK-08-*.md` — extends `notifications`, quiet hours, inbox
- `docs/03-backend-spec.md` §3 (v1 admin JWT, token version), §8 (redaction)
- Firebase docs: Verify ID tokens (Admin SDK), FCM HTTP v1, Phone auth on Android

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Firebase project not created by the founder in time | Blocks OTP and push | Fake gateway lets API work and tests proceed; Open Question #3 tracked |
| SHA fingerprints missing for Play App Signing | OTP fails in Play builds | Setup doc lists both upload and app-signing keys; checked in TASK-13 |
| Firebase phone auth SMS quota/cost and abuse | Cost, blocked numbers | India-only SMS region policy, App Check later, rate limits on exchange |
| OEM battery managers delay notifications | Missed alerts | Notification messages (not data-only), high priority for alerts, language topics |
| Erasure misses data added by later tasks | DPDP non-compliance | Registry pattern; each later task adds a section + test; TASK-14 audits |
| Token cross-use between admin and citizen | Privilege escalation | Separate audience + `typ` claim; T-04-06 |
| Logs leak tokens via library error objects | Privacy breach | Firebase errors logged as code only; redaction test T-04-15 |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-04` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-04: …`
- [ ] Validator passes
