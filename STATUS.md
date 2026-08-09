# Traelyx — Current Project State

> Keep this file short. It is meant to be inexpensive agent context. Update facts, not prose history.

## Current phase

**M2 active — M2.1 complete; awaiting explicit authorization for M2.2**

## Working

- Product direction defined.
- Product/repository/Flutter identity and Android namespace/application ID resolved: `Traelyx`, `traelyx`, and `io.github.atrx07.traelyx`.
- Initial governance/reference pack created.
- Main-first atomic commit/push discipline and public README roadmap tracking established.
- M0 execution plan completed and archived.
- M1 execution plan completed and archived after all six authorized substeps passed their required gates.
- Flutter Android repository scaffold created with the canonical application identity and a launchable bootstrap screen.
- Flutter 3.44.9/Dart 3.12.2, Android SDK 36.1, Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, and JDK/JVM targets validated as the bootstrap baseline.
- Strict Dart analysis, Flutter widget testing, Kotlin unit testing, and repository JSON/YAML/secret validation commands established.
- GitHub Actions passes generated-source, format, analysis, Flutter/Kotlin tests, repository validation, debug/release builds, size reporting, and artifact upload on `main`.
- The accountless bootstrap app launches on a physical Android 14 device with Riverpod/`go_router` boundaries, provisional centralized theme tokens, and an honest local-foundation state.
- Drift schema version 1 defines vehicles, trips, chunk indexes, events, scores, driver baselines, sync queue, and non-secret settings with relational constraints validated locally and in CI.
- A committed Drift schema-v1 snapshot, generated verifier, and file-backed upgrade fixtures validate fresh/current databases and the exact settings-only development bootstrap shape locally and in CI. Unknown version-1 shapes fail visibly instead of being repaired implicitly.
- The versioned Flutter/Kotlin recorder bridge reports conservative capability state; its lifecycle service is enabled while `recordingAvailable` remains false and no telemetry is acquired.
- A provider-neutral map contract exists without selecting a tile SDK, endpoint, or network dependency.
- Dark-first semantic color, typography, spacing, radii, and reduced-motion-aware timing primitives are centralized and validated locally and in CI.
- Drive, Trips, DNA, Social, and You have directly routable, responsive navigation skeletons with isolated branch stacks and honest placeholder states validated locally and in CI.
- Typed non-secret settings persist through the existing Drift schema with defaults, reactive reads, explicit corruption failures, and Riverpod injection boundaries, validated locally and in CI.
- Secret storage is separated behind a replaceable interface whose default implementation fails closed instead of falling back to insecure persistence or logs, validated locally and in CI.
- A deep-link-safe Developer / Diagnostics screen reports allowlisted app/build metadata, schema version, recorder capability state, and aggregate storage bytes without exposing routes, raw samples, filenames, device identifiers, credentials, or API keys, validated locally, on-device, and in CI.
- The current debug APK update-installs and cold-launches on the Android 14 Tecno LH8n with existing app data preserved and no startup, Flutter, or database errors.
- M2.1 provides a versioned native recorder state machine, atomic app-private active-trip recovery metadata, idempotent start/stop/query behavior, and a low-distraction ongoing foreground-service notification.
- The M2.1 lifecycle survives activity recreation, service recreation into an explicit recovered state, app backgrounding, and a short screen-off interval on the physical Android 14 Tecno LH8n, then stops and removes its notification cleanly.

## Partial

- The recorder lifecycle is operational, but GNSS/IMU acquisition, telemetry buffering, and user permission onboarding are not; trip recording remains unavailable.
- Trips, DNA, and Social are navigation skeletons only. You exposes diagnostics; its other profile/settings features remain placeholders.
- Secure storage has an interface but no platform-backed production provider; no current feature attempts to persist secrets.
- Map rendering, tiles, cache implementation, and provider selection remain unimplemented.

## Not implemented

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
- Unknown or partial schema-version-1 shapes deliberately fail closed instead of receiving an unaudited implicit repair; any real occurrence will require an explicit recovery/export path.
- Android background/foreground-service behavior across OS versions/OEMs.
- M2.1 physical validation proves a short lifecycle/recovery sequence on one Android 14 OEM device, not yet a 30–60 minute locked-screen recording or multi-version/OEM reliability.
- Device mounting/orientation and motorcycle vibration effects on IMU quality.
- Map tile/provider policy and offline/cache strategy.
- Availability/diversity of labeled telemetry for ML.
- Free-tier cloud limits if adoption becomes large.
- APK/app-data growth if raw telemetry retention is unmanaged.

## Current step

**M2.2 — GNSS acquisition:** pending explicit user authorization; no M2.2 implementation has started.
