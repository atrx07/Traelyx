# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Stage 0 bootstrap is active. The canonical Flutter/Android repository scaffold is validated, and toolchain constraints are the current step.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A step is marked complete only after its required validation gates pass.

| ID | Stage / Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Stage 0 — Governance & Project Bootstrap | Skeleton milestone | 🟡 In progress | ~1 day remaining | 2026-08-08 |
| 0.1 | Stage 0 | Confirm identity | ✅ Complete | Done | 2026-08-08 |
| 0.2 | Stage 0 | Initialize repository | ✅ Complete | Done | 2026-08-08 |
| 0.3 | Stage 0 | Toolchain pinning | 🔵 Active | ~1 hour | — |
| 0.4 | Stage 0 | Quality commands | ⚪ Pending | ~1–2 hours | — |
| 0.5 | Stage 0 | CI foundation | ⚪ Pending | ~1–2 hours | — |
| 0.6 | Stage 0 | Core architecture skeleton | ⚪ Pending | ~2–4 hours | — |
| Stage 1 | Application Foundation | Theme, navigation, settings, schema, migrations, diagnostics | ⚪ Pending | ~4–6 days | — |
| M1 / Stage 2 | Native Recording Engine | Reliable recorder milestone | ⚪ Pending | ~1.5–2 weeks | — |
| M2 / Stage 3 | Telemetry Processing Engine | Trustworthy derived telemetry | ⚪ Pending | ~1–2 weeks | — |
| M3 / Stage 4 | Deterministic Intelligence v1 | Driver intelligence milestone | ⚪ Pending | ~1–1.5 weeks | — |
| M4 / Stage 5 | Experience & Replay | Product experience milestone | ⚪ Pending | ~1.5–2 weeks | — |
| M5 / Stage 6 | Connected / Social Layer | Optional connected milestone | ⚪ Pending | ~1–1.5 weeks | — |
| M6 / Stage 7 | ML & Advanced Commentary | Auditable intelligence milestone | ⚪ Pending | ~2–3 weeks plus data collection | — |
| M7 → M8 / Stage 8 | Hardening & Public Release | Release candidate to v0.1.0 | ⚪ Pending | ~1–1.5 weeks | — |

## Development

Prerequisites are Flutter stable, an Android SDK with accepted licenses, and the JDK selected by Flutter.

```text
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
dart run tool/validate_repository.dart
dart run tool/report_apk_size.dart
```

Read `AGENTS.md`, `docs/index.md`, and the active execution plan before making non-trivial changes.
