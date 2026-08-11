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
- The recorder service, GNSS/IMU acquisition, durable native chunk writer, and versioned bridge skeleton exist; Flutter commands and aggregate recorder health are not yet integrated.
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
- M2.2 acquired coordinates are handed directly to the M2.4 app-private durable writer. Precise samples must not enter logs, notifications, Flutter bridge payloads, diagnostics, or network traffic.
- M2.3 raw device-frame motion vectors are handed directly to the M2.4 app-private durable writer. Exact vectors must not enter logs, notifications, Flutter bridge payloads, diagnostics, or network traffic.
- M2.4 durable chunks remain under the app-private no-backup directory. Paths use only trip UUID and sequence, and health surfaces expose aggregate state/counts rather than raw values, precise timestamps, paths, or device identifiers.
- M2.5 bridge payloads expose only lifecycle identity/state, aggregate sensor and buffer counters, capability flags, and allowlisted error codes. Coordinates, vectors, raw sample timestamps, precise fix metadata, filesystem paths, and device identifiers never cross the Flutter boundary.
- Diagnostics and logs must not expose precise routes, raw samples, device identifiers, secrets, or API keys.

## Compatibility/migration implications

- Recorder recovery metadata is explicitly versioned and must fail visibly/conservatively when invalid.
- Database schema v1 is unchanged by M2.1.
- Database schema v1 remains unchanged by M2.2; raw GNSS persistence and compatibility are deferred to the versioned chunk contract in M2.4.
- Database schema v1 remains unchanged by M2.3; raw IMU persistence and decoder compatibility are deferred to M2.4.
- M2.4 uses self-describing app-private chunk files whose metadata matches the existing `trip_chunks` schema. Native files are recoverable without Flutter; verified index reconciliation into Drift is deferred to the authorized bridge/integration boundary, so database schema version 1 remains unchanged.
- M2.5 keeps database schema version 1 unchanged. Native-to-Drift chunk-index reconciliation requires an explicit finalization/index transaction and remains deferred to M2.7 rather than exposing private paths or partially indexing an active native write stream through the health bridge.
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
- [x] M2.4 Crash-safe buffering
  - [x] Define binary telemetry chunk encoding version 1 with telemetry schema version, trip ID, sequence, elapsed-time bounds, channel counts, compression, checksum, and completion marker.
  - [x] Feed accepted GNSS/accelerometer/gyroscope samples into a bounded native queue without blocking acquisition callback threads on file I/O.
  - [x] Reorder within a bounded two-second horizon, then flush at one-second or 256-sample boundaries; fail visibly on overflow, invalid trip time, or evidence arriving behind the committed boundary.
  - [x] Persist chunks under app-private no-backup storage using platform DEFLATE, SHA-256 over stored payload bytes, and `AtomicFile` replacement.
  - [x] Recover the next sequence and last committed boundary by scanning self-describing chunks; isolate corrupt/truncated/orphaned files without making other chunks unreadable or overwriting evidence.
  - [x] Expose privacy-safe buffer health and storage-growth counters without routes, vectors, raw timestamps, filesystem paths, or device identifiers.
  - [x] Add deterministic codec fixture, ordering/boundary, corruption/truncation, overflow, atomic-store, recovery, and service integration tests.
  - [x] Measure encoded bytes/sample and estimated MB/hour; document that retention/default pruning remains undecided until broader storage measurements and UX work.
