# /goal — Saarthee: autonomous 2-hour build to a demo-ready, emulator-verified app

> Paste everything below the line into `/goal`. Work fully autonomously: do not ask me questions, do not wait for input.
> When the spec is silent, choose the option the spec recommends, log it as `ASSUMPTION` in the task file, and keep going.

---

## Mission

Build Saarthee from the plan in `docs/tasks/` within **120 minutes of wall-clock time**, and finish with a demo that is **verified end to end on an Android emulator**. Run things in parallel wherever it saves time. Hold the quality bar the plan defines. At every moment there must be a committed, working build I could demo.

Read these files first, in this order, and nothing else up front:
1. `docs/tasks/00-task-summary.md` — the plan, conventions and Progress Management Protocol.
2. Then open only the task file you are executing, and only the spec sections that file names.

## Definition of done (this is the goal condition)

The goal is met only when **all** of the following are true and the evidence is committed:

1. **Core demo loop verified on the Android emulator** (milestone M1), with screenshots saved in `docs/demo/evidence/`:
   1. first launch;
   2. invite code;
   3. report all six steps, including the emulator camera and a GPS fix;
   4. report recorded;
   5. admin login;
   6. Due list;
   7. Send reminder, with the sheet showing the message and the `saarthee://` link;
   8. the deep link fired with `adb`;
   9. verify "Not fixed" with a photo and a note;
   10. Rates screen showing the changed H2.
2. **Every task TASK-01…TASK-09 is either `Complete`, or `In Review` with its unfinished parts listed.** Unfinished parts are marked `Deferred` in `coverage-verification.md` with the reason "2-hour demo timebox". Nothing unfinished is silently dropped.
3. **TASK-10, emulator-scoped:**
   - the end-to-end flows in `06-security-testing.md §10.1` have been run on the emulator;
   - the privacy checks that can run locally have passed (log grep for a test phone number and a verify token, CSV without phone, revoked link rejected, 5 bad logins give 429, stored photo has no EXIF);
   - physical-phone, iPhone and real-WhatsApp items are marked `Deferred — needs physical device`, not faked.
4. **Quality gates are green:**
   - `tsc --noEmit`, ESLint, `dart analyze` and `dart format --set-exit-if-changed` all pass with 0 errors;
   - no `TODO`, stub, mock data or placeholder screens remain on the demo path.
5. **Both checkers have been run and their output pasted into the summary Change Log:**
   - `python3 docs/tasks/validate_tasks.py docs/tasks/` exits 0;
   - `python3 docs/tasks/check_coverage.py` has every row at `Pass`, `Fixed` or `Deferred` with evidence (none at `Not Verified` or `Fail`).
6. **Demo assets exist:**
   - `docs/demo/DEMO.md`: a 5-minute click-by-click demo script with the exact commands to start everything, the seeded logins and codes, and the `adb` deep-link command;
   - a one-command reset that brings the demo back to a known seeded state (`npm run demo:reset`);
   - git tag `demo-final` on the last green commit.

## Time plan with hard checkpoints

Check the clock at every checkpoint (`date`), and record elapsed time in the summary Change Log. **If you are behind at a checkpoint, cut scope using the cut order below. Never extend the timebox, and never break the demo loop.**

| Elapsed | Checkpoint | Must be true |
|---|---|---|
| 0–10 min | **Preflight** | Docker running, Postgres container healthy, `flutter doctor` passes for Android, an emulator is booted (`flutter emulators --launch <id>` or create a Pixel API 34 AVD), Node LTS present. Fix what you can; anything you can't fix gets one line in `DEMO.md` "Known limitations", and you continue. |
| 10–30 min | **Foundation** | TASK-01 and TASK-02 are done (sequential, by you). The API's `/health` reports ok with the database, migrations and seed are applied, and `SEED-EXPECTATIONS.md` matches `pilot_rates_v`. Commit and tag `demo-safe-0`. |
| 30–75 min | **Parallel build** | The three parallel workers below each deliver their slice, and you merge after each worker commit. |
| 75 min | **M1 gate** | Core demo loop (Definition of done, item 1) works on the emulator. Commit and tag `demo-safe-1`. **This is the demo you fall back to.** |
| 75–100 min | **Complete** | Finish TASK-08 and TASK-09 and the remaining P0/P1 acceptance criteria; harden error, loading and empty states on the demo path. |
| 100–112 min | **Verify** | TASK-10 on the emulator: §10.1 flows, privacy checks, coverage matrix, both checkers. |
| 112–120 min | **Freeze** | `DEMO.md`, `demo:reset`, final dry run of the demo script on the emulator from a reset, then tag `demo-final`. **No feature work after 112 min.** |

## Parallel execution

After Foundation, spawn **three subagents at once**, each in its own git worktree (`isolation: "worktree"`) on its own branch. They work in directories that don't overlap. You are the integrator: merge each branch into `main` as soon as it lands a green commit, resolve conflicts, and run the integration checks. Give each worker the paths of its task files and the shared rules below.

