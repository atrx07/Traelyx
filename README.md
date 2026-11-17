# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

M7.1 dataset registry/import is complete under an explicit development-order
exception. M6.8 remains incomplete: physical active-driver, recovery, performance
and mounted/vehicle/OEM acceptance carries forward; vehicle work stays deferred.
M7.1–M7.3 are complete at the experimental level. M7.4 export tooling and three isolated phone benchmarks are recorded; float and native parity pass, but the prescribed int8 artifact fails probability drift (0.0509469 >0.05) and remains rejected. Its graph is larger than float32 and has no consistent speed advantage. All 63 local Python tests and all four [source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43611844686) pass, including standalone APK/privacy checks and full app builds. M7.4 numerical acceptance remains blocked, with no app integration or promotion. Battery, severe/normal truth and M6.8 physical/vehicle gates remain open. See [aggregate evidence](docs/reference/eventnet-mobile-v1-result.json) and [protocol](docs/reference/EVENTNET_MOBILE_V1.md).
See [ML tooling](ml/README.md) and the [M7 plan](docs/exec-plans/active/M7_ML_COMMENTARY.md).

The M7.5 provider/audit/fallback foundation is implemented and validated with
501 app-native tests, 19 targeted Flutter tests and all four
[source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43615278473).
Production inference stays disabled; full model integration remains gated.
The active plan retains the acceptance checklist. M7.4's rejection and M6.8's
physical/vehicle gates are not waived. See [foundation evidence](docs/reference/hybrid-event-evidence-v1-result.json).

M7.6's generated-only IntegrityNet experiment is complete: a 98-parameter CPU
autoencoder flags 6/6 numeric injections vs native rules' 4/6, with zero flags on
16 known clean test fixtures for both. All 74 Python/502 app-native tests and
[four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43689186048)
pass, including native→CPU comparison and byte-identical within-platform repeats.
This small shared-template comparison does not establish field FPR, superiority
over strengthened rules or production acceptance. Inference stays disabled;
all previous gates remain open. See [protocol](docs/reference/INTEGRITYNET_BASELINE_V1.md)
and [aggregate evidence](docs/reference/integritynet-generated-v1-result.json).

Milestones M0–M5 and M6.1–M6.7 are complete. The optional cloud schema, owner-only access controls, email-link sign-in with encrypted sessions, and explicitly consented compact-summary sync are validated. Private profile/vehicle sync includes an account-scoped offline cache, guarded revision checks, retries, and explicit two-field public-profile publication. Social supports confirmed mutual requests, participant-only name snapshots, blocking, and request limits. M6.6 adds explicit accountless local analysis and separately consented, friends-only safe comparisons by vehicle class, with server validation and withdrawal. Hosted, physical synthetic and full CI validation pass. Scoring remains an experimental synthetic baseline. M6.7 Guardian pairing is implemented with private invitations, two-sided confirmation and revocable permission preferences; hosted tests, full CI and physical screen QA pass. M6.8 alert delivery is authorized; Firebase project/Android registration are ready, and live evaluation plus background delivery are authorized for implementation. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history and export a strictly verified local-private fixture without an account or network. Drive presents truthful ready/live states, Trips presents newest-first accountless history and deep-link-safe local results, DNA presents an original accessible ring signature with individually readable dimensions, lifecycle, bounded persisted trends, provenance, and honest insufficient-history states, and selected trips can play, pause, scrub, and replay a verified offline route at 0.5×/1×/2× with synchronized marker, completed path, camera framing, coordinate-free evidence, persisted event state, and deterministic bundled commentary on one replay clock. Data & Export reports real local storage, keeps raw-retention cleanup manual and previewed, separates precise-private archives from versioned redacted summaries, and confirmation-gates raw-only and whole-trip deletion. Six explicit tones, including Silent, use allowlisted event timing, governed cooldown/context selection, verified midpoint anchors, and non-evidentiary recorded-detail expansion without a model or network. Reduced-motion and accessible-navigation preferences provide immediate/static transitions and manual replay while preserving scrub and camera access; result hierarchy, score provenance, evidence states, units, and persisted relative event magnitude are explicit without relying on color or motion. Missing distance, confidence, score, events, baseline evidence, or route position remains explicitly unavailable. The local pipeline decodes raw trips fail-closed, builds deterministic derived/confidence/replay evidence, merges ten maneuver types, audits integrity/rank trust, produces versioned evidence-eligible trip scores, aggregates verified trip dimensions into a versioned Drive DNA profile, selects an auditable personal/vehicle/context cohort, and emits complete typed reason paths for every governed event, integrity state, score, and baseline result. It uses no ML, maximum-speed reward, accusation of intent, fabricated confidence percentage, or commentary as evidence. Governed synthetic fixtures lock the raw-to-explanation contract.

