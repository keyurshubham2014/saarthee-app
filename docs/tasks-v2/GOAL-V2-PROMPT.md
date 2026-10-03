# /goal — Saarthee v2: build the civic platform, tested and emulator-verified

> Run with: `/goal execute @docs/tasks-v2/GOAL-V2-PROMPT.md`
> Work fully autonomously: do not ask me questions and do not wait for input. When a task file is silent, choose what its spec section recommends, log it as `ASSUMPTION:` in that task's §5.6, and keep going.

---

## Mission

Build Saarthee v2 from the plan in `docs/tasks-v2/`, all 14 tasks, in dependency waves, with parallel workers wherever the dependency graph allows. Every wave ends with a green, committed, tagged build I could demo. v2 **requires automated tests** (unlike v1): a task is not `Complete` until its tests pass and its acceptance criteria are verified in the running app.

Read these files first, in this order, and nothing else up front:
1. `docs/tasks-v2/00-task-summary.md`: plan, lanes, conventions, Progress Management Protocol, settled cross-task contracts (Open Questions row 7).
2. `docs/v2/design-system.md` (v2.2 "Neem"), which applies to every screen: tokens, Baloo Bhai 2 + Mukta Vaani fonts, components and the DS §6 motion catalogue. The founder's chosen look is visible in `docs/v2/design-preview.html`.
3. Then open only the task file being executed and only the `Spec §n` / `DS §n` sections it names.

## Definition of done (goal condition)

The goal is met only when **all** of the following are true and the evidence is committed:

1. **Every task TASK-01 to TASK-14 is `Complete`, or `In Review` with its open items listed.** Items that need a founder action (see "Founder-blocked items") are `Deferred — needs <exact action>` in `coverage-verification.md`. Nothing is silently dropped.
2. **The v2 core loop has been verified on the Android emulator, with screenshots in `docs/demo/v2-evidence/`:**
   - language choice, intro and home ward;
   - phone sign-in using a Firebase Auth Emulator test number;
   - Home with a ward alert;
   - Report steps 1 → 2 (camera and GPS, duplicate suggestion) → 3 → submitted;
   - the issue on Map and in the feed, then "Me too" and follow;
   - staff: moderation, acknowledge, and mark fixed with an after photo;
   - a neighbour verifies the fix ("Yes, fixed"), and the status becomes Verified;
   - Alerts: a Warning alert composed, approved by a second admin and received in the inbox;
   - My Ward: corporators shown, a relayed message sent, no personal number visible;
   - Services and an initiative RSVP;
   - representative dashboard for the ward;
   - the Gujarati locale, plus one screen at 2.0× font size;
   - **motion:** short screen recordings (`adb shell screenrecord`) in `docs/demo/v2-evidence/motion/` for every DS §6 catalogue moment, plus one run of the whole loop with system "Remove animations" on.
3. **Tests are green:**
   - `npm test` (Vitest + Supertest) in `apps/api`;
   - `flutter test` in `apps/mobile`;
   - `flutter test integration_test -d emulator-5554` for report → acknowledge → mark fixed → verify, plus the reopened case.