- [x] M2.5 Flutter↔Kotlin bridge — completed and validated on 2026-08-11.
  - [x] Define a stable bridge-v1 capability and recorder-status contract with conservative parsing on both sides.
  - [x] Expose idempotent start, stop, explicit recovery, lifecycle query, and aggregate health query commands through a testable native dispatcher.
  - [x] Map GNSS, IMU, and durable-buffer health without coordinates, vectors, raw sample timestamps, precise fix values, paths, or device identifiers.
  - [x] Add immutable Dart lifecycle/health/status models plus Riverpod query and command boundaries; keep Flutter non-authoritative for recorder survival.
  - [x] Keep `recordingAvailable=false` and add no permission prompt, Drive control, database migration, network behavior, wake lock, or third-party dependency.
  - [x] Add Kotlin contract/dispatcher tests, Dart parsing/channel/provider tests, and a controlled physical-device bridge/service proof.
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
- [x] M2.4 deterministic codec/golden-fixture tests preserve timestamps, units, flags, optional fields, and global decode order.
- [x] M2.4 bounded-buffer tests cover flush thresholds, stop flush, overflow, invalid time, late evidence, write failure, corruption/truncation isolation, and sequence recovery.
- [x] M2.4 Android lint, Flutter regression checks, repository validation, instrumentation compilation, and debug/release builds.
- [x] M2.4 controlled physical-device proof verifies durable checksummed GNSS/IMU chunks before and after service recovery without emitting raw values or paths.
- [x] Confirm M2.4 adds no filtering/fusion, cloud/network behavior, wake lock, permission, third-party dependency, database migration, retention default, or normal user-facing recording availability.
- [x] M2.5 native contract and dispatcher tests cover all methods, exact version fields, idempotent outcomes, unknown methods, and privacy allowlists.
- [x] M2.5 Dart tests cover conservative parsing, every MethodChannel command, nested status health, malformed/null responses, and Riverpod refresh behavior.
- [x] M2.5 Android lint, Flutter format/analyze/tests, repository validation, instrumentation compilation, and debug/release builds.
- [x] M2.5 controlled physical-device proof verifies Flutter capability handshake plus native bridge start/query/recover/stop and aggregate health without emitting raw values or paths.
- [x] Confirm M2.5 adds no permission/onboarding UI, normal recording availability, database migration, network behavior, wake lock, third-party dependency, or native-to-Drift partial indexing.

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

### M2.4

- Accepted GNSS, accelerometer, and gyroscope evidence is durably encoded in versioned, self-describing app-private chunks while the native recorder runs without Flutter or network access.
- Producer memory and queued work are explicitly bounded; acquisition callbacks never perform compression or disk writes, and capacity/ordering/time failures stop recording conservatively instead of silently dropping evidence.
- Chunk sequence and elapsed-time bounds are monotonic after a bounded reorder horizon; decode preserves all raw fields, SI units, device-frame semantics, optionality, and quality flags.
- Each completed chunk uses explicit DEFLATE compression metadata, SHA-256 verification, an end marker, and atomic replacement. Truncated, corrupt, unknown-version, and orphaned writes are isolated and never treated as valid chunks.
- Service recovery continues at a non-overwriting sequence after the last observed filename and after the last verified elapsed-time boundary; an unfinished recovered trip is never presented as normally finalized.
- Health exposes only state, counts, byte totals, queue/buffer depths, sequence/boundary presence, corruption counts, and allowlisted error codes—never raw samples, precise coordinates, vectors, paths, or device identifiers.
- Database schema version 1 remains unchanged; the existing `trip_chunks` columns already cover the file index contract, while verified native-to-Drift reconciliation remains gated to the M2.7 finalization/recovery transaction.
- No filtering, resampling, derived channels, export, retention default/pruning, Flutter bridge expansion, normal recording availability, network behavior, wake lock, permission, or third-party dependency is introduced.

### M2.5

- The stable recorder channel reports bridge and nested status contract versions, rejects missing/malformed responses conservatively in Dart, and keeps existing capability consumers compatible.
- Flutter can query lifecycle plus aggregate GNSS, IMU, and durable-buffer health and can issue idempotent start, stop, and explicit recovery commands without becoming authoritative for service lifetime.
- Native dispatch is independently testable from `MainActivity`; unknown methods remain unimplemented and native failures return allowlisted state/error evidence rather than exception text.
- Bridge payloads contain no coordinates, motion vectors, raw sample timestamps, precise fix accuracy/time, filesystem paths, device identifiers, secrets, or chunk contents.
- `recordingAvailable` remains false until M2.6 supplies contextual permission/onboarding and user-facing controls; no existing screen can begin normal trip recording.
- Database schema version 1 remains unchanged and no active native write stream is partially reconciled into Drift. Finalization/index reconciliation remains an explicit M2.7 recovery transaction.
- No new dependency, network behavior, cloud behavior, wake lock, sensor rate, chunk encoding, retention policy, or permission is introduced.

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
- M2.4 chunk files live under `noBackupFilesDir/recorder/trips/<trip-id>/chunks` so precise routes and high-rate motion evidence remain app-private and are not copied through Android Auto Backup. The UUID and sequence name files; no route-derived information appears in paths.
- Encoding version 1 uses a binary envelope plus deterministic record encoding, platform DEFLATE at best-speed, SHA-256 over the stored compressed payload, an explicit completion marker, and `AtomicFile` replacement. Compression is replaceable through the declared envelope field rather than implicit.
- The asynchronous writer separately bounds ingress and the reorder heap at 1,024 samples each and reorders within two seconds, exceeding the requested one-second IMU FIFO latency. It emits at most 256 samples or one second per chunk and treats queue/reorder overflow, missing trip time, or evidence older than the committed boundary as explicit recorder errors.
- M2.5 keeps the existing `/recorder/v1` channel stable and adds a nested recorder-status contract version. Health is pull-based so Flutter can refresh on demand without creating a second authoritative lifecycle or an always-on event stream.
- Bridge lifecycle maps intentionally omit native monotonic start timestamps; GNSS/IMU health omits raw source timestamps and precise fix values. Flutter receives the trip UUID, lifecycle/recovery state, aggregate counters, capability flags, and allowlisted errors needed for UI orchestration.
- Native-to-Drift chunk indexing is deferred to the M2.7 finalization/recovery transaction because M2.5 must not expose private filesystem paths or create a partially indexed active stream.