## Roadmap

M7.7's generated ContextNet experiment is complete with no validated added value:
selective validation macro F1 is 0.60 vs temporal rules' 1.00, with worse coverage
and open-case handling. Test predictions remain uncomputed after the failed
validation gate. All 86 local Python tests and
[four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43692438655)
pass, including full app regressions and debug/release builds. See
[aggregate evidence](docs/reference/contextnet-generated-v1-result.json).
Production inference stays disabled; earlier acceptance gates remain open.

M7.8's generated DriveDNA embedding experiment is complete. Both methods retrieve
all 80 validation programs and detect 40/40 controlled changes; embedding stable
pair false flags are 2/40 versus 5/40 for summary distances. Its prespecified value gate
still fails, leaving test predictions uncomputed and explicit dimensions intact.
All 99 local Python tests and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43716929988)
pass, including both app builds. See [aggregate evidence](docs/reference/drivedna-generated-v1-result.json).
These are generated diagnostics, not real driving-style acceptance.

M7.9 adds local source-bound event notes and separately reviewed categorical
exports, with a private quarantine-only receiver. Schema4 preserves earlier
trip evidence; notes never change scores or safety state. All 503 Flutter/506
native/105 Python tests, offline generated emulator QA and
[four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43727767552)
pass. No automatic upload/training, new dependency or model promotion. See
[contract](docs/reference/EVENT_CORRECTION_V1.md) and
[aggregate evidence](docs/reference/event-correction-v1-result.json).
Model and physical/vehicle acceptance remain open/deferred.

M7.10 adds optional Groq BYO-key settings, secure credentials, dynamic models
and separately reviewed categorical requests selecting approved replay wording.
The offline narrator stays available; no schema migration or new package/runtime.
All 535 Flutter/506 native/105 Python tests, isolated Pixel/live synthetic Groq
checks and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43835667477)
pass. Temporary QA key/app removed; the existing production app was untouched.
This bounded v1 does not establish free-form narration quality or close any
sensor-model/vehicle gate. See [contract](docs/reference/CLOUD_COMMENTARY_V1.md)
and [aggregate evidence](docs/reference/cloud-commentary-v1-result.json).

M7.11 completes the local-provider architecture: reviewed manifests/admission,
verified private artifact storage and explicit status/removal. The production
catalog is empty; no model weights, inference SDK or real download transport is
activated. All 592 Flutter/509 native/105 Python tests, generated-only Pixel QA,
builds/lint/schema checks and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43886630798)
pass. Crypto 3.0.7 is now direct; no resolved package or database version changed.
See [contract](docs/reference/LOCAL_COMMENTARY_V1.md) and
[aggregate evidence](docs/reference/local-commentary-v1-result.json). Physical
performance/quality and earlier model/vehicle acceptance remain open.

The [M7 exit audit](docs/reference/M7_EXIT_AUDIT_2026-11-16.md) recommends M8
hardening with unaccepted ML disabled. The maintainer subsequently chose to tackle
M7.4/M7.5 acceptance first. [Recording intake](docs/reference/EVENTNET_RECORDING_INTAKE_V1.md)
preserves old phone evidence but admits no training/evaluation data. All 120 local
Python tests and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43904210026)
pass for the intake tool. Formal M7 exit,
M8 activation and public release remain open.
Further [public-source qualification](docs/reference/EVENTNET_PUBLIC_QUALIFICATION_V1.md)
records concrete label/group/timing limits. Manual Redmi stationary export
verifies high reported IMU accuracy but no GNSS fixes. All 131 local Python tests
and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43911237347) pass.
No production model is accepted.
The [Q-Motion metadata audit](docs/reference/QMOTION_METADATA_QUALIFICATION_V1.md)
and [native input proposal](docs/reference/EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md)
record the next corpus/feature requirements; no new candidate is trained or promoted.
All 142 local Python tests and
[four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/44028381119)
pass for this qualification. Independent negative exposure and native feature
equivalence still block model acceptance.

