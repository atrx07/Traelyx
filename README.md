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

Milestones M0–M5 and M6.1–M6.7 are complete. The optional cloud schema, owner-only access controls, email-link sign-in with encrypted sessions, and explicitly consented compact-summary sync are validated. Private profile/vehicle sync includes an account-scoped offline cache, guarded revision checks, retries, and explicit two-field public-profile publication. Social supports confirmed mutual requests, participant-only name snapshots, blocking, and request limits. M6.6 adds explicit accountless local analysis and separately consented, friends-only safe comparisons by vehicle class, with server validation and withdrawal. Hosted, physical synthetic and full CI validation pass. Scoring remains an experimental synthetic baseline. M6.7 Guardian pairing is implemented with private invitations, two-sided confirmation and revocable permission preferences; hosted tests, full CI and physical screen QA pass. M6.8 alert delivery is authorized; Firebase project/Android registration are ready, and live evaluation plus background delivery are authorized for implementation. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history and export a strictly verified local-private fixture without an account or network. Drive presents truthful ready/live states, Trips presents newest-first accountless history and deep-link-safe local results, DNA presents an original accessible ring signature with individually readable dimensions, lifecycle, bounded persisted trends, provenance, and honest insufficient-history states, and selected trips can play, pause, scrub, and replay a verified offline route at 0.5×/1×/2× with synchronized marker, completed path, camera framing, coordinate-free evidence, persisted event state, and deterministic bundled commentary on one replay clock. Data & Export reports real local storage, keeps raw-retention cleanup manual and previewed, separates precise-private archives from versioned redacted summaries, and confirmation-gates raw-only and whole-trip deletion. Six explicit tones, including Silent, use allowlisted event timing, governed cooldown/context selection, verified midpoint anchors, and non-evidentiary recorded-detail expansion without a model or network. Reduced-motion and accessible-navigation preferences provide immediate/static transitions and manual replay while preserving scrub and camera access; result hierarchy, score provenance, evidence states, units, and persisted relative event magnitude are explicit without relying on color or motion. Missing distance, confidence, score, events, baseline evidence, or route position remains explicitly unavailable. The local pipeline decodes raw trips fail-closed, builds deterministic derived/confidence/replay evidence, merges ten maneuver types, audits integrity/rank trust, produces versioned evidence-eligible trip scores, aggregates verified trip dimensions into a versioned Drive DNA profile, selects an auditable personal/vehicle/context cohort, and emits complete typed reason paths for every governed event, integrity state, score, and baseline result. It uses no ML, maximum-speed reward, accusation of intent, fabricated confidence percentage, or commentary as evidence. Governed synthetic fixtures lock the raw-to-explanation contract.

## Roadmap

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
| M7 | ML & Advanced Commentary | M7.5 foundation validated; model acceptance/integration carried forward | 🔵 Active | ~2–3 weeks plus data collection | — |
| M7.1 |  | Dataset registry/import | ✅ Complete | Done | 2026-11-11 |
| M7.2 |  | EventNet baseline | ✅ Complete | Done | 2026-11-14 |
| M7.3 |  | Calibration and error analysis | ✅ Complete | Done | 2026-11-14 |
| M7.4 |  | Mobile export/inference; int8 artifact rejected | ⛔ Blocked | Re-plan required | 2026-11-14 (partial) |
| M7.5 |  | Foundation validated; real-model integration gated | 🟡 In progress | ~1–2 days plus acceptance | 2026-11-14 (partial) |
| M7.6 |  | IntegrityNet experiment | ⚪ Pending | ~1–2 days | — |
| M7.7 |  | ContextNet experiment | ⚪ Pending | ~1–2 days | — |
| M7.8 |  | DriveDNA embedding experiment | ⚪ Pending | ~1–2 days | — |
| M7.9 |  | User post-drive correction | ⚪ Pending | ~1–2 days | — |
| M7.10 |  | BYO cloud commentary | ⚪ Pending | ~1–2 days | — |
| M7.11 |  | Local AI commentary provider | ⚪ Pending | Optional; performance-gated | — |
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
