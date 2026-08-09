# Execution Plan — M2 Native Recording Engine

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M2 — Native Recording Engine
**Started:** 2026-08-09
**Last updated:** 2026-08-09

## Context budget / references

Read only:

- `AGENTS.md` and `android/AGENTS.md`
- `docs/technical/ANDROID_TRACKING.md`
- timestamp, trip-boundary, and privacy sections of `docs/technical/TELEMETRY_SPEC.md`
- `docs/technical/STORAGE_SPEC.md`
- `docs/governance/SAFETY_GOVERNANCE.md`
- `docs/governance/TESTING_POLICY.md`
- `docs/governance/DEFINITION_OF_DONE.md`
- `docs/decisions/ADR-0002-flutter-kotlin-boundary.md`
- recorder-related Android, Flutter bridge, and test paths

Do not read unrelated ML, auth, cloud, social, map, or release documentation unless a dependency is discovered.

## Goal

Deliver a native Android recorder that can preserve a trustworthy local trip while Flutter is backgrounded or absent, then prove it on a normal physical drive with the screen locked.

## User-visible result

At milestone completion, a user can record, recover, finalize, and export a local trip without an account or network connection. During M2.1, only the foreground-service lifecycle foundation becomes operational; no location or motion samples are collected yet and trip recording remains unavailable to normal app UI.

## In scope

- M2.1 foreground-service lifecycle, explicit state machine, persistent active-trip recovery metadata, and notification.
- M2.2 GNSS acquisition with source timestamps, quality fields, and internal health counters.
- M2.3 IMU acquisition with source timestamps, accuracy, and batching.
- M2.4 bounded crash-safe buffers and durable versioned chunks.
- M2.5 versioned Flutter/Kotlin commands and recorder health/status.
- M2.6 contextual permission and notification onboarding.
- M2.7 lifecycle and recovery validation.
- M2.8 first privacy-safe real-drive fixture and locked-screen proof.

## Out of scope

- Telemetry filtering, resampling, derived channels, event detection, scoring, and Drive DNA.
- Replay UI, maps, cloud sync, social features, Guardian, ML, or commentary.
- Any dependency or service requiring payment, an account, or network access for core recording.
- Starting a later numbered M2 substep without explicit user authorization.

## Preconditions

- M0 and M1 are complete and synchronized to `origin/main`.
- The recorder service and versioned bridge skeleton exist but acquire no telemetry.
- Android 14 physical-device validation is available when a claim depends on background behavior.

## Affected components

- `android/app/src/main/kotlin/io/github/atrx07/traelyx/recorder/`
- `android/app/src/main/AndroidManifest.xml`
- native recorder unit/lifecycle tests
- the versioned Flutter recorder bridge and its tests when authorized by the relevant substep
- project roadmap and current-state documentation

## Data/privacy/security implications

- Raw routes and high-rate telemetry remain local-private by default.
- M2.1 persists only minimal active-trip recovery metadata in app-private storage and performs no sensor, location, or network access.
- M2.2 keeps acquired coordinates process-local and ephemeral until the authorized crash-safe chunk format exists in M2.4. Precise samples must not enter logs, notifications, Flutter bridge payloads, diagnostics, or network traffic.
- M2.3 keeps raw device-frame motion vectors process-local and ephemeral until M2.4. Exact vectors must not enter logs, notifications, Flutter bridge payloads, diagnostics, or network traffic.
- Diagnostics and logs must not expose precise routes, raw samples, device identifiers, secrets, or API keys.

## Compatibility/migration implications

- Recorder recovery metadata is explicitly versioned and must fail visibly/conservatively when invalid.
- Database schema v1 is unchanged by M2.1.
- Database schema v1 remains unchanged by M2.2; raw GNSS persistence and compatibility are deferred to the versioned chunk contract in M2.4.
- Database schema v1 remains unchanged by M2.3; raw IMU persistence and decoder compatibility are deferred to M2.4.
- Android foreground-service and notification behavior must be documented against supported API levels and OEM evidence.

## Implementation steps

