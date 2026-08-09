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
- M2.2 GNSS acquisition with source timestamps and quality fields.
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
- Diagnostics and logs must not expose precise routes, raw samples, device identifiers, secrets, or API keys.

## Compatibility/migration implications

- Recorder recovery metadata is explicitly versioned and must fail visibly/conservatively when invalid.
- Database schema v1 is unchanged by M2.1.
- Android foreground-service and notification behavior must be documented against supported API levels and OEM evidence.

## Implementation steps

- [x] M2.1 Foreground service lifecycle
  - [x] Define deterministic idle/starting/recording/stopping/recovered/error transitions.
  - [x] Persist the minimum active-trip recovery record before reporting recording state.
  - [x] Implement idempotent start, stop, query, null-intent restart, and stale-state recovery behavior.
  - [x] Display a low-distraction ongoing notification while the lifecycle is active.
  - [x] Add native unit/lifecycle tests and verify the Android manifest contract.
  - [x] Validate start/background/activity recreation/stop on an available physical device; disclose anything unverified.
- [ ] M2.2 GNSS acquisition — gated on explicit approval after M2.1.
- [ ] M2.3 IMU acquisition — gated on explicit approval after M2.2.
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

## Progress log

- 2026-08-09: M2 activated with explicit user authorization. Requirements loaded; implementation limited to M2.1.
- 2026-08-09: M2.1 implementation and local/device gates passed. Atomic completion diff prepared; M2.2 remains unauthorized.

## Completion summary

M2.1 delivers the native lifecycle foundation with contract-versioned state snapshots, an idempotent state machine, atomic active-trip recovery metadata, a non-exported sticky location foreground service, and an immediate ongoing notification with a stop action. The bridge reports `lifecycle_ready` while conservatively keeping `recordingAvailable=false`.

Validation passed: Kotlin unit tests, dependency-free Android instrumentation on the physical Android 14 Tecno LH8n, Android lint, Dart formatting, Flutter analysis, all 40 Flutter tests, repository validation, generated-source verification, debug/release APK builds, APK size reporting, update-install, and cold launch. The physical proof covered activity recreation, explicit service recreation/recovery, app backgrounding, a short screen-off interval, notification presence, and clean stop.

Not yet verified or claimed: GNSS/IMU acquisition, a 30–60 minute locked-screen trip, process/device reboot recovery, battery drain, multi-version/OEM reliability, or telemetry durability. Those remain in M2.2–M2.8.
