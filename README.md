# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Milestones M0–M3 and M4.1–M4.6 are complete. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history and export a strictly verified local-private fixture without an account or network. The local pipeline decodes raw trips fail-closed, builds deterministic derived/confidence/replay evidence, merges ten maneuver types, audits integrity/rank trust, produces versioned evidence-eligible trip scores, aggregates verified trip dimensions into a versioned Drive DNA profile, and now selects an auditable personal/vehicle/context cohort with explicit uncalibrated, emerging, established, or recalibrating state. Early, cross-vehicle, changed-context, or stale history cannot silently become the current baseline; scoring-v1 history is unchanged. It uses no ML, maximum-speed reward, accusation of intent, or fabricated confidence percentage. Governed synthetic fixtures lock the raw-to-lifecycle contract. M4 remains active, but M4.7 awaits explicit authorization.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass. Completed and future milestones use one summary row; only the currently authorized active milestone expands all of its canonical substeps.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder, recovery, private export, and real-drive fixture | ✅ Complete | Done | 2026-08-14 |
| M3 | Telemetry Processing Engine | Trustworthy derived telemetry and governed regression corpus | ✅ Complete | Done | 2026-08-21 |
| M4 | Deterministic Intelligence v1 | Driver intelligence milestone | 🟡 In progress | ~0.5–1 day | 2026-08-23 |
| M4.1 | Deterministic Intelligence v1 | Event taxonomy implementation | ✅ Complete | Done | 2026-08-21 |
| M4.2 | Deterministic Intelligence v1 | Event merge/debounce | ✅ Complete | Done | 2026-08-21 |
| M4.3 | Deterministic Intelligence v1 | Integrity rules v1 | ✅ Complete | Done | 2026-08-22 |
| M4.4 | Deterministic Intelligence v1 | Scoring v1 | ✅ Complete | Done | 2026-08-22 |
| M4.5 | Deterministic Intelligence v1 | Drive DNA baseline | ✅ Complete | Done | 2026-08-22 |
| M4.6 | Deterministic Intelligence v1 | Personal/vehicle baseline lifecycle | ✅ Complete | Done | 2026-08-23 |
| M4.7 | Deterministic Intelligence v1 | Explanation data | ⚪ Pending | ~0.5–1 day | — |
| M5 | Experience & Replay | Product experience milestone | ⚪ Pending | ~1.5–2 weeks | — |
| M6 | Connected / Social Layer | Optional connected milestone | ⚪ Pending | ~1–1.5 weeks | — |
| M7 | ML & Advanced Commentary | Auditable intelligence milestone | ⚪ Pending | ~2–3 weeks plus data collection | — |
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
