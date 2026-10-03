# TASK-05: Admin Authentication & Admin Shell

| Field | Value |
|---|---|
| Task ID | TASK-05 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-02, TASK-03 |
| Blocks | TASK-06 |
| Requirement IDs | REQ-F-034, REQ-F-035, REQ-F-036, REQ-F-037, REQ-F-038, REQ-F-039, REQ-F-040, REQ-F-041, REQ-S-001, REQ-S-002, REQ-S-003, REQ-S-004, REQ-S-009, REQ-S-025, REQ-S-027, REQ-S-029 |
| Primary Spec Refs | docs/03-backend-spec.md §3, docs/06-security-testing.md §2, docs/02-frontend-spec.md §4.17, §3.3, §5.3 |
| Last Updated | 2026-10-03 |

## 1. Objective

The pilot operator can be created from the command line, log in from the app's About screen with email and password, and land in an admin tab shell (Due, All, Rates, More) protected by a JWT guard on both server and app. Sessions end cleanly: expiry or "log out everywhere" returns the operator to login. At the end of this task every `/admin/*` endpoint rejects unauthenticated callers. An audit-logging helper exists for all later admin actions to use.

## 2. Scope

### In Scope
- `admin:create` CLI script (create + reset-password mode) with password policy and Argon2id hashing (bcrypt cost 12 fallback).
- `POST /admin/auth/login`, `GET /admin/me`, `POST /admin/auth/logout-all`.
- Admin JWT signing/verification in `src/lib/tokens`; `requireAdmin` middleware in `src/middleware/` that distinguishes `TOKEN_EXPIRED` from `TOKEN_REVOKED` and checks `is_active`.
- Rate limiters: login 5 per IP + email per 15 min; admin endpoints 300 per admin per minute.
- Admin audit-log helper `auditLog(req, action, targetId?)` writing an `info` line with `adminId`, `action`, `targetId`. Used here for `logout_all`. TASK-06/08/09 reuse it.
- App: `/admin/login` screen reached from About; `adminAuthProvider`; secure token storage; router guard on `/admin/*` with return-to route; 401 interceptor; admin tab shell with four tabs and a Due badge slot; More tab with "Log out" and "Log out everywhere".

### Out of Scope
- Due list content, badge count, reminders and Rates content → TASK-06 (tab bodies here are placeholders "Coming in TASK-06/08/09" built from `EmptyState`).
- All complaints list and complaint detail → TASK-08.
- More-tab links to Invite codes, Categories and Export → TASK-09.
- Admin sign-up endpoint → never (03 §3.2: admins are created only by script).
- Screenshot blocking on admin screens → deferred (REQ-S-037).

## 3. Prerequisites