- [x] M2.1 Foreground service lifecycle
  - [x] Define deterministic idle/starting/recording/stopping/recovered/error transitions.
  - [x] Persist the minimum active-trip recovery record before reporting recording state.
  - [x] Implement idempotent start, stop, query, null-intent restart, and stale-state recovery behavior.
  - [x] Display a low-distraction ongoing notification while the lifecycle is active.
  - [x] Add native unit/lifecycle tests and verify the Android manifest contract.
  - [x] Validate start/background/activity recreation/stop on an available physical device; disclose anything unverified.
- [x] M2.2 GNSS acquisition
  - [x] Define a versioned raw GNSS sample with source monotonic/wall timestamps, SI units, provider, optional source estimates, mock signal, and quality flags.
  - [x] Register native GPS-provider updates on a dedicated callback thread only while the recorder lifecycle is active.
  - [x] Map and validate platform fixes without fabricating missing fields or logging precise coordinates.
  - [x] Maintain privacy-safe acquisition health counters for samples, invalid fixes, low accuracy, timestamp discontinuities, mock signals, and provider state.
  - [x] Stop callbacks deterministically on stop, error, or service destruction and recover acquisition with an active lifecycle.
  - [x] Add native unit and physical-device proofs for the claimed acquisition behavior.
- [x] M2.3 IMU acquisition
  - [x] Define versioned raw accelerometer/gyroscope samples with Android source timestamps, device-frame axes, SI units, accuracy status, and quality flags.
  - [x] Register calibrated hardware accelerometer and gyroscope callbacks on a dedicated handler thread only while the recorder lifecycle is active.
  - [x] Request a documented 100 Hz period and bounded hardware FIFO batching without requiring high-rate sensor permission or a wake lock.
  - [x] Validate raw events without filtering, gravity removal, orientation inference, or vehicle-frame relabeling.
  - [x] Maintain vector-free health counters for accepted/rejected samples, accuracy, timestamp discontinuities, dropouts, registration, and batching capability.
  - [x] Stop callbacks deterministically on stop, error, or service destruction and restart them with a recovered lifecycle.
  - [x] Add native mapping/health unit tests and a controlled physical-device acquisition proof.
- [ ] M2.4 Crash-safe buffering — gated on explicit approval after M2.3.
- [ ] M2.5 Flutter↔Kotlin bridge — gated on explicit approval after M2.4.
- [ ] M2.6 Permissions/onboarding — gated on explicit approval after M2.5.
- [ ] M2.7 Service recovery tests — gated on explicit approval after M2.6.
- [ ] M2.8 First real-drive fixture — gated on explicit approval after M2.7.

## Tests / validation

- [x] Kotlin compilation/style and Android lint remain compliant with repository conventions.
- [x] Native unit and lifecycle tests.
- [x] Flutter format, static analysis, and existing tests.
- [x] Repository schema/secret/contract validation.
- [x] Debug and release-validation Android builds.
- [x] Physical-device validation for claimed M2.1 lifecycle reliability.
- [x] Confirm no sensor, location-sample, wake-lock, network, schema, or secret behavior was added during M2.1.
- [x] Inspect the exact diff, commit atomically to `main`, push, and verify `HEAD == origin/main`.
- [x] M2.2 native mapping/quality/health unit tests.
- [x] M2.2 Android lint, Flutter regression checks, repository validation, and debug/release builds.
- [x] M2.2 controlled physical-device GNSS acquisition proof with no precise coordinates emitted in test output.
- [x] Confirm M2.2 adds no IMU, durable telemetry, wake lock, network, database migration, or normal user-facing recording availability.
- [x] M2.3 native IMU mapping/quality/health unit tests.
- [x] M2.3 Android lint, Flutter regression checks, repository validation, instrumentation compilation, and debug/release builds.
- [x] M2.3 controlled physical-device accelerometer/gyroscope proof without emitting raw vectors.
- [x] Confirm M2.3 adds no filtering/fusion, durable telemetry, wake lock, network, database migration, high-rate sensor permission, or normal user-facing recording availability.

## Acceptance criteria

### M2.1

