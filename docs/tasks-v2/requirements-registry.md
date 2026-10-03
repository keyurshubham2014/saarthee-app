# Requirements Registry — Saarthee v2

**Source documents:** `docs/v2/saarthee-v2-spec.md` (§1–§12), `docs/v2/design-system.md` (DS §1–§8), `docs/research/saarthee-v2-proposal.html`.
**Rule:** every active requirement is covered by exactly one task. Verification lives in `coverage-verification.md`.

## Functional (REQ-F)

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-F-001 | `GET /geo/locate?lat&lng` returns ward and zone via PostGIS point-in-polygon; nearest ward with `confirm:true` when outside all polygons | Spec §6, §7 | P0 | TASK-02 |
| REQ-F-002 | `GET /wards`, `GET /wards/{id}`, `GET /zones` with Gujarati and English names, zone, ward office address and public phone | Spec §6, §7 | P0 | TASK-02 |
| REQ-F-003 | Ward picker data: searchable list of 48 wards grouped by 7 zones | Spec §8 | P0 | TASK-02 |
| REQ-F-004 | Onboarding: language first (ગુજરાતી / English), one intro screen with independence notice, set home ward by GPS or picker | Spec §8, D4 | P0 | TASK-03 |
| REQ-F-005 | Citizen app shell with five tabs (Home, Map, Report, Alerts, My Ward), state kept per tab | Spec §8 | P0 | TASK-03 |
| REQ-F-006 | Language switch in settings changes the whole app instantly; preference stored on device and on the account | Spec §8, D4 | P0 | TASK-03 |
| REQ-F-007 | Phone OTP sign-in (Firebase Authentication) shown only when an action needs an account; returns to the action after sign-in | Spec D6, D8 | P0 | TASK-04 |
| REQ-F-008 | `POST /auth/firebase` exchanges a verified Firebase ID token for a Saarthee session JWT; `POST /auth/logout` | Spec §7 | P0 | TASK-04 |
| REQ-F-009 | `GET/PATCH /me` (display name, language, home ward); profile screen | Spec §7, §8 | P0 | TASK-04 |
| REQ-F-010 | `POST /devices` registers the FCM token per install and user; topic subscription for home ward and `city_all` | Spec §9 | P0 | TASK-04 |
| REQ-F-011 | Server push service (FCM HTTP v1) for topics and individual tokens, with a delivery log in `notifications` | Spec §9 | P0 | TASK-04 |
| REQ-F-012 | v2 category list (14 categories, Gujarati + English, icon, colour token, SLA days) via `GET /categories`, with AMC CCRS problem-type mapping | Spec §4 | P0 | TASK-05 |
| REQ-F-013 | AMC problem types cached from the CCRS public JSON by a script (manual run, at most daily) | Spec §4 | P1 | TASK-05 |
| REQ-F-014 | Three-step report flow (DS §8): category grid; photos (1–3) with auto location and adjustable pin; optional description and check-your-answers; submit | Spec §8, DS §8 | P0 | TASK-05 |
| REQ-F-015 | Duplicate check before submit: open issues of the same category within 50 m in 30 days offered as "Me too" | Spec §5 | P0 | TASK-05 |
| REQ-F-016 | `POST /issues` idempotent by `clientSubmissionId`; assigns ward/zone, SLA due date, status `reported` | Spec §5, §7 | P0 | TASK-05 |
| REQ-F-017 | Report draft persists across app kill and camera hand-off; image_picker lost-data recovery handled | Spec §8 | P0 | TASK-05 |
| REQ-F-018 | Optional "File with AMC too" hand-off (CCRS web, WhatsApp, 155303) showing the matching AMC problem type; citizen can link a CCRS number later | Spec §5, §1 | P0 | TASK-05 |
| REQ-F-019 | Voice input for the description (device speech-to-text, gu/en) | Spec §8 | P2 | TASK-05 |
| REQ-F-020 | Issue status transitions enforced server-side by role (§5 state machine); every change appended to `issue_events` | Spec §5 | P0 | TASK-06 |
| REQ-F-021 | Marked-fixed by reporter, representative or moderator, optionally with an after photo | Spec §5 | P0 | TASK-06 |
| REQ-F-022 | Verification: citizen answers Fixed/Not fixed with a photo within `VERIFY_RADIUS_M` (100 m); rules move the issue to verified or reopened | Spec §5 | P0 | TASK-06 |
| REQ-F-023 | Reopen window of 7 days after marked-fixed; after that the issue shows "Fixed (not verified)" | Spec §5 | P0 | TASK-06 |
| REQ-F-024 | SLA due date per category; overdue issues flagged in lists and detail | Spec §5 | P0 | TASK-06 |
| REQ-F-025 | Escalation ladder: pre-filled message to corporators (relay), zone office, deputy commissioner, commissioner with evidence link | Spec §5 | P0 | TASK-06 |
| REQ-F-026 | CCRS 24-hour reopen reminder when the citizen marks "AMC closed it" | Spec §5 | P1 | TASK-06 |
| REQ-F-027 | Followers and reporter get push + inbox notifications on status changes and verification requests | Spec §9 | P0 | TASK-06 |
| REQ-F-028 | Home feed for the selected ward: alerts strip, report action, nearby issues, upcoming drives, service shortcuts (`GET /feed`) | Spec §8 | P0 | TASK-07 |
| REQ-F-029 | Map tab with clustered issue pins, category/status/"mine" filters, bottom-sheet preview (`GET /map/issues`) | Spec §8 | P0 | TASK-07 |
| REQ-F-030 | Issue detail: photos with before/after, status and timeline, Me too, Follow, Share, Verify/Reopen, Link CCRS, Escalate, report a problem | Spec §8 | P0 | TASK-07 |
| REQ-F-031 | Me too and Follow (`POST/DELETE`) with counts; one per user | Spec §7 | P0 | TASK-07 |
| REQ-F-032 | Share an issue as an image card plus link to WhatsApp and other apps | Spec §8 | P1 | TASK-07 |
| REQ-F-033 | My reports and Following lists with status chips | Spec §8 | P0 | TASK-07 |
| REQ-F-034 | Issue list API with filters (ward, category, status, bbox), sort (newest, most affected, overdue) and cursor paging | Spec §7 | P0 | TASK-07 |
| REQ-F-035 | Staff alert composer: type, severity, bilingual title/body, source name + URL, validity window, wards or zone/city | Spec §9 | P0 | TASK-08 |
| REQ-F-036 | Alert approval: Info/Advisory by one moderator; Warning/Critical need two different approvers; publish, retract, supersede | Spec D3, §9 | P0 | TASK-08 |
| REQ-F-037 | Published alerts pushed to ward/zone/city topics respecting quiet hours (except Critical); auto-expire at `valid_to` | Spec §9 | P0 | TASK-08 |
| REQ-F-038 | Alerts tab: active and past alerts for my wards, severity banner, source line, validity; alert detail | Spec §8 | P0 | TASK-08 |
| REQ-F-039 | Alert subscription settings: extra wards, categories of alerts, mute non-critical | Spec §9 | P0 | TASK-08 |
| REQ-F-040 | Notification inbox (90 days) with read state, across alerts, issue updates and initiatives | Spec §9 | P0 | TASK-08 |
| REQ-F-041 | Draft alerts created automatically from NDMA SACHET CAP RSS (and IMD district warnings if access is granted); never auto-published | Spec §9 | P1 | TASK-08 |
| REQ-F-042 | My Ward screen: four corporators, MLA, MP, ward office, scorecard link, services and drives for the ward | Spec §8 | P0 | TASK-09 |
| REQ-F-043 | Representative profile: name (gu/en), role, party as plain text, term, office contact if published, source link, last checked date | Spec §6, D2 | P0 | TASK-09 |
| REQ-F-044 | Message relay: citizen sends a message (optionally about an issue) that Saarthee emails to the representative; citizen phone hidden unless the citizen opts in | Spec D2, §7 | P0 | TASK-09 |
| REQ-F-045 | Representative roster import tool (CSV with source URLs) and staff CRUD for representatives and ward–constituency mapping | Spec §6 | P0 | TASK-09 |
| REQ-F-046 | Public ward scorecard: median days to acknowledge and to fix, verified %, reopen %, open backlog, reports per 1,000 residents, method note | Spec §7 | P1 | TASK-09 |
| REQ-F-047 | Election mode per city or ward: freezes representative-authored content and hides comparative stats, with a banner | Spec §11 | P0 | TASK-09 |
| REQ-F-048 | Staff console runs as a Flutter web build and in-app under `/staff`, role-aware navigation | Spec D7, §8 | P0 | TASK-10 |
| REQ-F-049 | Moderation queue: new issues in sensitive categories, flagged content, out-of-area issues; actions reject (reason), merge, recategorise, hide, suspend user | Spec §11 | P0 | TASK-10 |
| REQ-F-050 | Staff management of roles (grant/revoke moderator), categories, and app settings | Spec §3 | P0 | TASK-10 |
| REQ-F-051 | Content flagging by citizens on issues and comments | Spec §11 | P0 | TASK-10 |
| REQ-F-052 | Staff exports (CSV) of issues, events and verifications without phone numbers by default | Spec §7 | P1 | TASK-10 |
| REQ-F-053 | Representative claim flow: OTP-verified phone plus evidence upload, reviewed and approved by an admin | Spec §6 | P1 | TASK-11 |
| REQ-F-054 | Representative ward dashboard: open issues by category and age, overdue list, hotspots map, resolution trend, CSV export | Spec §7 | P1 | TASK-11 |
| REQ-F-055 | Representatives can acknowledge, comment and mark fixed on issues in their wards only | Spec §3, §5 | P1 | TASK-11 |
| REQ-F-056 | Representative inbox for relayed messages with reply-by-email tracking | Spec §7 | P2 | TASK-11 |
| REQ-F-057 | AMC services directory: categories, service pages (gu/en) with online/offline flag, official link, how-to steps | Spec §6, §8 | P0 | TASK-12 |
| REQ-F-058 | Monthly link check marks broken service links for staff review | Spec §6 | P1 | TASK-12 |
| REQ-F-059 | Initiatives (tree drives, clean-ups, health camps) list and detail with organiser and source | Spec §6, §8 | P1 | TASK-12 |
| REQ-F-060 | RSVP to initiatives with reminder 24 h before; staff can mark attendance | Spec §6, §9 | P1 | TASK-12 |
| REQ-F-061 | Seasonal service tips on Home (property-tax rebate window, monsoon, heat) managed by staff | Spec §8 | P2 | TASK-12 |
| REQ-F-062 | Report-flow motion per DS §6: tiles pop in with stagger, selected tile springs with selection haptic, shared-axis step transitions with animated progress bar, photo fly-in and pin drop, duplicate card slide-in with "Me too" morph, full-screen success with drawn check and success haptic | DS §6 | P1 | TASK-05 |
| REQ-F-063 | Lifecycle motion per DS §6: status chip cross-fades colour/icon/word, new timeline step expands from its dot, "Yes, fixed" button → progress → toast with drawn check, TalkBack announces the new status | DS §6 | P1 | TASK-06 |
| REQ-F-064 | Discovery motion per DS §6: Home first-load stagger, Report card spring and one-time first-launch pulse, feed card → detail shared element, "Me too" spring with rolling count, branded pull-to-refresh, map pin drop and cluster zoom | DS §6 | P1 | TASK-07 |
| REQ-F-065 | Alert motion per DS §6: in-app banner slides in under the app bar, single attention pulse for Critical (no loop), swipe-to-read in the inbox with rolling badge count | DS §6 | P1 | TASK-08 |
| REQ-F-066 | Dashboard motion per DS §6: numbers count up and bars grow on first view only (representative ward dashboard and ward scorecard widgets shared from TASK-09) | DS §6 | P2 | TASK-11 |