## Progress log

- 2026-08-09: M2 activated with explicit user authorization. Requirements loaded; implementation limited to M2.1.
- 2026-08-09: M2.1 implementation and local/device gates passed. Atomic completion diff prepared; M2.2 remains unauthorized.
- 2026-08-09: M2.2 explicitly authorized. Requirements and acceptance gates expanded before implementation; physical-phone actions will be announced live before execution.
- 2026-08-09: M2.2 local gates and controlled Android 14 device proof passed. Two shorter obstructed-view runs remained honestly in `awaiting_fix`; the improved-sky-view run acquired real fixes before and after explicit service recovery and cleaned up permissions/service/notification state.
- 2026-08-09: M2.3 explicitly authorized. Timestamp, units, device-frame, batching, privacy, and physical-phone communication gates expanded before implementation.
- 2026-08-09: M2.3 local gates and controlled Android 14 device proof passed. Both calibrated motion streams produced valid source timestamp/accuracy/configuration health before and after service recovery, then stopped cleanly; device permissions were restored.
- 2026-08-09: M2.4 explicitly authorized. Chunk/index compatibility, buffer bounds, reorder/flush behavior, checksum/atomicity, corruption isolation, privacy, performance measurement, and physical-device communication gates expanded before implementation.
- 2026-08-09: M2.4 implementation, local gates, and controlled Android 14 device proof passed. Real GNSS and dual-IMU evidence was durably checksummed before and after service recovery, sequence/catalog continuity and short background/screen-off survival were verified, and the proof removed its private files; independent cleanup confirmed zero proof files/directories, zero recorder services, and restored denied permissions.
- 2026-08-11: M2.5 explicitly authorized. Repository/toolchain readiness and Tecno ADB authorization were reverified after host background processes were closed; implementation is limited to the versioned command/status bridge and its privacy, regression, and controlled-device gates.
- 2026-08-11: M2.5 implementation and all local/device gates passed. The controlled Tecno proof exercised bridge start/status/recover/stop over real GNSS, dual IMU, durable chunks, activity/service recovery, backgrounding, and a short screen-off interval; a normal Flutter launch displayed `Recorder bridge_ready`, and cleanup left no service, proof files, test APK, or temporary permissions.

## Completion summary

M2.1 delivers the native lifecycle foundation with contract-versioned state snapshots, an idempotent state machine, atomic active-trip recovery metadata, a non-exported sticky location foreground service, and an immediate ongoing notification with a stop action. The bridge reports `lifecycle_ready` while conservatively keeping `recordingAvailable=false`.

Validation passed: Kotlin unit tests, dependency-free Android instrumentation on the physical Android 14 Tecno LH8n, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, debug/release APK builds, APK size reporting, update-install, and cold launch. The physical proof covered activity recreation, explicit service recreation/recovery, app backgrounding, a short screen-off interval, notification presence, and clean stop.

M2.2 adds dependency-free Android GPS-provider acquisition, raw GNSS schema version 1, strict source-field validation, monotonic timestamp derivation, explicit quality evidence, and privacy-safe health counters. Precise fixes remain process-local/ephemeral and never enter logs, diagnostics, Flutter payloads, notifications, or network traffic.

