# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Milestone M0 and roadmap substeps M1.1–M1.3 are complete. M1 remains active but is stopped at the approval gate before M1.4. Trip recording remains intentionally unavailable.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M0.1 | Project Bootstrap | Confirm identity | ✅ Complete | Done | 2026-08-08 |
| M0.2 | Project Bootstrap | Initialize repository | ✅ Complete | Done | 2026-08-08 |
| M0.3 | Project Bootstrap | Toolchain pinning | ✅ Complete | Done | 2026-08-08 |
| M0.4 | Project Bootstrap | Quality commands | ✅ Complete | Done | 2026-08-08 |
| M0.5 | Project Bootstrap | CI foundation | ✅ Complete | Done | 2026-08-08 |
| M0.6 | Project Bootstrap | Core architecture skeleton | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | 🔵 Active | ~4–6 days | 2026-08-09 |
| M1.1 | Application Foundation | Design tokens/theme | ✅ Complete | Done | 2026-08-09 |
| M1.2 | Application Foundation | Navigation | ✅ Complete | Done | 2026-08-09 |
| M1.3 | Application Foundation | Local settings | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder milestone | ⚪ Pending | ~1.5–2 weeks | — |
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