- TASK-02 complete: `admin_users` table (incl. `token_version`, `is_active`, `last_login_at`) migrated; seed creates the dev admin from `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`.
- TASK-03 complete: Flutter app shell, router, API client with standard headers and typed error mapping, ARB setup, design-system components, About screen.
- Env vars present in `apps/api/.env` (validated by TASK-01 config loader; add any missing to the schema and `.env.example`): `JWT_SECRET` (≥ 32 random bytes, CSPRNG-generated), `JWT_ISSUER=saarthee-api`, `JWT_AUDIENCE=saarthee-admin`, `JWT_EXPIRES_IN=8h`, `TRUST_PROXY=false`.
- Candidate libraries verified on npm/pub.dev for current version and maintenance (record versions in §13): `jsonwebtoken`, `argon2` (or `bcrypt`), `express-rate-limit`, `flutter_secure_storage`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Provides `admin_users` schema, Prisma client and the seeded development admin |
| TASK-03 | Provides the Flutter router, API client/interceptor chain, error-code→ARB mapping, About screen and shared widgets used by the login screen and tab shell |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-034 | Create-admin CLI (`admin:create`): prompts for password, never logs it, errors if email exists; reset mode re-hashes and increments `token_version` | 03 §5.3, 06 §2.1 |
| REQ-F-035 | `POST /admin/auth/login` returns `{accessToken, expiresAt, admin}`; updates `last_login_at` | 03 §2.2, §3.1 |
| REQ-F-036 | `GET /admin/me` returns the current admin | 03 §2.2 |
| REQ-F-037 | `POST /admin/auth/logout-all` increments `token_version`, 204 | 03 §2.2, §3.2 |
| REQ-F-038 | Operator login screen (from About): email, password with show/hide; stores token + expiry; handles `INVALID_CREDENTIALS`, `ADMIN_DISABLED`, `RATE_LIMITED` | 02 §4.17 |
| REQ-F-039 | Admin tab shell: Due, All, Rates, More with a marigold count badge on Due; admin screens allow rotation | 02 §3.3, §2.2 |
| REQ-F-040 | 401 (`TOKEN_EXPIRED`/`TOKEN_REVOKED`) on admin calls clears the token, shows "Your session ended…", redirects to login and returns to the original route | 02 §5.3, §9.2 |
| REQ-F-041 | More tab: "Log out" (this device) and "Log out everywhere" | 02 §3.1, 07 C7 |
| REQ-S-001 | Admin passwords: Argon2id (bcrypt cost 12 fallback), ≥ 12 chars, reject the 10,000 most common passwords | 06 §2.1 |
| REQ-S-002 | Admin JWT HS256 (`JWT_SECRET` ≥ 32 bytes), claims `sub`,`tv`,`iat`,`exp`,`iss`,`aud`, 8 h expiry, no refresh; signature, expiry, issuer, audience, `token_version` and `is_active` checked on every request | 03 §3.2, 06 §2.2 |
| REQ-S-003 | Login uses constant-time hash check and the same `INVALID_CREDENTIALS` for unknown email and wrong password; disabled → 403 `ADMIN_DISABLED`; bad logins logged with hashed email | 03 §3.1, §9.2 |
| REQ-S-004 | Login rate limit 5 per IP + email per 15 min → 429 with Retry-After; no account lockout | 03 §10, 06 §2.1 |
| REQ-S-009 | Every admin endpoint requires a valid admin JWT (authorization matrix §3.3) | 03 §3.3 |
| REQ-S-025 | Rate limit: admin endpoints 300/admin/min | 03 §10 |
| REQ-S-027 | Admin actions (reminder, exclusion, anonymization, export, category/invite-code change, logout-all) logged at `info` with admin ID and target ID | 03 §9.2, 06 T11 |
| REQ-S-029 | Admin JWT stored in platform secure storage (Keystore/Keychain) | 06 §2.2, 02 §5.2 |

### 5.2 Data Contracts

Table `admin_users` (created in TASK-02, docs/04-database-design.md §3.1). This task reads and writes:

| Column | Use here |
|---|---|
| `email` | Lookup key; always lowercased before query and insert |
| `password_hash` | Argon2id hash (encoded string incl. params); bcrypt-12 if fallback chosen |
| `display_name` | Returned in login and `/admin/me` |
| `is_active` | `false` → login 403 `ADMIN_DISABLED`; guard rejects existing tokens with 401 `TOKEN_REVOKED` |
| `token_version` | Put in JWT `tv`; compared on every request; `+= 1` on logout-all and password reset |
| `last_login_at` | Set on successful login |
| `updated_at` | Updated on every write |

No migration in this task. If TASK-02 omitted any column above, add it in a new migration (never edit an applied one, 04 §7.2).

### 5.3 API Contracts

Base `/api/v1`. Error shape `{error:{code,message,details?,requestId}}` (03 §2.1).

| Method | Endpoint | Auth | Request | Response | Errors |
|---|---|---|---|---|---|
| POST | /admin/auth/login | No | `{email, password}` | 200 `{accessToken, expiresAt, admin:{id, email, displayName}}` | 400 `VALIDATION_FAILED`, 401 `INVALID_CREDENTIALS`, 403 `ADMIN_DISABLED`, 429 `RATE_LIMITED` |
| GET | /admin/me | JWT | — | 200 `{id, email, displayName}` | 401 |
| POST | /admin/auth/logout-all | JWT | — | 204 | 401 |

