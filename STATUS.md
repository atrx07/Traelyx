# Traelyx — Current Project State

> Keep this file short. It is meant to be inexpensive agent context. Update facts, not prose history.

## Current phase

**M2 active — M2.6 complete; awaiting explicit authorization for M2.7**

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
- The stable Flutter/Kotlin recorder bridge v1 reports `bridge_ready`, exposes typed pull-based lifecycle/GNSS/IMU/buffer status and idempotent start/stop/recover commands, and reports `recordingAvailable=true` only when precise location and GPS are ready.
- A provider-neutral map contract exists without selecting a tile SDK, endpoint, or network dependency.
- Dark-first semantic color, typography, spacing, radii, and reduced-motion-aware timing primitives are centralized and validated locally and in CI.
- Drive, Trips, DNA, Social, and You have directly routable, responsive navigation skeletons with isolated branch stacks and honest placeholder states validated locally and in CI.
- Typed non-secret settings persist through the existing Drift schema with defaults, reactive reads, explicit corruption failures, and Riverpod injection boundaries, validated locally and in CI.
- Secret storage is separated behind a replaceable interface whose default implementation fails closed instead of falling back to insecure persistence or logs, validated locally and in CI.
- A deep-link-safe Developer / Diagnostics screen reports allowlisted app/build metadata, schema version, recorder capability state, and aggregate storage bytes without exposing routes, raw samples, filenames, device identifiers, credentials, or API keys, validated locally, on-device, and in CI.
- The current debug APK update-installs and cold-launches on the Android 14 Tecno LH8n with existing app data preserved and no startup, Flutter, or database errors.
- M2.1 provides a versioned native recorder state machine, atomic app-private active-trip recovery metadata, idempotent start/stop/query behavior, and a low-distraction ongoing foreground-service notification.
- The M2.1 lifecycle survives activity recreation, service recreation into an explicit recovered state, app backgrounding, and a short screen-off interval on the physical Android 14 Tecno LH8n, then stops and removes its notification cleanly.
- M2.2 provides native GPS-provider acquisition on a dedicated callback thread with raw schema version 1, platform monotonic/wall timestamps, SI units, explicit optional fields, auditable quality flags, and privacy-safe health counters.
- The M2.2 physical proof acquired real GPS fixes before and after explicit service recovery on the Android 14 Tecno LH8n, preserved required timestamp/accuracy metadata, and stopped GNSS callbacks with the recorder lifecycle without printing or uploading coordinates.
- M2.3 provides calibrated hardware accelerometer and gyroscope acquisition on a dedicated callback thread with raw IMU schema version 1, Android monotonic timestamps, device-frame axes, SI units, accuracy status, auditable dropout/clock flags, requested hardware FIFO batching, and vector-free health counters.
- The M2.3 physical proof acquired both motion streams before and after explicit service recovery on the Android 14 Tecno LH8n, preserved timestamp/accuracy/configuration evidence, and stopped both listeners with the recorder lifecycle without printing or uploading raw vectors.
- M2.4 provides bounded asynchronous native persistence for accepted GNSS/IMU evidence using self-describing encoding version 1, platform DEFLATE, SHA-256, completion markers, app-private no-backup storage, and Android atomic replacement; invalid capacity/time/order/write states fail visibly.
- M2.4 recovery verifies and isolates corrupt/truncated/orphaned files, continues after the highest observed sequence and valid elapsed boundary, exposes aggregate privacy-safe health, and leaves Drift schema version 1 unchanged. The deterministic synthetic baseline measured approximately 14.57 MiB/hour, without setting a retention default.
- M2.6 physical validation exposed a continuous-stream M2.4 batching regression. Horizon-cleared samples now stage into the existing one-second/256-sample output bound separately from the 1,024-entry reorder heap; native regression tests and a 20-second Tecno retry verified 21 active chunks and 27 after Stop flush instead of one file per sample.
- The M2.4 physical proof persisted and verified real GNSS and dual-IMU chunks before and after explicit service recovery on the Android 14 Tecno LH8n, preserved catalog/sequence continuity through activity/background/short-screen-off transitions, and cleaned all proof data and temporary permissions.
- M2.5 maps native lifecycle and aggregate health into immutable Dart models without crossing coordinates, vectors, raw sample timestamps, precise fix values, paths, or device identifiers. Native dispatch and Dart channel/provider boundaries are independently testable.
- The M2.5 physical proof exercised bridge start/status/recover/stop with real GNSS, dual IMU, durable chunks, service recovery, backgrounding, and a short screen-off interval; normal Flutter launch then displayed `Recorder bridge_ready` through the real MethodChannel. Cleanup left zero recorder services/proof files and denied temporary permissions.
- M2.6 provides a versioned permission-readiness contract, explicit fine+coarse while-in-use location and Android 13+ notification requests, approximate/denied/GPS-disabled settings recovery, resume refresh, and large Drive Start/Stop controls without auto-prompting or background-location access.
- The M2.6 Tecno proof traversed denied → contextual system dialogs → ready → recording → stopped through the real Flutter/MethodChannel UI, then passed native GNSS/dual-IMU/chunk recovery, background, and short screen-off checks. Cleanup left no service, recovery metadata, proof trips, test APK, or temporary grants.

## Partial

- Recorder lifecycle, GNSS/IMU acquisition, native durable chunks, Flutter health/commands, contextual permission onboarding, and Drive Start/Stop are operational. Native-to-Drift finalization/index reconciliation and broader recovery/finalization tests remain pending, so recorded evidence is not yet presented as a finalized trip.
- Trips, DNA, and Social are navigation skeletons only. You exposes diagnostics; its other profile/settings features remain placeholders.
- Secure storage has an interface but no platform-backed production provider; no current feature attempts to persist secrets.
- Map rendering, tiles, cache implementation, and provider selection remain unimplemented.

## Not implemented

- Telemetry processing pipeline.
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
- M2.1–M2.6 physical validation proves contextual permission/UI orchestration plus a short lifecycle/recovery, stationary real-GPS, dual-IMU, and bounded durable-chunk sequence on one Android 14 OEM device, not yet a 30–60 minute locked-screen recording, deep-sleep/reboot recovery, battery behavior, vibration quality, or multi-version/OEM reliability.
- Device mounting/orientation and motorcycle vibration effects on IMU quality.
- Map tile/provider policy and offline/cache strategy.
- Availability/diversity of labeled telemetry for ML.
- Free-tier cloud limits if adoption becomes large.
- APK/app-data growth if raw telemetry retention is unmanaged.

## Current step

**M2.7 — Service recovery tests:** pending explicit user authorization; do not begin until approved.
