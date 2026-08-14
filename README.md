# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Milestones M0–M2 and M3.1 are complete. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history and export a strictly verified local-private fixture without an account or network. M3.1 now decodes complete raw trips fail-closed and builds a deterministic, versioned local analysis timeline with bounded IMU interpolation, explicit missingness, preserved provenance, and sparse original GNSS evidence. M3 remains active but M3.2 awaits explicit authorization.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass. Completed and future milestones use one summary row; only the currently authorized active milestone expands all of its canonical substeps.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder, recovery, private export, and real-drive fixture | ✅ Complete | Done | 2026-08-14 |
| M3 | Telemetry Processing Engine | Trustworthy derived telemetry | 🟡 In progress | ~1–2 weeks | 2026-08-14 |
| M3.1 | Telemetry Processing Engine | Decoder/resampler | ✅ Complete | Done | 2026-08-14 |
| M3.2 | Telemetry Processing Engine | GNSS sanity filtering | ⚪ Pending | ~1–2 days | — |
| M3.3 | Telemetry Processing Engine | IMU calibration | ⚪ Pending | ~1–2 days | — |
| M3.4 | Telemetry Processing Engine | Orientation/frame transform | ⚪ Pending | ~1–2 days | — |
| M3.5 | Telemetry Processing Engine | Derived channels | ⚪ Pending | ~1–2 days | — |
| M3.6 | Telemetry Processing Engine | Telemetry confidence v1 | ⚪ Pending | ~1 day | — |
| M3.7 | Telemetry Processing Engine | Replay channel generator | ⚪ Pending | ~1 day | — |
| M3.8 | Telemetry Processing Engine | Fixture regression corpus | ⚪ Pending | ~1–2 days | — |
| M4 | Deterministic Intelligence v1 | Driver intelligence milestone | ⚪ Pending | ~1–1.5 weeks | — |
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
