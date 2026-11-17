# Isolated sync pilot export selection reset

**Status:** Device repair and full source CI verified. Applies only to the separate
`io.github.atrx07.traelyx.syncpilot` development package, not Traelyx trip export.

## Symptom and cause

On the authorized Tecno/API34, capture a completed run A and then a short run B.
Select A for export, cancel the Android document picker, and request export again.
The selected journal resets to B. The guarded device check stopped before saving
the unexpected filename. All source journals remained intact.

Confirmed cause: the activity's `onPause` calls `finishRun`; that method refreshed
history even when capture was already stopped, selecting the last captured run
instead of retaining the user's selection. The document picker itself triggers
that inactive pause. Earlier Pixel smoke verified capture/export but missed the
two-run cancel/retry case.

## Repair and regression

Refresh history only when actually finalizing an active run. Inactive pause now
retains the selected row. APK version code 2 / `sync-pilot-v1.0.1` identifies the
repair; journal schema stays v1. Source fix `68d91d6` passes all four jobs in
[source CI 44085930694](https://github.com/atrx07/Traelyx/actions/runs/44085930694).
Final source pins and results are recorded in
[`sync-pilot-tecno-v1-result.json`](../reference/sync-pilot-tecno-v1-result.json).

Regression: retain A and B, select A, cancel the picker (including any keyboard
dismissal), check that A stays selected, re-export and verify the filename and
bytes against A. Background an active run to check that finalization still works;
verify earlier journals byte-for-byte across the data-preserving APK update.
Run affected build/lint, packaged boundary, host tests and full source CI.
The platform-only instrumentation regression invokes real pause/resume callbacks
with a nondefault selection and two exclusively created synthetic files. It passes
on API34 and removes its fixtures; actual picker cancel/retry, byte equality and
the prior completed journal's upgrade preservation also pass. No JUnit/Robolectric
or other new dependency is added.

All 29 affected host tests, pilot and instrumentation APK builds, Android lint and
packaged privacy/runtime checks pass. CI compiles/lints the instrumentation APK;
the device regression was executed on the Tecno, not in CI.

## Privacy and limits

No trip, account, route or sensor data was read, lost or overwritten. Only private
software-marker journals are involved. Do not publish journal aliases/timestamps,
raw UI dumps or device identifiers. No dependency or persistence migration, main
app, scoring, Guardian or model change. This repair establishes no optical timing,
driving truth, IMU health, or automatic selection recovery after process death.