Authentication flow (03 §3.1):
1. Find admin by lowercase email.
2. Check the password hash (constant-time verify from the hashing library). If no admin exists, still run a verify against a fixed dummy hash so timing does not reveal unknown emails.
3. Unknown email or wrong password → 401 `INVALID_CREDENTIALS`, same message "Email or password is incorrect." Log `warn` with `emailHash` (SHA-256 of lowercase email), never the email or password.
4. Valid password but `is_active=false` → 403 `ADMIN_DISABLED` ("This account is disabled.").
5. Valid → update `last_login_at`, sign JWT, return token and `expiresAt` (ISO UTC).

Token strategy (03 §3.2):

| Item | Specification |
|---|---|
| Type | JWT access token, HS256, `JWT_SECRET` (≥ 32 random bytes) |
| Claims | `sub` (admin ID), `tv` (token_version), `iat`, `exp`, `iss` (`JWT_ISSUER`), `aud` (`JWT_AUDIENCE`) |
| Expiry | `JWT_EXPIRES_IN` = 8 h; no refresh token |
| Device storage | Platform secure storage (Keystore / Keychain) |
| Revocation | Guard compares `tv` to DB `token_version` each request; logout on one device = app deletes its token; logout-all = increment version |

Guard (`requireAdmin`) outcomes:

| Condition | Response |
|---|---|
| No / malformed `Authorization: Bearer` header, bad signature, wrong `iss`/`aud` | 401 `TOKEN_REVOKED` — ASSUMPTION, see §5.6 |
| `exp` passed | 401 `TOKEN_EXPIRED` ("Your session ended. Please log in again.") |
| Admin missing, `is_active=false`, or `tv` ≠ `token_version` | 401 `TOKEN_REVOKED` |
| OK | `req.admin = {id, email, displayName}`; continue |

Rate limits (03 §10), using the TASK-01 rate-limit middleware:

| Group | Limit | Key | On exceed |
|---|---|---|---|
| POST /admin/auth/login | 5 / 15 min | IP + lowercase email | 429 `RATE_LIMITED` + `Retry-After`; `warn` log (hashed email) |
| All JWT admin endpoints | 300 / 1 min | admin ID (after guard) | 429 `RATE_LIMITED` + `Retry-After` |

Audit log helper (`src/lib/audit` or inside `logger`): `auditLog(req, action: string, targetId?: string)` → `logger.info({requestId, adminId, action, targetId}, 'admin_action')`. Never pass phone, email, token or body content. Actions defined now: `logout_all`, `password_reset` (CLI). Later tasks add `reminder_created`, `reminder_revoked`, `exclusion_changed`, `anonymized`, `export`, `invite_code_created/updated`, `category_created/updated`.

CLI `admin:create` (03 §5.3, 06 §2.1):
- Prompts for email, display name, and password (hidden input, asked twice). Never echoes or logs the password.
- Password rules: ≥ 12 characters; not in the bundled 10,000-most-common list (case-insensitive compare); no other complexity rules.
- Create mode: exits non-zero with a clear message if the email already exists.
- `--reset` mode: email must exist; sets a new hash and increments `token_version` (logs out all sessions); writes a `password_reset` audit line with the admin ID only.
- May read `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD` for a non-interactive first run; prints a reminder to remove them from `.env` afterwards (05 §2.2).

### 5.4 UI Surfaces & States

| Surface | Route | States |
|---|---|---|
| About → "Operator login" link | `/about` | Default (link at bottom, never on Home — 02 §3.2) |
| Operator login | `/admin/login` | Default (email, password with show/hide toggle, "Log in" `PrimaryButton`); field validation (email required/format, password required) inline via `InlineFieldError`; in-flight (button progress, disabled, double-submit prevented); `INVALID_CREDENTIALS` → "Email or password is incorrect."; `ADMIN_DISABLED` → "This account is disabled."; `RATE_LIMITED` → "Too many attempts. Try again in N minutes." (N from `Retry-After`, rounded up); offline → `OfflineBanner` + retry; "session ended" banner when redirected after a 401 |
| Admin tab shell | `/admin`, `/admin/complaints`, `/admin/rates`, `/admin/more` | Bottom navigation (Due, All, Rates, More) with Material Symbols Rounded icons and text labels; Due icon carries a `marigold` badge with `ink` text, hidden when count is null/0 (count supplied by TASK-06). Tab bodies Due/All/Rates: `EmptyState` placeholder naming the task that fills them |
| More tab | `/admin/more` | "Log out" (secondary), "Log out everywhere" (confirm dialog → in-flight → success returns to login; error → message + retry). Placeholder area for TASK-09 links |