| Worker | Owns (only touches) | Delivers, in order |
|---|---|---|
| **W1 API** | `apps/api/**` | TASK-04 API (categories, storage + photo pipeline, `/photos`, `/reports`, cleanup) → TASK-05 API (admin:create, login, guard, me, logout-all, rate limits, audit log) → TASK-06 API (complaints list + due, reminders, rates) → TASK-07 API (verify guard, verify endpoints) → TASK-08/09 API (detail, admin photos, revoke, exclusion, anonymize, export, invite codes, categories). After each endpoint group, verify with curl against the seeded database and record the commands in the task file's §8. |
| **W2 Mobile citizen** | `apps/mobile/**` except `lib/features/admin/**` | TASK-03 first, and commit `lib/core/**` early (by elapsed 45 min) so W3 can build on it → TASK-04 app (six steps, draft persistence, camera, GPS, upload) → TASK-07 app (deep link, enter-code, verify screens). W2 owns the router file, ARB files and theme. |
| **W3 Mobile admin** | `apps/mobile/lib/features/admin/**` + `lib/router/admin_routes.dart` | Starts as soon as W2 commits `lib/core/**` (build against the API contracts in the task files until W1's endpoints land). Delivers TASK-05 app (login, secure storage, guard, tabs, More) → TASK-06 app (Due, reminder sheet, Rates) → TASK-08/09 app (All complaints, detail, exclusion, anonymize, export, invite codes, categories). Puts admin ARB keys under an `admin` prefix in a block that W2 merges. |

Shared rules for every worker:
- Follow the task file exactly: its contracts, error codes, copy text, and loading, empty, error and unauthorized states.
- No mock data left behind. Build against the real API contract.
- Run static checks before every commit. Commit format: `TASK-NN: <what landed>`.
- Check candidate libraries on npm/pub.dev before adding them, and pin the version you choose.
- Never put secrets, real phone numbers or verify tokens in code, logs or commits.
- If blocked for more than 5 minutes on one item, skip it, record it in the task file's §13 log, and move on.

You (integrator), at each merge: run the API, then run the app on the emulator against `http://10.0.2.2:<API_PORT>/api/v1`, and smoke-test the flows that just landed. Then update the docs per the Progress Management Protocol: task file §13/§14, the coverage matrix rows, and the summary board.

## Emulator E2E verification method

The founder chose no automated unit tests, so drive the real app on the emulator and capture evidence:
- **Build and run:** `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 --dart-define=APP_ENV=development …` (use the run configuration from TASK-03).
- **GPS:** `adb emu geo fix 72.5714 23.0225` (Ahmedabad) before photo steps. **Camera:** the emulator's virtual scene camera.
- **Deep link:** `adb shell am start -a android.intent.action.VIEW -d "saarthee://verify?t=<token>" <applicationId>`. Also test the manual enter-code path.
- **Drive and observe:**
  - for repeatable flows, write a Flutter `integration_test` script for the core loop (report → verify) and run it with `flutter test integration_test -d emulator-5554`; this is the verification harness for the demo, not unit tests;
  - for anything else, use `adb shell input tap/text`, `adb exec-out screencap -p > docs/demo/evidence/<step>.png`, and look at the screenshot to confirm the screen state;
  - API side, confirm with curl and SQL against the database;
  - if iOS Simulator and Xcode are available, repeat the core loop there too (`xcrun simctl openurl booted "saarthee://verify?t=…"`); otherwise mark it Deferred.
- **Record evidence:** every verified requirement gets a `Pass` row in `coverage-verification.md` with the evidence: a screenshot file name, a curl command, a SQL query or a commit hash.

## Cut order when behind (cut from the top first)

1. P2 items (rates snapshot script, optional weekly audit, log rotation, optional Vitest tests).
2. P1 polish: "Your reports on this phone", the distance highlight, drag-to-reorder (keep add, edit and deactivate).
3. Invite code and category management screens. Keep their API, and keep the seeded data so the demo still works.
4. CSV export screen. Keep the endpoint, verified with curl.
5. Anonymize UI. Keep the endpoint, verified with curl.

**Never cut:**
- the core demo loop;
- server-side validation and authorization on any endpoint that exists;
- verify-token hashing and header-only transport;
- phone and token redaction in logs;
- report idempotency;
- draft persistence across the CCRS hand-off;
- correct H1/H2 against the seed expectations.

Every cut becomes a `Deferred — 2-hour demo timebox` row in the coverage matrix and a line in `DEMO.md` "Known limitations".

## Quality bar (enterprise grade, applied inside the timebox)

- TypeScript strict; same error shape and stable error codes everywhere; Zod (candidate) validation on every request; parameterized SQL only; helmet headers; rate limits as specified.
- Every screen on the demo path:
  - built from the design tokens, with no hard-coded colours or strings (ARB only);
  - working loading, empty, error, offline and in-flight (disabled button) states;
  - 48 px touch targets and labelled controls.
- Riverpod layering: screens never call the API directly.
- Logs contain no phone numbers, tokens, passwords or request bodies. Prove this with a grep in TASK-10.
- Commit small and often, so every milestone can be rolled back to.

## Reporting rules

- Report the truth. Something unverified is `Not Verified` or `Deferred`, never `Pass`. Show any failing check's output in the task log.
- At the end, print a short final report:
  - elapsed time;
  - tasks complete versus in review;
  - coverage numbers from `check_coverage.py`;
  - what was deferred and why;
  - the exact commands to start the demo from a fresh terminal.
