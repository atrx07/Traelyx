# Execution Plan — M3 Telemetry Processing Engine

**Status:** Complete
**Owner:** agent/maintainer
**Milestone:** M3
**Started:** 2026-08-14
**Completed:** 2026-08-21
**Last updated:** 2026-08-21

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

Finalized trips can be processed locally into explainable analysis and replay inputs. M3.1 establishes the fail-closed decoder and aligned analysis timebase; M3.2 adds auditable GNSS classification and distance accumulation; M3.3 adds explicit stationary IMU calibration state; M3.4 adds documented device/vehicle/world frame transforms; M3.5 adds filtered, provenance-preserving motion channels; M3.6 adds categorical confidence and metric-scoped eligibility; M3.7 adds evidence-preserving replay reduction; M3.8 locks those contracts into a governed deterministic synthetic regression corpus.

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
- Raw chunk bytes, precise coordinates, vectors, source timestamps, M3.2 GNSS decisions, M3.3 calibration results, M3.4 transforms, M3.5 derived channels, M3.6 confidence/eligibility, and M3.7 replay frames remain under native authority and do not cross the Flutter bridge.
- M3.8 commits only generated synthetic telemetry at a non-real coordinate origin; it does not ingest or reproduce a private route.
- The accepted private fixture remains local and is not committed or logged.

## Compatibility/migration implications

- M3.1–M3.8 read existing raw chunk encoding/schema version 1 without changing it.
- Unknown versions, corrupt chunks, mixed trips, sequence gaps, and invalid ordering fail closed.
- No Drift schema or storage migration is required for M3.1–M3.8.

## Implementation steps

- [x] M3.1 Add a versioned raw trip decoder and deterministic aligned analysis timeline with explicit missing/interpolated states.
- [x] M3.2 Add GNSS sanity filtering and confidence-aware distance accumulation.
- [x] M3.3 Add stationary/bias calibration with visible quality state.
- [x] M3.4 Add device/world/vehicle frame transforms with explicit orientation confidence.
- [x] M3.5 Add versioned filtered speed, acceleration, jerk, yaw, and movement channels.
- [x] M3.6 Add explainable confidence subcomponents and aggregate eligibility.
- [x] M3.7 Add a reduced synchronized replay stream.
- [x] M3.8 Add the governed deterministic fixture regression corpus.

## Tests / validation

- [x] Kotlin static compilation through focused/full Gradle unit tasks.
- [x] Focused native decoder/resampler, GNSS sanity/distance, stationary calibration, orientation/frame-transform, derived-channel, confidence/eligibility, replay-reduction, and complete-pipeline fixture tests.
- [x] Complete native unit suite: 149 passed, 0 failed/skipped across 23 suites.
- [x] Flutter analysis and tests for regression safety: no analysis issues; 93 tests passed.
- [x] Android debug APK build.
- [x] Repository formatting, JSON/YAML, secret, and private-fixture validation.
- [x] Real-device validation not required for M3.1–M3.8: no acquisition/lifecycle behavior changed. Synthetic fixtures validate deterministic frame/channel/confidence/reduction behavior without claiming mounted physical tuning, calibrated probabilities, or UI rendering quality; the accepted private route remains outside Git and logs.

## Acceptance criteria

- Raw schema/encoding version 1 decodes without semantic or unit changes.
- Chunk input order cannot reorder global raw evidence.
- Invalid, corrupt, mixed-trip, gapped-sequence, and overlapping evidence fails closed.
- The versioned analysis timeline uses monotonic trip time, preserves source provenance, never extrapolates IMU values, bounds interpolation across gaps, and does not interpolate GNSS coordinates before sanity filtering.
- GNSS classification and distance accumulation preserve every original fix, break invalid chains, reject impossible jumps/stationary noise, and expose every exclusion or degradation reason.
- Stationary IMU calibration is deterministic and bounded-memory; missing, discontinuous, moving, unstable, unreliable, or insufficient evidence stays explicit, and one orientation never becomes a fabricated full accelerometer correction.
- Versioned source-to-target matrices use documented Android device, vehicle forward-left-up, and world ENU conventions; they remain orthonormal/right-handed and expose unavailable, degraded, moved, stale, mock, and yaw-unobservable evidence without rewriting raw vectors.
- Versioned derived channels remain lazy, bounded-memory, deterministic, and source-provenanced; causal filters reset at invalid evidence boundaries, GNSS fallback speed remains explicitly degraded, movement uses hysteresis, and missing upstream evidence produces typed missing output instead of fabricated values.
- Versioned confidence remains categorical, lazy, deterministic, and explainable; component state retains typed reasons and source evidence, per-metric eligibility scopes faults to dependent channels, and cross-sensor disagreement cannot become a safety/integrity verdict or false global probability.
- Versioned replay reduction remains lazy, bounded-memory, deterministic, display-only, and independently sampled; exact first/terminal timestamps, representative provenance, extrema, missingness, movement transitions, confidence, and metric eligibility survive reduction without becoming scoring evidence.
- The versioned synthetic corpus covers stationary, straight, acceleration, braking, left/right corner, pothole, phone-move, GNSS-loss/recovery, and motorcycle-vibration evidence through the complete M3 pipeline, with byte-repeatable generation and physically meaningful expected ranges.
- The same verified input and configuration produce the same timeline.
- Applicable validation gates pass before each substep is marked complete.