## Data (REQ-D)

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-D-001 | PostGIS enabled: compose image `postgis/postgis:17-3.5`, `CREATE EXTENSION postgis` in a new migration, local data migrated | Spec D10 | P0 | TASK-01 |
| REQ-D-002 | New v2 tables per spec §6 created only through new migrations; applied v1 migrations untouched | Spec §6 | P0 | TASK-01 |
| REQ-D-003 | `users`, `consents`, `devices` tables with constraints (unique phone, unique firebase uid, role enum) | Spec §6 | P0 | TASK-01 |
| REQ-D-004 | `issues`, `issue_photos`, `issue_events`, `issue_verifications`, `me_toos`, `follows` with geography point, GIST index and status index | Spec §6 | P0 | TASK-01 |
| REQ-D-005 | Legacy migration: every v1 complaint copied into `issues` with mapped status and `legacy_complaint_id`; v1 tables read-only | Spec §6, D11 | P0 | TASK-01 |
| REQ-D-006 | `zones` and `wards` seeded from the OpenCity KML (48 wards, 7 zones) with boundary version, cross-checked against AMC's ward list | Spec D10 | P0 | TASK-02 |
| REQ-D-007 | `categories` seeded with the 14 v2 categories and `amc_problem_types` mapping | Spec §4 | P0 | TASK-05 |
| REQ-D-008 | `representatives`, `representative_areas`, `assembly_constituencies`, `ward_constituency`, `rep_claims`, `rep_messages` tables | Spec §6 | P0 | TASK-09 |
| REQ-D-009 | `alerts`, `alert_wards`, `subscriptions`, `notifications` tables with status and validity constraints | Spec §6 | P0 | TASK-08 |
| REQ-D-010 | `services`, `initiatives`, `rsvps` tables | Spec §6 | P0 | TASK-12 |
| REQ-D-011 | `moderation_flags` and `app_settings` (election mode, flags) tables | Spec §6 | P0 | TASK-10 |
| REQ-D-012 | Ward scorecard computed by a SQL view or materialised view refreshed hourly | Spec §7 | P1 | TASK-09 |
| REQ-D-013 | Development seed for v2: wards, categories, sample citizens, issues in every status, representatives (fictional), alerts, services, initiatives | Spec §6 | P0 | TASK-01 |

