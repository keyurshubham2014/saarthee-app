# Motion performance report (REQ-N-013, DS §6)

**Status:** emulator pre-check done 2026-10-04. **Gate not yet run** — the gate is the physical reference phone (Android 10, ≤ 3 GB RAM): `Deferred — needs the founder's low-end Android phone`.

## How it was run

- Harness: `apps/mobile/integration_test/motion_perf_test.dart` (one `traceAction` per MO row, fake data, no API) + `apps/mobile/test_driver/perf_driver.dart` (TimelineSummary per moment; fails > 16 ms worst build/raster, missed-budget frames, or a layout pass after a moment's first frame except MO-10/MO-14).
- **Icon fonts must be tree-shaken**, as in a shipped build. `flutter drive` alone does not tree-shake; it parses the full 15 MB Material Symbols font on first icon use and inflated first builds (MO-01 1,664 ms, MO-09 430 ms). Build the target APK first and drive that binary:

```
cd apps/mobile
flutter build apk --profile --target-platform android-arm64 -t integration_test/motion_perf_test.dart \
  --dart-define=APP_ENV=test --dart-define=API_BASE_URL=<api>/api/v1 --dart-define=AUTH_EMULATOR_HOST=<host>:9099
flutter drive --profile --no-dds --use-application-binary build/app/outputs/flutter-apk/app-profile.apk \
  --driver=test_driver/perf_driver.dart -d <serial>
```
`--no-dds` is required: with DDS the in-app `traceAction` cannot reach its own VM service ("Connection refused").

## Emulator pre-check (emulator-5554, Pixel 9 AVD, Android 16 arm64 on Apple silicon, Impeller/OpenGLES via gfxstream)

Raster times on this AVD are not representative (translated GPU; TASK-14 §5.6), so the raster column is informational. Build times run natively on arm64 and are an optimistic proxy for a low-end phone.

```
moment | worst build ms | worst raster ms | missed build | missed raster | layouts after frame 1 | result
MO-01 | 255.4 | 964.1 | 7 | 59 | 0 | FAIL
MO-02 | 17.5 | 48.6 | 1 | 31 | 0 | FAIL
MO-03 | 7.0 | 20.8 | 0 | 20 | 0 | FAIL
MO-04 | 44.4 | 308.9 | 4 | 26 | 0 | FAIL
MO-05 | 28.4 | 111.3 | 6 | 55 | 0 | FAIL
MO-06 | 6.5 | 22.4 | 0 | 73 | 0 | FAIL
MO-07 | 18.1 | 315.7 | 1 | 43 | 0 | FAIL
MO-08 | 138.5 | 315.1 | 10 | 128 | 0 | FAIL
MO-09 | 95.2 | 277.8 | 11 | 40 | 0 | FAIL
MO-10 | 7.7 | 20.8 | 0 | 28 | 0 | FAIL
MO-11 | 16.4 | 7.6 | 1 | 0 | 0 | FAIL
MO-12 | 7.6 | 8.0 | 0 | 0 | 0 | PASS
MO-13 | 2.7 | 11.0 | 0 | 0 | 0 | PASS
MO-14 | 25.5 | 75.6 | 6 | 40 | 0 | FAIL
MO-15 | 6.2 | 6.9 | 0 | 0 | 0 | PASS
MO-16 | 54.9 | 8.6 | 1 | 0 | 0 | FAIL
MO-17 | 40.9 | 4.2 | 1 | 0 | 0 | FAIL
MO-18 | 18.8 | 127.8 | 4 | 89 | 0 | FAIL
MO-19 | 9.1 | 158.4 | 0 | 35 | 0 | FAIL
MO-20 | 20.3 | 203.7 | 6 | 131 | 0 | FAIL
MO-21 | 72.1 | 68.7 | 1 | 30 | 0 | FAIL
MO-22 | 7.9 | 38.8 | 0 | 7 | 0 | FAIL
MO-23 | 33.0 | 130.5 | 8 | 71 | 0 | FAIL
MO-23-dashboard | 80.7 | 537.1 | 12 | 85 | 0 | FAIL
MO-24 | 31.1 | 6.6 | 1 | 0 | 0 | FAIL
MO-25 | 77.0 | 131.7 | 10 | 96 | 0 | FAIL
```

Summaries: `docs/demo/v2-evidence/motion/perf/MO-nn.timeline_summary.json`. Recordings: `docs/demo/v2-evidence/motion/`.

## Findings

| # | Finding | Status |
|---|---|---|
| 1 | **Transform/opacity/colour only:** 0 layout passes after the first frame in all 26 traces | Pass (renderer-independent) |
| 2 | **No looping flashes:** only the skeleton shimmer and the in-flight refresh chevron repeat, both 1,200 ms periods (`docs/v2/sweep-v2.md` 18b) | Pass |
| 3 | First-occurrence build spikes: MO-01 255 ms (first frame, now the launch mark only), MO-08 138, MO-09 95, MO-23-dashboard 81, MO-25 77, MO-21 72, MO-16 55 ms | Investigate on the reference phone first; candidates: warm the first screen's text/icons during the launch mark, `FadeTransition` instead of rebuilding `Opacity` in `PopIn`/`RiseIn` |
| 4 | Raster > 16 ms on most moments | Emulator artefact until measured on the phone |
| 5 | Cold start: launch mark made the first frame (commit `9a3a906`); emulator Displayed 6.2–7.3 s, of which ~4 s is Impeller-GLES setup on the translated GPU (Skia: first frame 2.2 s) | Measure on the phone with Impeller on and off (`io.flutter.embedding.android.EnableImpeller` manifest flag) before choosing |

## To close the gate (founder device)
1. Connect the reference phone (USB debugging allowed), record model, RAM, Android version, renderer in TASK-14 §13.
2. Run the two commands above three times (first after cold start). Copy `build/motion/*.timeline_summary.json` here.
3. Open any failing moment's `*.timeline.json` in DevTools, fix in the owning component, re-run.