All strings in ARB files. Admin screens allow rotation; citizen flows stay portrait-locked (02 §2.2). Tap targets ≥ 48; text works at largest system size.

### 5.5 Permissions & Roles

| Action | Admin (JWT) | Citizen with verify token | Citizen (no token) |
|---|---|---|---|
| Log in | n/a (public endpoint, rate-limited) | n/a | n/a |
| `/admin/me`, logout-all | ✅ | ❌ 401 | ❌ 401 |
| Any other `/admin/*` route (incl. future ones from TASK-06/08/09) | ✅ | ❌ 401 | ❌ 401 |
| See admin entry point | Via About only | — | Via About only (login still required) |

The guard is mounted on the `/admin` router (excluding `/admin/auth/login`) so every later admin route inherits it by construction. App guard on `/admin/*` is UX only; the server is authoritative.

### 5.6 Assumptions

- ASSUMPTION: Missing, malformed, wrongly signed or wrong-audience tokens return 401 `TOKEN_REVOKED` — the error table (03 §9.1) defines only `TOKEN_EXPIRED` and `TOKEN_REVOKED` for admin JWTs and both trigger the same app behaviour — if a distinct code (e.g. `UNAUTHENTICATED`) is wanted, add it to the error table and ARB.
- ASSUMPTION: The 10,000 common-password list is a public list (e.g. SecLists top-10k) committed to `apps/api/scripts/data/` — 06 §2.1 requires bundling but names no source — swap the file if a different list is preferred.
- ASSUMPTION: Login keyed rate limiting uses the raw IP + lowercase email; with `TRUST_PROXY=false` locally — at deployment `TRUST_PROXY` must be set (05 §9) or all users share one key.
- ASSUMPTION: The app checks `expiresAt` on startup and before admin navigation and proactively returns to login when expired — 02 §4.17 says "the expiry time is kept so the app can return to login when it lapses" — no behaviour change if the server 401 path is relied on instead.
- ASSUMPTION: Argon2id parameters use the library's current recommended defaults (verify at build time); fallback bcrypt cost 12 only if argon2 native build fails on the dev machine — record the choice in §13.

## 6. Implementation Steps