## Non-functional (REQ-N)

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-N-001 | Design tokens per DS §2 replace v1 tokens; no colour literal outside the theme; semantic token names | DS §2 | P0 | TASK-03 |
| REQ-N-002 | Typography per DS §3 with bundled Gujarati + Latin fonts (subset), Indic line heights, scale to 200% without clipping | DS §3 | P0 | TASK-03 |
| REQ-N-003 | Component library per DS §5 (app bar, bottom nav, buttons, inputs, chips, list rows, cards, status timeline, banners, empty/loading/error/offline states) with a debug-only gallery | DS §5 | P0 | TASK-03 |
| REQ-N-004 | Accessibility: 48 dp targets, labels on all controls, contrast AA, icon + text for every status, TalkBack order | DS §7 | P0 | TASK-03 |
| REQ-N-005 | Complete Gujarati and English ARB translations for every string; no hard-coded strings | Spec D4 | P0 | TASK-03 |
| REQ-N-006 | Dark theme from the same tokens | DS §2 | P1 | TASK-03 |
| REQ-N-007 | Report sheet completes in ≤ 4 taps after the photo for a typical issue; cold start ≤ 3 s on a low-end phone (profile/release build) | DS §8 | P0 | TASK-05 |
| REQ-N-008 | Map renders 2,000 issues smoothly using server clustering and client clustering | Spec §7 | P1 | TASK-07 |
| REQ-N-009 | Automated tests: API integration tests (Vitest + Supertest) for auth, issue lifecycle, permissions and rate limits; run in CI | Spec §12 | P0 | TASK-01 |
| REQ-N-010 | Flutter widget tests for core components and an integration test of report → verify on the emulator | Spec §12 | P1 | TASK-14 |
| REQ-N-011 | All list endpoints paginated; p95 latency < 400 ms for feed, list and detail on pilot data | Spec §7 | P1 | TASK-07 |
| REQ-N-012 | Motion system per DS §6: `SaartheeMotion` tokens (durations, curves, stagger, spring) used by every animation (no `Duration(` literals in features, enforced by a test); shared transitions (shared axis, fade-through, sheets), press scale, skeleton shimmer, nav-pill slide, launch and onboarding motion; system "Remove animations" and an in-app Animations switch reduce all motion to instant/≤ 100 ms cross-fades | DS §6 | P0 | TASK-03 |
| REQ-N-013 | Motion performance and safety: every DS §6 catalogue moment holds 60 fps with no frame > 16 ms on the reference low-end phone (profile build, DevTools timeline evidence); only transform/opacity/colour animated; no element flashes > 3 times per second; reduced-motion run of the core loop passes | DS §6, DS §7 | P0 | TASK-14 |