Validation passed: native mapping/quality/health tests, prior lifecycle/recovery tests, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, instrumentation compilation, and debug/release APK builds. The controlled physical Android 14 Tecno LH8n proof acquired real GPS fixes during the initial lifecycle and again after explicit service recovery, verified source timestamp/horizontal-accuracy/provider health evidence without emitting coordinates, survived the existing activity/background/short-screen-off sequence, and stopped GNSS/notification/service state cleanly. Temporary device permissions were restored to denied after the proof.

M2.3 adds dependency-free calibrated accelerometer/gyroscope acquisition, raw IMU schema version 1, strict device-frame/SI semantics, per-sensor timestamp ordering, accuracy/dropout evidence, requested hardware FIFO batching, and vector-free health counters. Raw motion evidence remains process-local/ephemeral and never enters logs, diagnostics, Flutter payloads, notifications, or network traffic.

Validation passed: native IMU mapping/quality/health tests, all existing native tests, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, instrumentation compilation, and debug/release APK builds. The controlled physical Android 14 Tecno LH8n proof acquired accelerometer and gyroscope events in the initial lifecycle and again after explicit service recovery, verified source/trip timestamps, accuracy status, and requested/effective batching configuration without emitting vectors, preserved the GNSS/lifecycle regression proof, and stopped listeners/GNSS/notification/service state cleanly. Temporary device permissions were restored to denied.

M2.4 adds dependency-free native crash-safe persistence for accepted GNSS, accelerometer, and gyroscope evidence. Encoding version 1 is self-describing and deterministic; platform DEFLATE, SHA-256, an explicit completion marker, and `AtomicFile` replacement protect each chunk. Separate 1,024-sample ingress/reorder bounds, a two-second reorder horizon, and one-second/256-sample flush limits fail visibly on capacity, time, ordering, sequence, or write errors. Recovery verifies and isolates files before continuing at a non-overwriting sequence and committed elapsed boundary. Privacy-safe health exposes aggregate state/counts/bytes only. Database schema version 1 and normal user-facing recording availability remain unchanged.

Validation passed: deterministic codec/golden-fixture round trips; ordering, flush, stop, overflow, invalid-time, late-evidence, write-failure, corruption/truncation/orphan isolation, atomic-store, and sequence-recovery tests; all native tests; Android lint; Dart formatting; Flutter analysis; all 40 Flutter tests; repository validation; instrumentation compilation; and debug/release APK builds. The controlled physical Android 14 Tecno LH8n proof persisted checksummed real GNSS and dual-IMU evidence before and after explicit service recovery, verified recovered catalog/sequence continuity, survived activity recreation, backgrounding, and a short screen-off interval, then stopped and deleted its proof trip without emitting raw values or paths. Independent cleanup verified zero proof files/directories, zero recorder services, and denied temporary permissions. A deterministic synthetic 1 Hz GNSS plus dual-100 Hz IMU stream measured 4,244 encoded bytes/second (approximately 14.57 MiB/hour); this is provisional and does not set retention policy.

M2.5 completes the stable `/recorder/v1` integration with a separately versioned aggregate status contract, a testable native dispatcher, idempotent start/stop/recover/query commands, immutable Dart lifecycle/GNSS/IMU/buffer models, and pull-based Riverpod query/command boundaries. Public payloads omit precise sensor evidence and private storage details, Flutter remains non-authoritative for recorder survival, and normal recording stays unavailable pending M2.6.

Validation passed: native contract/privacy/dispatcher tests, all native regression tests, instrumentation compilation, Android lint, Dart formatting, Flutter analysis, all 45 Flutter tests, repository validation, debug/release APK builds, and APK size reporting. The controlled Android 14 Tecno LH8n proof passed bridge start/status/recover/stop with real stationary GNSS, dual IMU, durable chunks, activity/service recovery, backgrounding, and a short screen-off interval. A normal Flutter launch then rendered `Database v1 · Native bridge v1 · Recorder bridge_ready` through the real MethodChannel while recording remained disabled. Cleanup verified zero recorder services/proof files, removal of the test APK, and denied temporary permissions.

Not yet verified or claimed: a 30–60 minute locked-screen drive, IMU delivery during deep sleep, process/device reboot recovery, battery drain, vibration quality, multi-version/OEM reliability, native-to-Drift finalization/index reconciliation, permission onboarding, or a production retention default. Those remain in M2.6–M2.8 or later, and M2.6 requires explicit authorization.