1. Verify and add candidate libraries (`jsonwebtoken`, `argon2`/`bcrypt`, `express-rate-limit` if not already added in TASK-01); record versions in §13. Extend the config schema and `.env.example` with `JWT_SECRET` (min 32 bytes), `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRES_IN` if missing.
2. Extend the existing `src/lib/password` helper created in TASK-02 (`hashPassword`, `verifyPassword` — constant-time library verify; do **not** create a second hashing module): add `checkPasswordPolicy` (length ≥ 12, not in common list) and load the bundled common-password file once. If TASK-02 chose bcrypt as the fallback, keep that choice.
3. `src/lib/tokens`: `signAdminToken(admin)` and `verifyAdminToken(token)` returning a discriminated result (`ok` / `expired` / `invalid`), enforcing HS256, `iss`, `aud`.
4. `src/lib/audit`: `auditLog(req, action, targetId?)` on top of the redacting logger; document allowed actions in a const list.
5. `scripts/create-admin.ts` (+ root script `admin:create`): interactive create and `--reset` mode per §5.3; refuse weak passwords with a clear message; exit codes 0/1.
6. `src/middleware/requireAdmin`: parse Bearer header → verify → load admin → compare `tv` and `is_active` → set `req.admin`; map outcomes to `TOKEN_EXPIRED` / `TOKEN_REVOKED`.
7. `src/modules/admin-auth`: Zod-validated login handler + service (dummy-hash timing protection, generic error, `ADMIN_DISABLED`, `last_login_at`), `/admin/me`, `/admin/auth/logout-all` (increment `token_version`, `auditLog('logout_all', admin.id)`).
8. Rate limiters: login limiter keyed IP + lowercase email (5/15 min) with `warn` log of hashed email; admin limiter keyed `req.admin.id` (300/min) mounted after the guard.
9. Router wiring: `/admin/auth/login` (public, login limiter) and an `/admin` sub-router with `requireAdmin` + admin limiter applied once at the top so all future admin modules inherit it.
10. Manual API verification of M-05-01…M-05-09 (§8) before starting app work.
11. App `features/admin/data`: `AdminAuthRepository` (login, me, logoutAll) on the TASK-03 API client; secure storage wrapper (candidate `flutter_secure_storage`) storing token + `expiresAt` + profile.
12. App `features/admin/application`: `adminAuthProvider` notifier with `login`, `logout`, `logoutEverywhere`, `handleUnauthorized`; restores state from secure storage on launch and drops expired tokens.
13. API client: attach `Authorization: Bearer` only to `/admin/*` calls; interceptor converts 401 `TOKEN_EXPIRED`/`TOKEN_REVOKED` on admin calls into `handleUnauthorized()` (clear token, set "session ended" flag).
14. Router: guard for `/admin/*` (except `/admin/login`) redirecting to `/admin/login?from=<route>`; after login navigate to `from` or `/admin`; About screen link "Operator login" → `/admin/login`.
15. Login screen per §5.4 using `PrimaryButton`, `InlineFieldError`, `OfflineBanner`; error code → ARB mapping incl. Retry-After minutes; show/hide password with accessible label.
16. Admin tab shell (`StatefulShellRoute` or equivalent) with four tabs, labelled icons, Due badge widget fed by a nullable count provider (returns null until TASK-06); placeholders via `EmptyState`. Allow rotation on admin routes only.
17. More tab: "Log out" (local delete → login) and "Log out everywhere" (confirm dialog → API → local delete → login with confirmation snackbar); errors keep the user on the tab with retry.
18. Add all new strings to ARB; run `dart analyze`, `dart format`, `tsc --noEmit`, ESLint.
19. Manual app verification M-05-10…M-05-16 on the Android emulator, including failure paths; update coverage matrix and task docs per the protocol.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Create an admin from the CLI
- **Given** an empty `admin_users` table (or a new email)
- **When** the operator runs `admin:create` and enters an email, display name and a 14-character uncommon passphrase twice
- **Then** a row exists with a lowercased email and an Argon2id (or bcrypt-12) hash, the password appears nowhere in terminal output or logs, and running it again with the same email exits non-zero with "already exists"

**AC-2** — Weak passwords are refused
- **Given** the create-admin script
- **When** the operator enters an 11-character password, or a 12+ character password from the common list (e.g. `password1234`)
- **Then** the script refuses with a message explaining the rule and creates nothing

**AC-3** — Password reset logs out every session
- **Given** an admin with a valid JWT
- **When** `admin:create --reset` sets a new password for that email
- **Then** `token_version` is incremented, the old JWT gets 401 `TOKEN_REVOKED` on `/admin/me`, and an `info` audit line `password_reset` contains the admin ID only

**AC-4** — Successful login
- **Given** an active admin
- **When** `POST /admin/auth/login` is called with the correct email (any letter case) and password
- **Then** the response is 200 with `accessToken`, `expiresAt` ≈ now + 8 h, and `admin{id,email,displayName}`; the JWT decodes to HS256 with `sub`, `tv`, `iat`, `exp`, `iss=saarthee-api`, `aud=saarthee-admin`; `last_login_at` is updated

**AC-5** — Generic failure for wrong email or password
- **Given** an existing admin
- **When** login is attempted with a wrong password, and separately with an unknown email
- **Then** both return 401 `INVALID_CREDENTIALS` with the identical message, and the `warn` log lines contain a hashed email but no email or password

**AC-6** — Disabled admin
- **Given** an admin with `is_active=false`
- **When** they log in with the correct password, or call `/admin/me` with a token issued before they were disabled
- **Then** login returns 403 `ADMIN_DISABLED` and the old token gets 401 `TOKEN_REVOKED`