## Security & privacy (REQ-S)

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-S-001 | Firebase ID tokens verified server-side (signature, audience, issuer, expiry); session JWT with token version | Spec D8 | P0 | TASK-04 |
| REQ-S-002 | Role-based authorisation on every staff endpoint; representatives scoped to their wards | Spec §3 | P0 | TASK-10 |
| REQ-S-003 | Purpose-specific consent records (core, share with representatives, AMC hand-off, notifications) with withdrawal | Spec §11 | P0 | TASK-04 |
| REQ-S-004 | Data export (`GET /me/export`) and account deletion (`DELETE /me`) that anonymises issues and deletes the person's photos | Spec §11 | P0 | TASK-04 |
| REQ-S-005 | Under-18 users blocked with an age confirmation at sign-in | Spec §11 | P0 | TASK-04 |
| REQ-S-006 | Public views never expose reporter phone or name; "A resident of <ward>" | Spec §11 | P0 | TASK-07 |
| REQ-S-007 | Faces and number plates blurred on-device before upload, with manual blur fallback | Spec §11 | P1 | TASK-05 |
| REQ-S-008 | Per-user rate limits per spec §7 (issues, me-too, messages, verifications) | Spec §7 | P0 | TASK-05 |
| REQ-S-009 | Message relay rate-limited (5/day per representative), profanity screen, citizen phone hidden by default | Spec D2 | P0 | TASK-09 |
| REQ-S-010 | Every staff action logged in the audit log with actor, role and target; no bodies or PII | Spec §11 | P0 | TASK-10 |
| REQ-S-011 | Alerts always show source and validity; no AMC logo; "independent app" label on About, alerts, services and hand-offs | Spec §1, §11 | P0 | TASK-08 |
| REQ-S-012 | Representative data shows only office or consented contacts; personal numbers never imported | Spec D2 | P0 | TASK-09 |
| REQ-S-013 | HTTPS everywhere outside local; cleartext exceptions only in debug builds (profile exception removed) | Spec §12 | P0 | TASK-13 |
| REQ-S-014 | Retention jobs: photos of closed issues after 2 years, logs 14 days, notifications 90 days | Spec §11 | P1 | TASK-13 |
| REQ-S-015 | v1 logging redaction extended to OTP, Firebase tokens, FCM tokens and message bodies | Spec §11 | P0 | TASK-04 |