## Risks

- Long trips can be expensive if callers eagerly materialize the analysis timeline; M3.1 exposes repeatable lazy frame iteration.
- Device mounting, real motorcycle vibration, dynamic tilt/grade coupling, filter/confidence threshold tuning, and the Tecno accelerometer status still require controlled physical fixture replay; M3.4–M3.8 preserve unsupported/degraded states rather than claiming synthetic coverage proves mounted, probabilistically calibrated, or rendered quality.
- Full multi-device, battery, and deep-sleep reliability remain M8 hardening concerns.

## Decisions made during execution

- Keep M3.1 raw decode/resampling in pure native Kotlin beside the native raw authority. This preserves the established bridge privacy boundary and introduces no dependency.
- Analysis timeline version 1 is anchored to monotonic trip elapsed time at a configurable, snapshotted cadence. IMU may be linearly interpolated only between bounded bracketing samples; GNSS remains original sparse evidence for M3.2.
- Keep M3.2 GNSS processing pure and versioned beside the raw decoder. Classify every original fix, break the distance chain at low-accuracy/clock-discontinuous/gapped evidence, retain the prior anchor when isolating one impossible jump, and treat mock-location state as evidence rather than an automatic rejection.
- Separate distance resolved beyond combined horizontal-accuracy radii from plausible source-speed-supported distance within those radii. Stationary or unresolved within-accuracy movement contributes zero, while every decision retains its thresholds and evidence for auditability.
- Keep M3.3 calibration as a bounded-memory scan over the aligned native timeline. Select the quietest qualifying fixed-duration window, break candidates on missing/discontinuous/non-gravity-like/angular-motion evidence, and retain explicit diagnostics when no window qualifies.
- Treat a single stationary orientation as sufficient for zero-rate gyroscope bias and only the accelerometer bias component observable parallel to gravity. Preserve the raw mean/vector/status/provenance, degrade selected unreliable evidence, and defer full orientation, device-movement invalidation, gravity removal, and correction application to later authorized work.
- Fix M3.4 version 1 to unchanged Android device axes, vehicle forward-left-up, and world ENU. Resolve tilt from M3.3 gravity while keeping yaw unobservable, bind movement comparisons to their calibration windows, require explicit mount-forward evidence, and admit GNSS course only when M3.2 decision, speed, bearing accuracy, and age are usable.
- Keep M3.5 pure, native, lazy, and versioned. Use a causal three-sample median before one-pole low-pass filters; subtract the measured stationary accelerometer mean and gyroscope bias before device-to-vehicle transformation; prefer platform speed, permit only accuracy-resolved geodesic speed as a degraded fallback, wrap course deltas through ±π, and reset dependent state across gaps, rejections, staleness, or context changes. Movement uses explicit speed/duration/sample-count hysteresis, and no device-specific bias constant is embedded.
- Keep M3.6 pure, native, lazy, categorical, and versioned. Expose GNSS, separate accelerometer/gyroscope, calibration, orientation, device-movement, source-agreement, and clock assessments; aggregate eligible/limited/excluded state per metric plus corroborated motion; use a 15 m preferred GNSS tier and compare recent moving yaw/heading rates within 0.5 rad/s without producing a global percentage or deciding safety/integrity outcomes.
- Keep M3.7 pure, native, lazy, bounded-memory, and versioned. Reduce synchronized M3.5/M3.6 frames on an independent 100 ms default trailing-window cadence; emit exact first and terminal timestamps; retain representative provenance, scalar/per-axis extrema, typed missingness, state transitions, and conservative confidence/eligibility summaries; keep replay output ephemeral and display-only.
- Keep M3.8 synthetic, code-generated, and explicitly versioned. Use fixed timestamps and a non-real coordinate origin, pass each case through the production raw-to-replay stages, assert physical ranges and typed evidence instead of brittle float dumps, and keep the accepted precise-private `.tripdebug` archive outside Git and logs.