**AC-7** — Login rate limit without lockout
- **Given** one IP and one email
- **When** six login attempts are made within 15 minutes
- **Then** the sixth returns 429 `RATE_LIMITED` with a `Retry-After` header and a `warn` log; a different email from the same IP is not blocked by that counter; after the window passes, a correct password succeeds (no lockout)

**AC-8** — Every admin route requires a JWT
- **Given** no `Authorization` header (citizen without token), a malformed token, a token signed with another secret, and a verify token sent as a Bearer token
- **When** each calls `GET /admin/me`, `POST /admin/auth/logout-all`, and any other mounted `/admin/*` route
- **Then** every call returns 401 with the standard error shape and none reaches a handler

**AC-9** — Expired vs revoked tokens
- **Given** a token whose `exp` has passed, and a valid token for an admin whose `token_version` was then incremented
- **When** each calls `GET /admin/me`
- **Then** the first returns 401 `TOKEN_EXPIRED` and the second 401 `TOKEN_REVOKED`

**AC-10** — Current admin and log out everywhere
- **Given** two valid tokens for the same admin (two devices)
- **When** `GET /admin/me` is called, then `POST /admin/auth/logout-all` with token A
- **Then** `/admin/me` returns `{id,email,displayName}`; logout-all returns 204, both tokens now get 401 `TOKEN_REVOKED`, and an `info` audit line `logout_all` with `adminId` exists

**AC-11** — Admin endpoint throttle
- **Given** a valid admin token
- **When** more than 300 admin requests are made within one minute
- **Then** the 301st returns 429 `RATE_LIMITED` with `Retry-After`

**AC-12** — App login flow from About
- **Given** the citizen Home screen with no admin entry point
- **When** the operator opens About → "Operator login", enters valid credentials and taps "Log in"
- **Then** the button shows progress and is disabled during the call, the token and expiry are stored in secure storage (not shared_preferences), and the Due tab of the admin shell opens

**AC-13** — App login errors
- **Given** the login screen
- **When** the operator submits empty fields, wrong credentials, a disabled account, or exceeds the rate limit
- **Then** they see inline field errors, "Email or password is incorrect.", "This account is disabled.", or "Too many attempts. Try again in N minutes." respectively, with screen-reader announcement

**AC-14** — Session ended returns to login and back
- **Given** the operator is on `/admin/rates` and the server now returns 401 `TOKEN_REVOKED` (after logout-all from another device) or `TOKEN_EXPIRED`
- **When** the next admin call is made (or the app resumes past `expiresAt`)
- **Then** the stored token is cleared, `/admin/login` shows "Your session ended. Please log in again.", and after logging in the operator returns to `/admin/rates`

**AC-15** — Admin shell and More tab
- **Given** a logged-in operator
- **When** they switch between Due, All, Rates and More, rotate the phone, and use "Log out" then (after logging in again) "Log out everywhere"
- **Then** each tab shows its labelled icon and placeholder, the Due icon shows a marigold badge when the badge provider returns a count > 0 (verified with a stub value), rotation works on admin screens only, "Log out" deletes the local token and shows login, and "Log out everywhere" asks for confirmation, calls the API and shows login

**AC-16** — Guarded deep navigation
- **Given** no stored token
- **When** the app is navigated directly to `/admin/complaints`
- **Then** it redirects to `/admin/login` and after login lands on `/admin/complaints`

| AC | Requirements |
|---|---|
| AC-1, AC-2 | REQ-F-034, REQ-S-001 |
| AC-3 | REQ-F-034, REQ-S-002, REQ-S-027 |
| AC-4 | REQ-F-035, REQ-S-002 |
| AC-5 | REQ-S-003 |
| AC-6 | REQ-S-002, REQ-S-003 |
| AC-7 | REQ-S-004 |
| AC-8 | REQ-S-009 |
| AC-9 | REQ-S-002 |
| AC-10 | REQ-F-036, REQ-F-037, REQ-S-027 |
| AC-11 | REQ-S-025 |
| AC-12, AC-13 | REQ-F-038, REQ-S-029 (AC-12) |
| AC-14 | REQ-F-040 |
| AC-15 | REQ-F-039, REQ-F-041 |
| AC-16 | REQ-F-040, REQ-S-009 |

