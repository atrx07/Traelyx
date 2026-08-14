# Execution Plan — M3 Telemetry Processing Engine

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M3
**Started:** 2026-08-14
**Last updated:** 2026-08-14

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

Finalized trips can be processed locally into explainable analysis and replay inputs. M3.1 establishes the fail-closed decoder and aligned analysis timebase; later authorized substeps add filtering, calibration, frames, derived channels, confidence, replay reduction, and regression coverage.

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
- Raw chunk bytes, precise coordinates, vectors, and source timestamps remain under native authority and do not cross the Flutter bridge in M3.1.
- The accepted private fixture remains local and is not committed or logged.

## Compatibility/migration implications

- M3.1 reads existing raw chunk encoding/schema version 1 without changing it.
- Unknown versions, corrupt chunks, mixed trips, sequence gaps, and invalid ordering fail closed.
- No Drift schema or storage migration is required for M3.1.

## Implementation steps

- [x] M3.1 Add a versioned raw trip decoder and deterministic aligned analysis timeline with explicit missing/interpolated states.
- [ ] M3.2 Add GNSS sanity filtering and confidence-aware distance accumulation.
- [ ] M3.3 Add stationary/bias calibration with visible quality state.
- [ ] M3.4 Add device/world/vehicle frame transforms with explicit orientation confidence.
- [ ] M3.5 Add versioned filtered speed, acceleration, jerk, yaw, and movement channels.
- [ ] M3.6 Add explainable confidence subcomponents and aggregate eligibility.
- [ ] M3.7 Add a reduced synchronized replay stream.
- [ ] M3.8 Add the governed deterministic fixture regression corpus.

## Tests / validation

- [x] Kotlin static compilation through focused/full Gradle unit tasks.
- [x] Focused native decoder/resampler unit and golden-fixture tests.
- [x] Complete native unit suite: 69 passed, 0 failed/skipped.
- [x] Flutter analysis and tests for regression safety: no analysis issues; 93 tests passed.
- [x] Android debug APK build.
- [x] Repository formatting, JSON/YAML, secret, and private-fixture validation.
- [x] Real-device validation not required for M3.1: no acquisition/lifecycle behavior or physical-quality claim changed.

## Acceptance criteria

- Raw schema/encoding version 1 decodes without semantic or unit changes.
- Chunk input order cannot reorder global raw evidence.
- Invalid, corrupt, mixed-trip, gapped-sequence, and overlapping evidence fails closed.
- The versioned analysis timeline uses monotonic trip time, preserves source provenance, never extrapolates IMU values, bounds interpolation across gaps, and does not interpolate GNSS coordinates before sanity filtering.
- The same verified input and configuration produce the same timeline.
- Applicable validation gates pass before each substep is marked complete.

## Risks

- Long trips can be expensive if callers eagerly materialize the analysis timeline; M3.1 exposes repeatable lazy frame iteration.
- Device mounting, motorcycle vibration, and the Tecno accelerometer status require later calibration/confidence handling and must not be hidden during decoding.
- Full multi-device, battery, and deep-sleep reliability remain M8 hardening concerns.

## Decisions made during execution

- Keep M3.1 raw decode/resampling in pure native Kotlin beside the native raw authority. This preserves the established bridge privacy boundary and introduces no dependency.
- Analysis timeline version 1 is anchored to monotonic trip elapsed time at a configurable, snapshotted cadence. IMU may be linearly interpolated only between bounded bracketing samples; GNSS remains original sparse evidence for M3.2.

## Progress log

- 2026-08-14: Maintainer authorized the intended next step; M3 activated with M3.1 in progress.
- 2026-08-14: M3.1 implementation and required gates completed. Stopped before M3.2 pending explicit authorization.

## Completion summary

M3.1 introduced a strict trip-wide decoder over the existing checksummed chunk contract and a versioned, configurable, lazy analysis timeline. GNSS samples remain original sparse evidence; IMU interpolation is bounded, provenance-preserving, confidence-conservative, and explicitly missing across unavailable/out-of-coverage/discontinuous/oversized-gap states.

Validation passed: focused and complete native unit suites (69 tests), Flutter analysis, all 93 Flutter tests, debug APK build, Dart formatting check, repository privacy/secret validation, and diff whitespace checks. No dependency, schema migration, network flow, raw-storage change, or new real-device reliability claim was introduced. M3.2 is pending maintainer authorization.