## Progress log

- 2026-08-14: Maintainer authorized the intended next step; M3 activated with M3.1 in progress.
- 2026-08-14: M3.1 implementation and required gates completed. Stopped before M3.2 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.2; implementation and required local gates completed. Stopped before M3.3 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.3; implementation and required local gates completed. Stopped before M3.4 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.4; implementation and required local gates completed. Stopped before M3.5 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.5; implementation and required local gates completed. Stopped before M3.6 pending explicit authorization.
- 2026-08-15: Maintainer authorized M3.6; implementation and required local gates completed. Stopped before M3.7 pending explicit authorization.
- 2026-08-16: Maintainer authorized M3.7; implementation and required local gates completed. Stopped before M3.8 pending explicit authorization.
- 2026-08-21: Maintainer authorized M3.8; the governed deterministic corpus and complete-pipeline regression harness passed required local gates. M3 completed and stopped before M4 pending explicit authorization.

## Completion summary

M3.1 introduced a strict trip-wide decoder over the existing checksummed chunk contract and a versioned, configurable, lazy analysis timeline. GNSS samples remain original sparse evidence; IMU interpolation is bounded, provenance-preserving, confidence-conservative, and explicitly missing across unavailable/out-of-coverage/discontinuous/oversized-gap states.

M3.2 added versioned per-fix GNSS decisions and evidence plus cumulative resolved and source-speed-supported distance. Low accuracy, clock discontinuities, oversized gaps, impossible jumps, stationary jitter, unresolved within-accuracy segments, implausible source speed, and mock-location signals remain explicit; raw fixes are preserved.

M3.3 added a versioned, bounded-memory stationary-window calibrator with calibrated/degraded/insufficient states, explicit diagnostic evidence, conservative raw status/provenance, observable accelerometer radial bias, and zero-rate gyroscope bias. It does not rewrite raw evidence or claim a full accelerometer correction from one orientation.

M3.4 added versioned, right-handed device-to-vehicle and vehicle-to-ENU transforms with explicit mount evidence, calibration-window provenance, gravity-direction movement invalidation, usable-course gates, and resolved/degraded/unavailable outcomes. Geographic yaw remains explicitly unobservable from stationary gravity, and the transform stage does not remove gravity or create derived motion channels.

M3.5 added a versioned, lazy, bounded-memory derived telemetry pipeline with filtered vehicle acceleration, jerk, yaw, speed, heading-rate, and movement state. Every channel retains typed missingness and structured source/filter/upstream provenance; gaps and invalid context reset dependent state, speed fallback is explicitly degraded, and the Tecno fixture bias is handled through the measured stationary reference rather than a production phone-specific offset.

M3.6 added versioned categorical confidence for GNSS, separate IMU sensors, calibration, orientation, source agreement, device movement, and clock integrity plus metric-scoped eligible/limited/excluded outcomes and a stricter corroborated-motion aggregate. It preserves exact evidence without inventing a probability, prevents unrelated-source failure from erasing healthy channels, and treats yaw/heading disagreement as audit evidence rather than a safety/integrity decision.

M3.7 added a versioned, independently sampled replay timeline that reduces synchronized derived/confidence frames with bounded memory. Exact first/fixed/terminal timestamps, representative provenance, scalar/per-axis extrema, typed gaps, movement changes, categorical confidence, and metric eligibility remain explicit; the result stays display-only and cannot become scoring evidence.

M3.8 added a versioned code-generated synthetic corpus for stationary, straight, acceleration, braking, left/right corner, pothole, phone-move, GNSS-loss/recovery, and motorcycle-vibration evidence. A shared harness exercises chunk encoding/decoding, alignment, GNSS processing, stationary calibration, orientation/mount handling, derived channels, confidence/eligibility, and replay. Generation and repeated iteration are deterministic; expectations use physical tolerances and typed state/reason evidence; no private route or Tecno-specific production offset is included.

Validation passed: focused fixture tests and the complete native unit suite (149 tests across 23 suites), Flutter analysis, all 93 Flutter tests, debug APK build, Dart formatting check, repository privacy/secret validation, and diff whitespace checks. No dependency, schema migration, network flow, raw-storage change, recorder behavior, bridge expansion, or new real-device/UI reliability claim was introduced. M3 is complete; M4 remains pending explicit maintainer authorization.
