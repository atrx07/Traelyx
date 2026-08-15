# Execution Plan — M3 Telemetry Processing Engine

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M3
**Started:** 2026-08-14
**Last updated:** 2026-08-15

## Context budget / references

Read only:

- `AGENTS.md`
- `android/AGENTS.md`
- `docs/technical/TELEMETRY_SPEC.md`
- `docs/technical/SENSOR_PIPELINE.md`
- `docs/technical/STORAGE_SPEC.md`
- `docs/technical/PERFORMANCE_BUDGETS.md`
- `docs/governance/TESTING_POLICY.md`
- `docs/governance/DEFINITION_OF_DONE.md`
- `docs/exec-plans/milestones/M3_TELEMETRY_PROCESSING_ENGINE.md`
- native telemetry chunk models/codec and their focused tests

Do not read unrelated product, cloud, auth, map, ML, or release documentation unless a dependency is discovered.

## Goal

Convert verified local raw GNSS and IMU evidence into deterministic, physically meaningful, confidence-aware telemetry and replay channels without altering the M2 raw record.

## User-visible result

Finalized trips can be processed locally into explainable analysis and replay inputs. M3.1 establishes the fail-closed decoder and aligned analysis timebase; M3.2 adds auditable GNSS classification and distance accumulation; M3.3 adds explicit stationary IMU calibration state; later authorized substeps add frames, derived channels, confidence, replay reduction, and regression coverage.

## In scope

- M3.1 versioned raw trip decoding and time alignment/resampling.
- M3.2 GNSS sanity filtering and distance accumulation.
- M3.3 IMU calibration.
- M3.4 orientation/frame transform.
- M3.5 derived channels.
- M3.6 telemetry confidence v1.
- M3.7 replay channel generation.
- M3.8 fixture regression corpus.

## Out of scope

- Event detection, scoring, and Drive DNA (M4).
- Product replay UI (M5).
- Cloud upload of precise routes or raw telemetry.
- Rewriting, normalizing, or discarding M2 raw values and quality evidence.

## Preconditions

- M2 and its accepted first-fix-confirmed private fixture are complete.
- Raw chunk encoding version 1 and telemetry schema version 1 remain authoritative.
- Each numbered substep requires explicit maintainer authorization and its own completion gate.

## Affected components

- Native Kotlin telemetry processing models and pure algorithms.
- Native unit and deterministic fixture tests.
- Telemetry processing specifications and project status trackers.

## Data/privacy/security implications

- Processing remains local and accountless.
- Raw chunk bytes, precise coordinates, vectors, source timestamps, M3.2 GNSS decisions, and M3.3 calibration results remain under native authority and do not cross the Flutter bridge.
- The accepted private fixture remains local and is not committed or logged.

## Compatibility/migration implications

- M3.1–M3.3 read existing raw chunk encoding/schema version 1 without changing it.
- Unknown versions, corrupt chunks, mixed trips, sequence gaps, and invalid ordering fail closed.
- No Drift schema or storage migration is required for M3.1–M3.3.

## Implementation steps

- [x] M3.1 Add a versioned raw trip decoder and deterministic aligned analysis timeline with explicit missing/interpolated states.
- [x] M3.2 Add GNSS sanity filtering and confidence-aware distance accumulation.
- [x] M3.3 Add stationary/bias calibration with visible quality state.
- [ ] M3.4 Add device/world/vehicle frame transforms with explicit orientation confidence.
- [ ] M3.5 Add versioned filtered speed, acceleration, jerk, yaw, and movement channels.
- [ ] M3.6 Add explainable confidence subcomponents and aggregate eligibility.
- [ ] M3.7 Add a reduced synchronized replay stream.
- [ ] M3.8 Add the governed deterministic fixture regression corpus.

## Tests / validation

- [x] Kotlin static compilation through focused/full Gradle unit tasks.
- [x] Focused native decoder/resampler, GNSS sanity/distance, and stationary calibration tests.
- [x] Complete native unit suite: 92 passed, 0 failed/skipped.
- [x] Flutter analysis and tests for regression safety: no analysis issues; 93 tests passed.
- [x] Android debug APK build.
- [x] Repository formatting, JSON/YAML, secret, and private-fixture validation.
- [x] Real-device validation not required for M3.1–M3.3: no acquisition/lifecycle behavior changed and M3.3 makes no cross-device or physical calibration-quality claim. Private fixture replay/tuning remains later M3 work.

## Acceptance criteria