The [feature feasibility slice](docs/reference/EVENTNET_FEATURE_FEASIBILITY_V1.md)
now implements an unwired native input extractor and measures one real public
development recording. All 519 native and 150 Python tests, lint and debug build
and [four source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/44035810697)
pass. Its approximately 400 Hz timing is sufficient for probing; source semantics,
input-quality policy, independent evaluation and model acceptance remain open.
No production inference or device operation is enabled.

The separate [v2 input-quality proposal](docs/reference/EVENTNET_INPUT_QUALITY_V2.md)
constructs development windows with bounded interpolation and mandatory quality
metadata. All 528 native tests pass; strict v1 and M3 confidence remain unchanged.
Lint/debug build and repository validation pass; source CI pending. No model is trained/promoted, and no production
inference, device use, schema or dependency is added.

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass. Completed and future milestones use one summary row; only the currently authorized active milestone expands all of its canonical substeps.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder, recovery, private export, and real-drive fixture | ✅ Complete | Done | 2026-08-14 |
| M3 | Telemetry Processing Engine | Trustworthy derived telemetry and governed regression corpus | ✅ Complete | Done | 2026-08-21 |
| M4 | Deterministic Intelligence v1 | Events, integrity, scoring, Drive DNA, lifecycle, and explanation data | ✅ Complete | Done | 2026-08-23 |
| M5 | Experience & Replay | Ready/Drive, history/results, Drive DNA, offline route replay, commentary, accessibility, and local data controls | ✅ Complete | Done | 2026-09-23 |
| M6 | Connected / Social Layer | M6.1–M6.7 complete; M6.8 acceptance carried forward, vehicle checks deferred | 🟡 In progress | Deferred acceptance | 2026-11-11 (partial) |
| M7 | ML & Advanced Commentary | M7.4/M7.5 acceptance follow-up active; M8 inactive | 🔵 Active | ~2–3 weeks plus data collection | — |
| M7.1 |  | Dataset registry/import | ✅ Complete | Done | 2026-11-11 |
| M7.2 |  | EventNet baseline | ✅ Complete | Done | 2026-11-14 |
| M7.3 |  | Calibration and error analysis | ✅ Complete | Done | 2026-11-14 |
| M7.4 |  | V1 int8 rejected; recording/data qualification active | ⛔ Blocked | Re-plan required | 2026-11-14 (partial) |
| M7.5 |  | Foundation validated; real-model integration gated | 🟡 In progress | ~1–2 days plus acceptance | 2026-11-14 (partial) |
| M7.6 |  | IntegrityNet generated experiment vs native rules | ✅ Complete | Done | 2026-11-15 |
| M7.7 |  | ContextNet generated experiment; no added value, rules retained | ✅ Complete | Done | 2026-11-15 |
| M7.8 |  | DriveDNA generated embedding; value gate unmet, dimensions retained | ✅ Complete | Done | 2026-11-15 |
| M7.9 |  | Local post-drive corrections and consented categorical export | ✅ Complete | Done | 2026-11-15 |
| M7.10 |  | BYO Groq reviewed-wording commentary | ✅ Complete | Done | 2026-11-16 |
| M7.11 |  | Local-provider architecture; runtime/model activation gated | ✅ Complete | Done | 2026-11-16 |
| M8 | Hardening & Public Release | Release candidate to v0.1.0 | ⚪ Pending | ~1–1.5 weeks | — |

## Development

Prerequisites are Flutter stable, an Android SDK with accepted licenses, and the JDK selected by Flutter.

```text
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
cd android && ./gradlew testDebugUnitTest
flutter build apk --release
dart run tool/validate_repository.dart
dart run tool/report_apk_size.dart
```

Read `AGENTS.md`, `docs/index.md`, and the active execution plan before making non-trivial changes.