### 7.2 Non-Functional Checklist

- [ ] Login body validated with Zod (email format, non-empty password, unknown fields stripped); 400 `VALIDATION_FAILED` with `details`
- [ ] Unknown-email path runs a dummy hash verify so response time does not reveal account existence
- [ ] Logs after M-05 checks contain no password, email in clear, `Authorization` header or JWT (grep the log output)
- [ ] `JWT_SECRET`, issuer, audience, expiry read from config; nothing hard-coded; startup fails if `JWT_SECRET` < 32 bytes
- [ ] Guard mounted once on the `/admin` router; a newly added dummy admin route is protected without extra code (checked then removed)
- [ ] Token stored only via secure storage; `grep` of shared_preferences keys shows no token
- [ ] Login screen: loading (button progress), error, offline and session-ended states reachable; double-submit prevented
- [ ] Tab shell and login usable at 320 px width and largest system text size; touch targets ≥ 48; badge not colour-only (count text)
- [ ] All new strings in ARB files; error messages keyed by backend code
- [ ] Follows TASK-01 error/logging patterns and TASK-03 provider/repository layering (screens never call the API directly)

## 8. Validation & Testing

| Level | What to test | ACs proven |
|---|---|---|
| Static | `tsc --noEmit`, ESLint, `dart analyze`, `dart format --set-exit-if-changed` all clean | — |
| CLI manual | **M-05-01** `npm run admin:create` with valid input → row created; rerun same email → non-zero exit. **M-05-02** 11-char and `password1234` refused. **M-05-03** `--reset` → `SELECT token_version FROM admin_users WHERE email=…` incremented; old token 401 `TOKEN_REVOKED`; audit line present | AC-1, AC-2, AC-3 |
| API manual | **M-05-04** `curl -s -XPOST $API/admin/auth/login -H 'content-type: application/json' -d '{"email":"Admin@Example.test","password":"…"}'` → 200; decode JWT (jwt.io offline or `node -e`) and check alg/claims; `SELECT last_login_at` updated | AC-4 |
| API manual | **M-05-05** wrong password and unknown email → both 401 `INVALID_CREDENTIALS`, same message; grep log for the email → no match, `emailHash` present | AC-5 |
| DB + API manual | **M-05-06** `UPDATE admin_users SET is_active=false` → login 403 `ADMIN_DISABLED`; old token on `/admin/me` → 401 `TOKEN_REVOKED`; restore | AC-6 |
| API manual | **M-05-07** loop 6 bad logins same email → 6th 429 + `Retry-After`; other email still 401 (not 429); wait window (or restart API in dev) → correct password 200 | AC-7 |
| API manual | **M-05-08** no header / `Bearer garbage` / token signed with other secret / verify token as Bearer against `/admin/me`, `/admin/auth/logout-all` and every mounted `/admin/*` route → all 401 standard shape | AC-8 |
| API manual | **M-05-09** token minted with `JWT_EXPIRES_IN=1s` (dev) → `TOKEN_EXPIRED`; two tokens + logout-all → both `TOKEN_REVOKED`, 204, `logout_all` audit line; `/admin/me` body correct; loop 301 calls → 429 | AC-9, AC-10, AC-11 |
| App manual | **M-05-10** About → Operator login → valid login → Due tab; inspect secure storage usage (no token in shared_preferences) | AC-12 |
| App manual | **M-05-11** empty fields, wrong password, disabled admin, 6 attempts → each message; TalkBack announces errors | AC-13 |
| App manual | **M-05-12** on Rates tab, run logout-all via curl → next refresh redirects to login with "session ended", login returns to Rates; repeat with 1 s expiry build | AC-14 |
| App manual | **M-05-13** tabs, rotation, stub badge count 3 → badge shows "3"; Log out; Log out everywhere confirm/cancel/success/offline error | AC-15 |
| App manual | **M-05-14** cold start without token, navigate to `/admin/complaints` (dev route push) → login → lands on `/admin/complaints` | AC-16 |
| App manual | **M-05-15** 320 px emulator + largest font: login and shell readable, no cut-off | 7.2 items |
| Optional automated | Not applicable — 06 §8.1 lists no auth-specific safety-net test | — |

