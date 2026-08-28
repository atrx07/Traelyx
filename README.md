# Traelyx

Traelyx is an open-source, local-first driving telemetry and driver intelligence platform. Core recording, analysis, history, and replay are designed to work without an account or mandatory cloud access.

## Current state

Milestones M0–M4 and M5.1–M5.7 are complete. A ready Android device can record through lifecycle, network, and GNSS interruptions, then finalize verified native chunks into local Drift history and export a strictly verified local-private fixture without an account or network. Drive presents truthful ready/live states, Trips presents newest-first accountless history and deep-link-safe local results, DNA presents an original accessible ring signature with individually readable dimensions, lifecycle, bounded persisted trends, provenance, and honest insufficient-history states, and selected trips can play, pause, scrub, and replay a verified offline route at 0.5×/1×/2× with synchronized marker, completed path, camera framing, coordinate-free evidence, persisted event state, and deterministic bundled commentary on one replay clock. Six explicit tones, including Silent, use allowlisted event timing, governed cooldown/context selection, verified midpoint anchors, and non-evidentiary recorded-detail expansion without a model or network. Missing distance, confidence, score, events, baseline evidence, or route position remains explicitly unavailable. The local pipeline decodes raw trips fail-closed, builds deterministic derived/confidence/replay evidence, merges ten maneuver types, audits integrity/rank trust, produces versioned evidence-eligible trip scores, aggregates verified trip dimensions into a versioned Drive DNA profile, selects an auditable personal/vehicle/context cohort, and emits complete typed reason paths for every governed event, integrity state, score, and baseline result. It uses no ML, maximum-speed reward, accusation of intent, fabricated confidence percentage, or commentary as evidence. Governed synthetic fixtures lock the raw-to-explanation contract. M5 remains active at the explicit M5.8 approval gate.

## Roadmap

Roadmap status is a human-readable mirror of the authoritative [roadmap](docs/exec-plans/ROADMAP.md), [project status](STATUS.md), [priority queue](NEXTSTEPS.md), and [active execution plans](docs/exec-plans/active/). A substep is marked complete only after its required validation gates pass. Completed and future milestones use one summary row; only the currently authorized active milestone expands all of its canonical substeps.

| ID | Milestone | Step | Status | ETA | Last validated |
|---|---|---|---|---|---|
| M0 | Project Bootstrap | Skeleton milestone | ✅ Complete | Done | 2026-08-08 |
| M1 | Application Foundation | Theme, navigation, settings, schema migrations, diagnostics | ✅ Complete | Done | 2026-08-09 |
| M2 | Native Recording Engine | Reliable recorder, recovery, private export, and real-drive fixture | ✅ Complete | Done | 2026-08-14 |
| M3 | Telemetry Processing Engine | Trustworthy derived telemetry and governed regression corpus | ✅ Complete | Done | 2026-08-21 |
| M4 | Deterministic Intelligence v1 | Events, integrity, scoring, Drive DNA, lifecycle, and explanation data | ✅ Complete | Done | 2026-08-23 |
| M5 | Experience & Replay | Product experience milestone | 🔵 Active | ~1.5–2 weeks | 2026-08-28 |
| M5.1 |  | Ready/Drive screen — glanceable recorder health and safe minimal live mode | ✅ Complete | Done | 2026-08-25 |
| M5.2 |  | Trip history/result — rich result hierarchy with confidence and integrity | ✅ Complete | Done | 2026-08-25 |
| M5.3 |  | Drive DNA visual — original signature treatment, trends, and insufficient-data states | ✅ Complete | Done | 2026-08-25 |
| M5.4 |  | Map abstraction and route rendering — provider-neutral map and cache controls | ✅ Complete | Done | 2026-08-25 |
| M5.5 |  | Synchronized replay clock — map, graphs, and events on one timeline | ✅ Complete | Done | 2026-08-25 |
| M5.6 |  | Replay animations — camera, marker/path, events, pause, scrub, and speed | ✅ Complete | Done | 2026-08-25 |
| M5.7 |  | Procedural road commentary — governed tone, context, cooldown, and anchored bubbles | ✅ Complete | Done | 2026-08-28 |
| M5.8 |  | Reduced motion and accessibility — alternative transitions and accessible metrics | ⚪ Pending | — | — |
| M5.9 |  | Storage manager/export — retention, map cache, debug export, and anonymization | ⚪ Pending | — | — |
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