4. **Static gates are green:**
   - `tsc --noEmit`, ESLint, `dart analyze` and `dart format --set-exit-if-changed` with 0 errors;
   - no `TODO`, stub or placeholder screen left on any shipped route (TASK-03's P-01 to P-09 list is fully replaced).
5. **Motion quality (REQ-N-012/013):** the motion catalogue is implemented with `SaartheeMotion` tokens only (the no-`Duration(`-literal test passes); profile-build traces on the reference low-end emulator show no frame over 16 ms during catalogued motion; reduced motion produces identical content.
6. **TASK-14 privacy sweep:** `node scripts/privacy-checks.mjs` (v2 checks P2-01 to P2-12) passes, and its output is pasted into the TASK-14 §13 log.
7. **Both checkers have been run and their output pasted into the summary Change Log:**
   - `python3 docs/tasks/validate_tasks.py docs/tasks-v2/` exits 0;
   - `python3 docs/tasks-v2/check_coverage.py` shows every row at `Pass`, `Fixed` or `Deferred` with evidence, and none at `Not Verified` or `Fail`.
8. **Demo assets:**
   - `docs/demo/DEMO-v2.md`, a 7-minute click-by-click script with the start commands, seeded logins, Firebase test numbers and `adb` commands;
   - `npm run demo:reset`, which restores the seeded v2 state;
   - git tag `v2-demo` on the last green commit.

## Environment facts (do not rediscover)

- **Database:** Postgres runs in Docker on **127.0.0.1:5433**. TASK-01 switches the image to `postgis/postgis:17-3.5`; if there is no arm64 image, use the amd64 one under emulation.
- **Emulator:** `emulator-5554` (AVD `leadpilot_pixel9`, arm64). adb is at `/opt/homebrew/share/android-commandlinetools/platform-tools`.
- **App build for verification:** use the **profile build with `--target-platform android-arm64`**, because debug cold starts cause ANRs and x64 builds crash. If Gradle hangs, kill stale daemons and build a single ABI.
- **API URL from the emulator:** `http://10.0.2.2:4000/api/v1`. **GPS:** `adb emu geo fix 72.5714 23.0225` (Paldi area). **Typing:** clear the field first, then send the text in a single `adb shell input text` call.
- **`.gitignore`:** v1 lesson: anchor ignore paths (`/photos/`, not `photos/`). Never commit `.claude/` worktrees.
- **Firebase:** run the Firebase Auth Emulator (`npx firebase-tools emulators:start --only auth`) with test phone numbers for all local sign-in. Do not create real Firebase projects.

## Waves (dependency-driven; each ends with a gate)

| Wave | Work (workers in parallel) | Gate, then tag |
|---|---|---|
| 0 Preflight | Integrator: Docker, PostGIS image pull, emulator boot, `flutter doctor`, Node LTS, firebase-tools via npx. Anything unfixable gets one line in `DEMO-v2.md` "Known limitations" and you continue. | – |
| 1 Foundation | **W-API:** TASK-01 → TASK-02. **W-MOB:** TASK-03. | Migrations apply on a fresh database; the test harness runs; the new shell runs on the emulator in Gujarati and English → `v2-m1` |
| 2 Accounts and ops | **W-ACC:** TASK-04 (API + app). **W-OPS:** TASK-13, local and repo parts. | OTP sign-in via the Auth Emulator on the emulator; push notifications recorded in `notifications` |
| 3 Features | **W-REP:** TASK-05. **W-ALR:** TASK-08. **W-WARD:** TASK-09. **W-SVC:** TASK-12. | Report anything works end to end → `v2-m2`; alerts, My Ward and services work → `v2-m4` |
| 4 Lifecycle and staff | **W-LIFE:** TASK-06. **W-STAFF:** TASK-10, starting from TASK-05's merged API. | Verify and reopen loop; staff console on web and on the emulator |
| 5 Discovery and reps | **W-DISC:** TASK-07. **W-REPD:** TASK-11. | Feed, map and social actions → `v2-m3`; representative dashboard → `v2-m5` |
| 6 Launch verification | Integrator: TASK-14 plus the full Definition of done | → `v2-m6` and `v2-demo` |

Start a wave only when every dependency in the summary's graph is merged and green. Inside a wave, start all its workers at once.

## Parallel execution

Run each worker as a subagent in its own git worktree (`isolation: "worktree"`) on branch `v2/task-NN-<slug>`. You are the integrator: merge each worker's branch into `main` as soon as it has a green commit, resolve conflicts, rerun all tests and smoke-test on the emulator.

**File ownership, which prevents most conflicts:**
- **API:** a worker touches only `apps/api/src/modules/<its module>/**`, its own tests under `apps/api/test/<module>/**`, and new migrations named with a unique timestamp. Shared files (`app.ts` route mounting, `lib/errors.ts` codes, `prisma/schema.prisma`, `seed/index.ts` registration) are edited by appending only. The integrator resolves conflicts in these files.
- **Mobile:** a worker touches only `apps/mobile/lib/features/<feature>/**` and its tests. Router entries, ARB keys (in a `<feature>` prefixed block, Gujarati and English together) and the staff navigation registry are append-only. W-MOB (TASK-03) owns `lib/core/**`, the theme and the router skeleton, and must commit them first.
- **Contracts settled in the summary (row 7) are binding:**
  - one job runner, `src/jobs` from TASK-06; a worker that needs it before TASK-06 lands creates it with the same contract;
  - `OUTSIDE_SERVICE_AREA` 422;
  - `amc_problem_types` is created in TASK-05;
  - `notifications` is created in TASK-04;
  - `ENDPOINT_RETIRED` 410;
  - the single status-change function in TASK-06.

**Rules for every worker:**
- Follow the task file exactly: contracts, error codes, copy, and loading, empty, error, offline and unauthorized states.
- Write the tests named in the task's §8 (T-NN-xx, W-NN-xx) in the same commits as the code. Run static checks and tests before every commit. Commit format: `V2-TASK-NN: <what landed>`.
- Check candidate libraries on npm or pub.dev before adding them, and pin the version.
- **Never commit or log:** secrets, real phone numbers, OTPs, Firebase or FCM tokens, or personal numbers of representatives. Seeds use fictional `+9190000000NN` numbers and clearly fictional placeholder names for representatives.
- **Real public data is allowed:**
  - OpenCity ward KML;
  - the CCRS problem list snapshot (fetch it once and commit it; tests never call AMC);
  - AMC service URLs.
  Always record the source and date.
- If one item blocks you for more than 10 minutes, skip it, note it in the task's §13 log, and continue.

**At each merge, the integrator:**
1. Migrates a fresh database and seeds it.
2. Runs the API tests and the Flutter tests.
3. Runs the profile build on the emulator and smoke-tests what just landed, capturing screenshots.
4. Updates the docs per the Progress Management Protocol: task §13/§14, coverage rows with evidence, and the summary board.

## Founder-blocked items (defer, never fake)

| Needs | Do now instead | Mark |
|---|---|---|
| Real Firebase project | Firebase Auth Emulator; FCM sends behind an interface with a recording fake in dev and tests; inbox works from the `notifications` table | `Deferred — needs Firebase project` for real push delivery only |
| Play Console and signing | Build the release config and docs; build an unsigned or debug-signed bundle | `Deferred — needs Play Console` |
| Cloud hosting and domain | Production Dockerfile, compose, Caddyfile and scripts, verified locally; staging deploy steps documented | `Deferred — needs hosting account and domain` |
| Real 2026–31 corporator roster | Import tool and validation built; seed fictional placeholders labelled "Sample" | `Deferred — roster compilation` |
| IMD API access | SACHET CAP parser against a committed sample | `Deferred — IMD access` |
| Gujarati native review and legal review | Drafts flagged "pending review" | `Deferred — founder review` |
| Physical phone run | Emulator only | `Deferred — needs physical device` |

## Cut order if a wave stalls (cut from the top first)

1. P2 items and the dark theme. (Motion is not cut wholesale: if needed, drop only P2 motion such as dashboard count-ups, never the P0 motion system or the report/verify feedback.)
2. Ward scorecard, ward dashboard charts, initiative reminders.
3. IMD poller, email reply tracking for relayed messages.
4. Staff exports (keep the endpoint, verified by a test).
5. Server-side map clustering (use clustering on the phone only).

**Never cut:**
- the core loop in Definition of done item 2;
- server-side validation and authorization;
- ward scoping for representatives;
- two-person approval for Warning and Critical alerts;
- the message relay (no personal numbers);
- photo EXIF stripping and face/plate blurring;
- redaction in logs;
- idempotent issue creation;
- the independence line and source labels;
- tests for any endpoint that exists.

Every cut becomes a `Deferred — <reason>` coverage row and a line in `DEMO-v2.md` "Known limitations".

## Quality bar

- **API:** TypeScript strict; Zod on every request; parameterized SQL only (raw SQL is allowed only for PostGIS queries, using parameters); uniform error shape with stable codes; rate limits as specified; handlers stay thin, services hold the business rules.
- **Screens:** built only from Neem tokens and fonts (Baloo Bhai 2 for headings and numbers, Mukta Vaani for text); no hard-coded colours or strings (ARB only, Gujarati and English); 48 dp touch targets; every status and severity shown as icon + word; layouts work at 2.0× font size; screens never call the API directly (Riverpod layering).
- **Motion:** feels like the DS §6 "gentle spring": quick to start, slight overshoot, soft settle. Motion explains a change or confirms an action and is never decoration. Only transform, opacity and colour are animated. Reduced motion is always honoured. Nothing loops except skeletons.
- **Privacy:** reporters appear publicly only as "A resident of <ward>". Logs contain no phone numbers, tokens, OTPs or message bodies; prove it with the privacy sweep.
- **Commits:** small and frequent, so every milestone tag can be rolled back to.

## Reporting rules

- Report the truth. Anything unverified is `Not Verified` or `Deferred`, never `Pass`. Show the output of any failing check in the task's log.
- At each wave gate, print a three-line status: wave, tasks merged, tests passing / failing.
- At the end, print a final report covering:
  - tasks Complete versus In Review;
  - `check_coverage.py` numbers;
  - test counts;
  - everything deferred and its reason;
  - founder actions still needed;
  - the exact commands to start the v2 demo from a fresh terminal.
