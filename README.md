# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Milestones M0 and M1 are complete. M2 is active and M2.8 first real-drive fixture work was authorized on 2026-08-12. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history without an account or network. The local-private export path and clean Tecno rehearsal are validated. A first 41-minute field attempt finalized intact but exposed an 11-minute leading GPS gap; live first-fix readiness is being validated before the required repeat.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass. Completed and future milestones use one summary row; only the currently authorized active milestone expands all of its canonical substeps.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder milestone | 🚧 In Progress | ~1.5–2 weeks | 2026-08-11 |
| M2.1 | Native Recording Engine | Foreground service lifecycle | ✅ Complete | Done | 2026-08-09 |
| M2.2 | Native Recording Engine | GNSS acquisition | ✅ Complete | Done | 2026-08-09 |
| M2.3 | Native Recording Engine | IMU acquisition | ✅ Complete | Done | 2026-08-09 |
| M2.4 | Native Recording Engine | Crash-safe buffering | ✅ Complete | Done | 2026-08-09 |
| M2.5 | Native Recording Engine | Flutter↔Kotlin bridge | ✅ Complete | Done | 2026-08-11 |
| M2.6 | Native Recording Engine | Permissions/onboarding | ✅ Complete | Done | 2026-08-11 |
| M2.7 | Native Recording Engine | Service recovery tests | ✅ Complete | Done | 2026-08-11 |
| M2.8 | Native Recording Engine | First real-drive fixture | 🚧 In Progress | ~1 day plus drive | — |
| M3 | Telemetry Processing Engine | Trustworthy derived telemetry | ⚪ Pending | ~1–2 weeks | — |
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
