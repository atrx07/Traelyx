# Traelyx — Current Project State

> Keep this file short. It is meant to be inexpensive agent context. Update facts, not prose history.

## Current phase

**M1 active — M1.1 locally validated; remote CI pending**

## Working

- Product direction defined.
- Product/repository/Flutter identity and Android namespace/application ID resolved: `Traelyx`, `traelyx`, and `io.github.atrx07.traelyx`.
- Initial governance/reference pack created.
- Main-first atomic commit/push discipline and public README roadmap tracking established.
- M0 execution plan completed and archived.
- M1 execution plan activated after explicit user authorization.
- Flutter Android repository scaffold created with the canonical application identity and a launchable bootstrap screen.
- Flutter 3.44.9/Dart 3.12.2, Android SDK 36.1, Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, and JDK/JVM targets validated as the bootstrap baseline.
- Strict Dart analysis, Flutter widget testing, Kotlin unit testing, and repository JSON/YAML/secret validation commands established.
- GitHub Actions passes generated-source, format, analysis, Flutter/Kotlin tests, repository validation, debug/release builds, size reporting, and artifact upload on `main`.
- The accountless bootstrap app launches on a physical Android 14 device with Riverpod/`go_router` boundaries, provisional centralized theme tokens, and an honest local-foundation state.
- Drift schema version 1 initializes and persists local settings under test.
- The versioned Flutter/Kotlin recorder bridge reports conservative capability state; its service is registered but disabled and acquires no telemetry.
- A provider-neutral map contract exists without selecting a tile SDK, endpoint, or network dependency.
- Dark-first semantic color, typography, spacing, radii, and reduced-motion-aware timing primitives are centralized and locally validated.

## Partial

- The recorder bridge and service are structural only; trip recording remains unavailable.
- Drift contains only the bootstrap `app_settings` table; the application schema and migration harness belong to M1.
- Map rendering, tiles, cache implementation, and provider selection remain unimplemented.

## Not implemented

- Android foreground recorder.
- Application database schema beyond bootstrap settings.
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
- The centralized M1.1 palette is intentionally evolvable pending broader visual prototyping; consumers use semantic names rather than raw colors.
- Android background/foreground-service behavior across OS versions/OEMs.
- Device mounting/orientation and motorcycle vibration effects on IMU quality.
- Map tile/provider policy and offline/cache strategy.
- Availability/diversity of labeled telemetry for ML.
- Free-tier cloud limits if adoption becomes large.
- APK/app-data growth if raw telemetry retention is unmanaged.

## Current step

**M1.1 — Design tokens/theme:** implementation and local gates pass; awaiting required remote CI before completion.
