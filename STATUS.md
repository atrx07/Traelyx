# Traelyx — Current Project State

> Keep this file short. It is meant to be inexpensive agent context. Update facts, not prose history.

## Current phase

**Phase 0 — Governance / repository bootstrap**

## Working

- Product direction defined.
- Product/repository/Flutter identity and Android namespace/application ID resolved: `Traelyx`, `traelyx`, and `io.github.atrx07.traelyx`.
- Initial governance/reference pack created.
- Main-first atomic commit/push discipline and public README roadmap tracking established.
- Stage 0 execution plan activated.
- Flutter Android repository scaffold created with the canonical application identity and a launchable bootstrap screen.
- Flutter 3.44.9/Dart 3.12.2, Android SDK 36.1, Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, and JDK/JVM targets validated as the bootstrap baseline.
- Strict Dart analysis, Flutter widget testing, Kotlin unit testing, and repository JSON/YAML/secret validation commands established.
- GitHub Actions passes generated-source, format, analysis, Flutter/Kotlin tests, repository validation, debug/release builds, size reporting, and artifact upload on `main`.

## Partial

- Foundation implementation exists locally but is not yet persisted as roadmap step 0.6.

## Not implemented

- Android foreground recorder.
- Local database.
- Telemetry pipeline.
- Event engine.
- Drive DNA/scoring.
- Replay.
- Auth/cloud/social.
- Guardian Connect.
- ML models.
- Commentary provider integrations.
- Release pipeline.

## Known risks

- Generated Flutter Gradle compatibility flags emit AGP 9 built-in-Kotlin deprecation warnings; current builds and Kotlin tests pass.
- Android background/foreground-service behavior across OS versions/OEMs.
- Device mounting/orientation and motorcycle vibration effects on IMU quality.
- Map tile/provider policy and offline/cache strategy.
- Availability/diversity of labeled telemetry for ML.
- Free-tier cloud limits if adoption becomes large.
- APK/app-data growth if raw telemetry retention is unmanaged.

## Next milestone

**M0 — Skeleton:** repository, Flutter shell, native Android integration skeleton, local DB skeleton, automated formatting/analysis/tests, and initial CI.
