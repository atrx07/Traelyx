# M8.5 failure UX pass v1

**Status:** Complete — bounded synthetic failure/recovery and host UI pass
**Date:** 2026-11-18
**Source baseline:** `da9908f`

The [aggregate result](m8-failure-ux-v1-result.json) records local checks,
capture inventory and explicit acceptance limits. All four
[source CI jobs 44277975977](https://github.com/atrx07/Traelyx/actions/runs/44277975977)
pass for `3fab32914b9d2b7916fb0ab4d2730eb712255b0f`, including Linux captures,
full Flutter/native suites, builds/lint and packaged privacy policy. Product
repairs are in `40debce`; capture portability is corrected in `3fab329`.
Initial checkpoint `40debce` CI44275674425 was cancelled after SDK font-path
case errors stalled capture tests. The corrected helper uses exact official
archive filenames, preloads bytes and caches only successful loading. Local
font bytes match the pinned official SDK archive; captures/tests remain required.
The same initial run's unrelated benchmark packageDebug failed without a nested
cause; that unchanged target passes the fresh source run.

This bounded pass exercises production widgets/services with synthetic inputs.
No ordinary app installation, phone data access, real API key, hosted account,
provider request or distribution is involved. User permitted device UI checks;
the deterministic host fixtures cover these repairs without a platform-dependent
change. Pixel/physical-device UI, keyboard, OEM and sensor recovery remain untested
in this substep.

## Required matrix

| Area | Behavior / recovery checked |
| --- | --- |
| Low GPS | No-fix acquisition stays explicit. GPS off/reported interruption after prior fixes cannot retain a positive headline. Cumulative low-accuracy fixes produce limited-evidence copy, never a claim about current reception. A clean snapshot remains healthy. Stop stays available. |
| Corruption | Save/verification failures get a critical live headline, without a promise that missing evidence was saved. Invalid route evidence draws no partial path and changes no saved data; explicit Retry route rereads it and can display a later valid response. Existing malformed-history/result/read-error tests remain. |
| Provider failure | Network, timeout, quota, unavailable model, server, malformed and refused responses restore built-in narration. No automatic retry; a new explicit review/consent/send can recover. HTTP/body/cancellation sanitization remains covered by existing adapter/service tests. |
| Invalid key | Missing/rejected credential copy points to Cloud settings. Settings feedback remains visible outside the scrolled form. Replacing a synthetic key uses the secure-store abstraction, clears input and turns permission off without another provider request. Replay fallback remains available. |
| Offline cloud | Failed summary upload preserves local history and the exact queued payload. Pumping time makes no request. An explicit early retry respects the persisted delay and no longer claims progress; a due foreground retry can succeed. Sign-out/ownership/consent behavior is unchanged. |

## Repairs / limits

Presentation uses existing recorder health v1 counters; no thresholds, sampling,
wake policy, sensor/provider state machine or score/algorithm changes. Cumulative
interruption/low-accuracy counters remain a limitation for the drive even if a
later fix improves. The health bridge exposes no current accuracy/fix age here,
so this pass cannot certify fresh/accurate GPS. Local-save failure takes headline
priority, while GPS/motion/save details remain available in the health grid.

The live headline announces status changes through a semantic live region.
Advice is for safely parked review, and no banner promises to recreate missing
evidence. Ending a drive still requires confirmation. Provider wording avoids
raw error bodies or internal response-contract jargon. Settings feedback is
persistent, above keyboard insets, bounded to 35% of the available height and
scrollable at large text, leaving
the settings form accessible. No contact address, account or provider setting
is invented or changed outside the synthetic tests.

Retrying an invalid route does not repair, delete, reset, redownload or recreate
evidence. The test's later valid response is injected; it is not proof that a
damaged real file heals. Sync tests compare all local trip fields except the
intentional sync-state mirror; they do not assert immutable queue attempt/state
metadata. No cloud download/restore, silent opt-in or background retry is added.

See the [failure-presentation issue](../issues/2026-11-18_failure-state-presentation.md)
and [execution plan](../exec-plans/active/M8_FAILURE_UX_PASS.md).

## Reproduction / visual evidence

```powershell
flutter test test/features/bootstrap test/features/cloud_commentary test/features/summary_sync test/features/trips/presentation/trips_screen_test.dart test/widget_test.dart
flutter analyze
flutter test
```

The affected suite passes 114 tests. Eight synthetic PNG captures are written to
build/reports/failure-ux-v1: live-low-gps, live-save-failure, invalid-route,
offline-sync, cloud-credential, cloud-network, cloud-malformed and
cloud-settings-key (all suffixed -2x.png). Each is 390×844 at text scale 2, reduced
motion enabled, using cached SDK Roboto/Material fonts. The font alias is scoped
to new capture fixtures; existing tests keep their original font/layout setup.
These are production-widget host renders, not device screenshots or pixel-golden
proof. CI requires all eight valid PNG dimensions and retains them as artifacts;
it does not claim identical pixels across operating systems.

Final local analysis, all 636 Flutter tests, ordinary debug/arm64 release builds,
repository contracts and packaged Android privacy policy pass.

The key-replacement test additionally injects a 300 px keyboard inset and
checks that feedback remains above it while replacement is still possible. This
is a Flutter layout check, not a real Android IME/secure-storage/device test.

Existing shared recorder fixtures already contain one low-accuracy GPS fix.
Their old positive-headline expectations are deliberately updated to reflect
that evidence; no bridge fixture, threshold or acquisition behavior was changed.

No schema migration, dependency, permission, network payload or privacy expansion.
Actual provider/key acceptance, Android keyboard/accessibility services, physical
GPS/storage faults, OEM/background reliability and signed-device upgrades remain
unverified. Recorder profiling/private reporting and carried M6.8/M7 acceptance
remain release gates. Stop after M8.5; M8.6 needs explicit authorization.