- Raw schema/encoding version 1 decodes without semantic or unit changes.
- Chunk input order cannot reorder global raw evidence.
- Invalid, corrupt, mixed-trip, gapped-sequence, and overlapping evidence fails closed.
- The versioned analysis timeline uses monotonic trip time, preserves source provenance, never extrapolates IMU values, bounds interpolation across gaps, and does not interpolate GNSS coordinates before sanity filtering.
- GNSS classification and distance accumulation preserve every original fix, break invalid chains, reject impossible jumps/stationary noise, and expose every exclusion or degradation reason.
- Stationary IMU calibration is deterministic and bounded-memory; missing, discontinuous, moving, unstable, unreliable, or insufficient evidence stays explicit, and one orientation never becomes a fabricated full accelerometer correction.
- The same verified input and configuration produce the same timeline.
- Applicable validation gates pass before each substep is marked complete.

## Risks

- Long trips can be expensive if callers eagerly materialize the analysis timeline; M3.1 exposes repeatable lazy frame iteration.
- Device mounting, motorcycle vibration, and the Tecno accelerometer status require later orientation, fixture replay/tuning, and confidence handling; M3.3 preserves them as raw/degraded evidence rather than hiding them.
- Full multi-device, battery, and deep-sleep reliability remain M8 hardening concerns.

## Decisions made during execution

- Keep M3.1 raw decode/resampling in pure native Kotlin beside the native raw authority. This preserves the established bridge privacy boundary and introduces no dependency.
- Analysis timeline version 1 is anchored to monotonic trip elapsed time at a configurable, snapshotted cadence. IMU may be linearly interpolated only between bounded bracketing samples; GNSS remains original sparse evidence for M3.2.
- Keep M3.2 GNSS processing pure and versioned beside the raw decoder. Classify every original fix, break the distance chain at low-accuracy/clock-discontinuous/gapped evidence, retain the prior anchor when isolating one impossible jump, and treat mock-location state as evidence rather than an automatic rejection.
- Separate distance resolved beyond combined horizontal-accuracy radii from plausible source-speed-supported distance within those radii. Stationary or unresolved within-accuracy movement contributes zero, while every decision retains its thresholds and evidence for auditability.
- Keep M3.3 calibration as a bounded-memory scan over the aligned native timeline. Select the quietest qualifying fixed-duration window, break candidates on missing/discontinuous/non-gravity-like/angular-motion evidence, and retain explicit diagnostics when no window qualifies.
- Treat a single stationary orientation as sufficient for zero-rate gyroscope bias and only the accelerometer bias component observable parallel to gravity. Preserve the raw mean/vector/status/provenance, degrade selected unreliable evidence, and defer full orientation, device-movement invalidation, gravity removal, and correction application to later authorized work.

## Progress log

- 2026-08-14: Maintainer authorized the intended next step; M3 activated with M3.1 in progress.
- 2026-08-14: M3.1 implementation and required gates completed. Stopped before M3.2 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.2; implementation and required local gates completed. Stopped before M3.3 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.3; implementation and required local gates completed. Stopped before M3.4 pending explicit authorization.

## Completion summary

M3.1 introduced a strict trip-wide decoder over the existing checksummed chunk contract and a versioned, configurable, lazy analysis timeline. GNSS samples remain original sparse evidence; IMU interpolation is bounded, provenance-preserving, confidence-conservative, and explicitly missing across unavailable/out-of-coverage/discontinuous/oversized-gap states.

M3.2 added versioned per-fix GNSS decisions and evidence plus cumulative resolved and source-speed-supported distance. Low accuracy, clock discontinuities, oversized gaps, impossible jumps, stationary jitter, unresolved within-accuracy segments, implausible source speed, and mock-location signals remain explicit; raw fixes are preserved.

M3.3 added a versioned, bounded-memory stationary-window calibrator with calibrated/degraded/insufficient states, explicit diagnostic evidence, conservative raw status/provenance, observable accelerometer radial bias, and zero-rate gyroscope bias. It does not rewrite raw evidence or claim a full accelerometer correction from one orientation.

Validation passed: focused and complete native unit suites (92 tests), Flutter analysis, all 93 Flutter tests, debug APK build, Dart formatting check, repository privacy/secret validation, and diff whitespace checks. No dependency, schema migration, network flow, raw-storage change, recorder behavior, bridge expansion, or new real-device reliability claim was introduced. M3.4 is pending maintainer authorization.