## Operational (REQ-O)

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-O-001 | Prisma schema updated for v2 with PostGIS columns via `Unsupported` or raw SQL; `prisma generate`, typecheck and lint pass | Spec §6 | P0 | TASK-01 |
| REQ-O-002 | `npm run demo:reset` and `db:reset` work with v2 seed | Spec §12 | P0 | TASK-01 |
| REQ-O-003 | Firebase project configuration documented (Android app, SHA fingerprints, service account for the API) without committing secrets | Spec D8 | P0 | TASK-04 |
| REQ-O-004 | Cloudflare R2 storage driver implemented behind the storage interface and selectable by `STORAGE_DRIVER` | Spec D12 | P0 | TASK-13 |
| REQ-O-005 | Staging and pilot environments: API behind HTTPS, managed PostgreSQL with PostGIS, environment variables documented | Spec D12 | P0 | TASK-13 |
| REQ-O-006 | Daily database backup, R2 versioning, and a restore drill recorded before launch | Spec §12 | P0 | TASK-13 |
| REQ-O-007 | Uptime monitoring on `/health` and error alerting without PII | Spec §12 | P0 | TASK-13 |
| REQ-O-008 | Android release signing, Play internal and closed testing tracks, Data safety form matching §11 | Spec §12 | P0 | TASK-13 |
| REQ-O-009 | Full v2 end-to-end verification on emulator and a physical low-end Android phone; coverage matrix closed | Spec §12 | P0 | TASK-14 |
| REQ-O-010 | Accessibility audit (TalkBack, largest font, Gujarati) of report, issue detail, alerts and My Ward | DS §7 | P0 | TASK-14 |
| REQ-O-011 | Pilot launch checklist: 5 West-zone wards seeded with verified representatives, services and moderators onboarded | Spec D5 | P0 | TASK-14 |
| REQ-O-012 | v1 spec documents marked superseded where v2 differs; summary links to v2 spec | Spec header | P1 | TASK-14 |

## Deferred / out of scope (v2)

| Req ID | Requirement | Source | Reason | Decided by |
|---|---|---|---|---|
| REQ-F-090 | WhatsApp reporting and WhatsApp alert delivery | Spec §1 | Phase 3; cost and template approval (₹0.115+/message) | Build lead, 2026-10-03 |
| REQ-F-091 | SMS alerts via TRAI DLT | Spec §1 | Phase 3; registration and per-message cost | Build lead, 2026-10-03 |
| REQ-F-092 | Hindi translation | Spec D4 | Phase 3 | Build lead, 2026-10-03 |
| REQ-F-093 | Ward polls (agree/disagree) | Spec §1 | Phase 3 | Build lead, 2026-10-03 |
| REQ-F-094 | Integration with AMC CCRS systems | Spec §1 | No public API; requires AMC partnership | Build lead, 2026-10-03 |
| REQ-O-090 | iOS App Store release | Spec §1 | Android first; iOS kept buildable | Build lead, 2026-10-03 |