- Start produces one active lifecycle with a stable trip identifier and app-private recovery metadata.
- Duplicate start cannot create a second trip or service lifecycle.
- Query returns a conservative, versioned snapshot without requiring Flutter to remain alive.
- Stop clears active recovery metadata only after the lifecycle reaches idle.
- A service restart with valid active metadata enters recovered state instead of silently presenting a normal fresh trip.
- Missing or corrupt restart metadata fails closed and does not fabricate a recording.
- The active service has a visible, ongoing, non-distracting notification.
- No GNSS, IMU, raw telemetry, network, or cloud behavior is introduced.

### M2.2

- An active or recovered native recorder registers only the Android GPS provider and stops updates with the service lifecycle.
- Each accepted fix preserves the platform elapsed-realtime timestamp and source wall timestamp, derives trip elapsed time only when the monotonic epoch is valid, and keeps units/optional fields explicit.
- Invalid mandatory fields are rejected and counted; low horizontal accuracy, non-monotonic/invalid epoch timing, and platform mock signals remain auditable quality evidence rather than being silently normalized.
- Health snapshots expose counters and acquisition state without coordinates or raw route data.
- GNSS loss/provider disablement is visible in health state and does not fabricate samples or silently finalize the trip.
- No IMU acquisition, durable raw chunk, Flutter health bridge, network behavior, new third-party dependency, or database migration is introduced.

### M2.3

- Active and recovered recorder lifecycles register both Android calibrated hardware accelerometer and gyroscope sources; absence or registration failure is explicit and conservative.
- Each accepted event preserves the platform monotonic source timestamp, Android accuracy status, three device-frame axes, sensor type, and documented SI unit without gravity removal, filtering, fusion, or frame conversion.
- Trip elapsed time is derived only for a valid same-boot monotonic epoch; invalid ordering and sample gaps remain auditable quality evidence.
- The recorder requests a 10,000 microsecond sampling period (100 Hz) and up to 1,000,000 microseconds of FIFO report latency, reduced to device capability when necessary.
- Health snapshots expose configuration, capabilities, timestamps, accuracy, counts, and gaps without raw vector values.
- Both listeners stop with service teardown and restart after explicit lifecycle recovery.
- No durable raw chunk, Flutter health bridge, network behavior, wake lock, new permission, third-party dependency, or database migration is introduced.

### M2 milestone

- A normal 30–60 minute physical drive records synchronized raw GNSS/IMU with the screen locked.
- Flutter can reopen and discover or finalize an active/recovered trip.
- No unexplained catastrophic gaps occur and failures never masquerade as perfect finalized trips.
- The raw timeline is preserved and exportable for deterministic follow-on processing.

## Risks

- Android foreground-service restrictions and OEM battery management differ by OS/device.
- Process death can expose ordering bugs between persistent metadata and service state.
- Notification permission behavior can reduce drawer visibility on newer Android versions even while the system tracks the foreground service.
- Later sample rates, buffering, and wake behavior require measured battery/performance evidence.

## Decisions made during execution

- ADR-0002 remains authoritative: native Kotlin owns acquisition/lifecycle; Flutter is not authoritative for recorder survival.
- M2.1 will add no third-party dependency and will keep recovery metadata separate from future telemetry chunks.
- Recovery metadata uses Android `AtomicFile` under `noBackupFilesDir` so active-trip state is app-private, atomically replaced, and not restored onto another device by backup.
- The service declares the `location` foreground-service type now because that is its actual recorder purpose; foreground promotion fails closed until coarse/fine location permission exists. User-facing permission onboarding remains M2.6.
- M2.2 uses the platform `LocationManager.GPS_PROVIDER` at a requested one-second minimum interval and zero minimum distance, with callbacks isolated on a native handler thread. It does not add Google Play Services or another location dependency.
- Raw GNSS schema version 1 uses `Location.elapsedRealtimeNanos` as the source monotonic timestamp and preserves `Location.time` separately as source wall time. A missing/invalid horizontal accuracy rejects the fix; accuracy above 50 metres is retained with `GNSS_LOW_ACCURACY`.
- M2.3 uses calibrated `Sensor.TYPE_ACCELEROMETER` (gravity included, m/s²) and `Sensor.TYPE_GYROSCOPE` (rad/s), preserving Android's device coordinate system anchored to the device's natural orientation without display-rotation swapping. It requests 100 Hz, below Android's 200 Hz `registerListener` limit for apps without `HIGH_SAMPLING_RATE_SENSORS`.
- IMU schema version 1 preserves `SensorEvent.timestamp`, which shares the `SystemClock.elapsedRealtimeNanos()` time base for each sensor. Hardware FIFO batching is requested up to one second and bounded by each sensor's reported FIFO capacity; zero capacity falls back visibly to immediate delivery.