## 9. Deliverables

- `admin:create` script with create and `--reset` modes, bundled common-password list.
- Admin JWT lib, password lib, audit-log helper.
- `requireAdmin` guard, login limiter, admin limiter, `/admin` sub-router.
- Endpoints: `POST /admin/auth/login`, `GET /admin/me`, `POST /admin/auth/logout-all`.
- Flutter: login screen, `adminAuthProvider`, secure storage wrapper, 401 interceptor, router guard with return-to, admin tab shell with Due badge slot, More tab with logout actions, About link.
- ARB strings for all admin auth copy and error codes.
- Updated `.env.example` (JWT vars) and root `package.json` script `admin:create`.

## 10. Files Expected to Change

Prediction, not a constraint.

| Path | Change |
|---|---|
| `apps/api/src/lib/password/` (created in TASK-02; policy added) | Modified |
| `apps/api/src/lib/tokens/`, `apps/api/src/lib/audit/` | New |
| `apps/api/src/middleware/requireAdmin.*`, `apps/api/src/middleware/rateLimiters.*` | New / Modified |
| `apps/api/src/modules/admin-auth/` | New |
| `apps/api/src/app.*` (router mounting) | Modified |
| `apps/api/src/config/` | Modified (JWT vars) |
| `apps/api/scripts/create-admin.*`, `apps/api/scripts/data/common-passwords.txt` | New |
| `apps/api/.env.example`, root `package.json` | Modified |
| `apps/mobile/lib/features/admin/{data,application,presentation}/` (auth, shell, more) | New |
| `apps/mobile/lib/core/api/` (auth header + 401 interceptor) | Modified |
| `apps/mobile/lib/router/` (admin routes, guard) | Modified |
| `apps/mobile/lib/features/about/` (operator login link) | Modified |
| `apps/mobile/lib/core/l10n/*.arb` | Modified |
| `apps/mobile/pubspec.yaml` (`flutter_secure_storage` candidate) | Modified |

## 11. Related Documentation

- `docs/03-backend-spec.md §3.1–§3.3` — auth sequence, token strategy, authorization matrix.
- `docs/03-backend-spec.md §2.2` (Admin: authentication) — endpoint contracts.
- `docs/03-backend-spec.md §9.1, §9.2` — error codes; logging levels and redaction (bad logins with hashed email; admin action logs).
- `docs/03-backend-spec.md §10` — login and admin rate limits.
- `docs/03-backend-spec.md §5.3` — create-admin script behaviour.
- `docs/06-security-testing.md §2.1–§2.3` — password policy, token security, session management.
- `docs/02-frontend-spec.md §4.17` — login screen; `§3.1–§3.3` — routes, navigation, admin tabs layout; `§5.2–§5.3` — `adminAuthProvider`, 401 handling; `§9.2` — session-ended message.
- `docs/04-database-design.md §3.1` — `admin_users` columns.
- `docs/05-devops-infrastructure.md §2.2` — JWT and seed env vars.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Argon2 native module fails to build on the dev machine | Blocks login | bcrypt cost 12 fallback (06 §2.1); record choice |
| In-memory rate limiter resets on API restart | Limits easier to bypass locally | Acceptable for single-process pilot (05 §7); revisit at deployment |
| Guard mounted per-route instead of on the router | Later admin routes left unprotected | Mount once on `/admin`; AC-8 checks every mounted route; TASK-10 re-checks |
| Secure storage behaviour differs on iOS simulator/Keychain | Token lost or persisted after uninstall | Test on iOS in TASK-10; treat missing token as logged out |
| Audit helper misused with PII arguments | Personal data in logs | Helper accepts only `action` and `targetId`; TASK-10 grep check (REQ-S-027 verification) |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-05` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-05: …`
- [ ] Validator passes