## Progress log

- 2026-08-09: M2 activated with explicit user authorization. Requirements loaded; implementation limited to M2.1.
- 2026-08-09: M2.1 implementation and local/device gates passed. Atomic completion diff prepared; M2.2 remains unauthorized.
- 2026-08-09: M2.2 explicitly authorized. Requirements and acceptance gates expanded before implementation; physical-phone actions will be announced live before execution.
- 2026-08-09: M2.2 local gates and controlled Android 14 device proof passed. Two shorter obstructed-view runs remained honestly in `awaiting_fix`; the improved-sky-view run acquired real fixes before and after explicit service recovery and cleaned up permissions/service/notification state.
- 2026-08-09: M2.3 explicitly authorized. Timestamp, units, device-frame, batching, privacy, and physical-phone communication gates expanded before implementation.
- 2026-08-09: M2.3 local gates and controlled Android 14 device proof passed. Both calibrated motion streams produced valid source timestamp/accuracy/configuration health before and after service recovery, then stopped cleanly; device permissions were restored.

## Completion summary

M2.1 delivers the native lifecycle foundation with contract-versioned state snapshots, an idempotent state machine, atomic active-trip recovery metadata, a non-exported sticky location foreground service, and an immediate ongoing notification with a stop action. The bridge reports `lifecycle_ready` while conservatively keeping `recordingAvailable=false`.

Validation passed: Kotlin unit tests, dependency-free Android instrumentation on the physical Android 14 Tecno LH8n, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, debug/release APK builds, APK size reporting, update-install, and cold launch. The physical proof covered activity recreation, explicit service recreation/recovery, app backgrounding, a short screen-off interval, notification presence, and clean stop.

M2.2 adds dependency-free Android GPS-provider acquisition, raw GNSS schema version 1, strict source-field validation, monotonic timestamp derivation, explicit quality evidence, and privacy-safe health counters. Precise fixes remain process-local/ephemeral and never enter logs, diagnostics, Flutter payloads, notifications, or network traffic.

Validation passed: native mapping/quality/health tests, prior lifecycle/recovery tests, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, instrumentation compilation, and debug/release APK builds. The controlled physical Android 14 Tecno LH8n proof acquired real GPS fixes during the initial lifecycle and again after explicit service recovery, verified source timestamp/horizontal-accuracy/provider health evidence without emitting coordinates, survived the existing activity/background/short-screen-off sequence, and stopped GNSS/notification/service state cleanly. Temporary device permissions were restored to denied after the proof.

M2.3 adds dependency-free calibrated accelerometer/gyroscope acquisition, raw IMU schema version 1, strict device-frame/SI semantics, per-sensor timestamp ordering, accuracy/dropout evidence, requested hardware FIFO batching, and vector-free health counters. Raw motion evidence remains process-local/ephemeral and never enters logs, diagnostics, Flutter payloads, notifications, or network traffic.

Validation passed: native IMU mapping/quality/health tests, all existing native tests, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, instrumentation compilation, and debug/release APK builds. The controlled physical Android 14 Tecno LH8n proof acquired accelerometer and gyroscope events in the initial lifecycle and again after explicit service recovery, verified source/trip timestamps, accuracy status, and requested/effective batching configuration without emitting vectors, preserved the GNSS/lifecycle regression proof, and stopped listeners/GNSS/notification/service state cleanly. Temporary device permissions were restored to denied.

Not yet verified or claimed: durable raw telemetry, crash-safe chunks, a 30–60 minute locked-screen drive, IMU delivery during deep sleep, process/device reboot recovery, battery drain, vibration quality, multi-version/OEM reliability, or telemetry durability. Those remain in M2.4–M2.8, and M2.4 requires explicit authorization.
