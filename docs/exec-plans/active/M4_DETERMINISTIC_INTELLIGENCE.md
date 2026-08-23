# Execution Plan — M4 Deterministic Intelligence v1

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M4
**Started:** 2026-08-21
**Last updated:** 2026-08-23

## Context budget / references

Read only:

- `AGENTS.md` and `android/AGENTS.md`
- `docs/technical/EVENT_ENGINE.md`
- `docs/technical/INTEGRITY_ENGINE.md`, `SCORING_SPEC.md`, `docs/product/DRIVE_DNA_SPEC.md`, and the relevant M4 machine-readable references
- M3.5–M3.7 contracts in `docs/technical/TELEMETRY_SPEC.md` and `SENSOR_PIPELINE.md`
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization rules in `DOCUMENTATION_POLICY.md`
- affected native telemetry/intelligence code and tests

Do not read M4.7 explanation/presentation, UI, ML, cloud, or unrelated documentation until its canonical substep is explicitly authorized.

## Goal

Deliver a deterministic, versioned, auditable local intelligence pipeline over the accepted M3 telemetry and confidence contracts, without an ML or network dependency.

## User-visible result

Completed trips can now produce coherent typed maneuver evidence, categorical integrity/rank-trust audits, evidence-eligible fixed-point score audits, a versioned multi-trip Drive DNA profile, and an auditable personal/vehicle/context lifecycle entirely on-device; the later authorized M4.7 substep adds explanation data. Product presentation remains M5 scope.

## In scope

- M4.1 deterministic event taxonomy implementation.
- M4.2 event merge/debounce.
- M4.3 integrity rules v1.
- M4.4 scoring v1.
- M4.5 Drive DNA baseline after separate authorization.
- M4.6 personal/vehicle baseline lifecycle after separate authorization.
- M4.7 explanation data after separate authorization.

## Out of scope

- Event persistence or schema migration unless a later authorized M4 contract requires it.
- ML classification, crash decisions, legal or moral judgments.
- Replay/UI presentation, maps, cloud sync, social, and commentary.
- Preparing or implementing any later M4 substep before its approval gate.

## Preconditions

- M0–M3 complete and synchronized on `origin/main`.
- Maintainer explicitly authorized M4 on 2026-08-21.
- M3 derived telemetry, confidence, eligibility, and synthetic regression corpus remain the source contracts.

## Affected components

- Native Kotlin deterministic intelligence models/pipeline.
- Native unit and end-to-end synthetic fixture tests.
- Event-engine and telemetry contract documentation.
- Roadmap/status/progress documents.

## Data/privacy/security implications

M4 remains local-native and consumes local raw/derived/aggregate evidence. M4.1–M4.6 add no network flow, permission, secret, raw route logging, or Flutter bridge payload. M4.6's personal and mount/sensor context values are opaque application-local keys, not hardware, advertising, route-derived, or mandatory account identifiers.

## Compatibility/migration implications

M4.1 adds event-taxonomy version 1, M4.2 event-merge version 1, M4.3 integrity-rules version 1, M4.4 scoring version 1, M4.5 Drive DNA version 1, and M4.6 Drive DNA lifecycle version 1 without changing Drift, raw telemetry, M3 contracts, or historical stored results. Schema-v1 already has a compatible future baseline snapshot boundary, so M4.6 requires no migration. Later persistence must retain every producing algorithm/config version and must not silently recompute old scores or profiles.

## Implementation steps

- [x] M4.1: Add versioned event types, rule/config snapshots, evidence windows, confidence/quality provenance, and fail-closed deterministic detection over synchronized M3.5/M3.6 frames.
- [x] M4.1: Lock thresholds and expected/non-expected classifications against focused unit cases and the governed M3 synthetic corpus.
- [x] M4.2: Merge/debounce candidate windows into coherent maneuver events with versioned gap/debounce policy, deterministic IDs, conservative confidence, and explicit rejected-group decisions.
- [x] M4.3: Add deterministic integrity rules v1 over raw validity, GNSS decisions, sensor flags, cross-sensor confidence, and merged phone-movement evidence.
- [x] M4.4: Add explicit confidence-weighted scoring v1 with physical opportunity eligibility, fixed-point audit contributions, missing-dimension synthesis, integrity gating, and a low-dimension overall guardrail.
- [x] M4.5: Add a versioned Drive DNA baseline over comparable, fully eligible trip dimensions with robust aggregation, explicit evidence states, and cross-trip consistency.
- [x] M4.6: Add personal/vehicle/context cohort selection with explicit uncalibrated, emerging, established, and recalibrating lifecycle states.
- [ ] M4.7: Add complete user-facing explanation data. Pending authorization.

## Tests / validation

- [x] Kotlin compilation and diff whitespace checks applicable to changed sources
- [x] focused event taxonomy unit tests
- [x] focused merge/debounce, separation, transient, limited-evidence, repeatability, and fail-closed ordering tests
- [x] focused integrity state/kind/dimension, mock, jump, speed, clock, dropout, disagreement, missing-corroboration, phone-movement, and corruption tests
- [x] focused scoring config/fixed-point, opportunity, unavailable/provisional/full, confidence weighting, contribution audit, integrity gating, guardrail, and rank-state tests
- [x] focused Drive DNA config/version, raw-score capture, early-history, robust median, dispersion/consistency, partial-profile, eligibility-filter, snapshot, duplicate, and repeatability tests
- [x] focused lifecycle config/state, vehicle/class/context isolation, inactivity epoch, rolling-window, evidence-filter, snapshot, invalid-timeline, provenance, and repeatability tests
- [x] complete native unit-test suite
- [x] governed synthetic fixture replay through M4.6
- [x] affected debug and release builds
- [x] repository validation and secret/privacy review
- [x] real-device validation not required because M4.1–M4.6 make no new physical acquisition/reliability claim

## Acceptance criteria

- All M4.1 roadmap event classes are stable machine IDs with a versioned configuration snapshot.
- Detection consumes exact synchronized M3 derived/confidence evidence, never replay-reduced display values.
- Missing, unavailable, or invalidated required metric evidence cannot produce a maneuver event claim; limited evidence remains explicitly limited.
- Every emitted window retains source times, physical measurements/units, activation rules, severity calibration, eligibility, confidence reasons, and M3/M4 versions.
- Phone movement requires M3's explicit orientation-invalidated device-movement evidence and is never inferred from an arbitrary acceleration spike.
- Stationary, smooth, GNSS-loss, and motorcycle-vibration fixtures do not produce unsupported maneuver/impact claims; governed positive fixtures produce their intended taxonomy evidence.
- Same-type neighboring evidence becomes one maneuver-level event with deterministic identity, complete peak/source evidence, and conservative merged confidence.
- Short sustained noise is retained as an explicit debounced decision while transient impact/transition/phone-movement evidence remains eligible from one window.
- Integrity output separates quality limitation, platform signal, inconsistency, and corruption while reducing fixed dimensions to versioned categorical trip/rank states.
- Clean governed fixtures remain verified; GNSS loss and phone movement remain limited; mock, isolated impossible motion, clock/source conflict, and missing inertial corroboration are reviewable rather than intent claims; repeated impossible jumps and invalid raw input are unranked.
- Scores require explicit opportunity and usable evidence; absent evidence is unavailable, limited evidence is provisional, and every numerical penalty retains exact event/confidence provenance.
- Strong sustained maneuvers are not automatically penalized, road impacts/phone movement are excluded from driver-control penalties, and maximum speed is never an input or ranking category.
- Overall synthesis defines missing dimensions and prevents one low dimension from being hidden; verified/full output is locally rank-eligible while questionable/unranked integrity remains review/ineligible.
- Drive DNA v1 accepts a caller-supplied comparable cohort, aggregates only fully eligible verified dimensions, retains source trip/value/state/version evidence, and refuses to form direct baselines before five eligible observations.
- Drive DNA direct dimensions use a robust median, profile consistency uses cross-trip mean-absolute-deviation evidence from at least three available direct dimensions, and scoring-v1 trip/overall meaning remains unchanged.
- Lifecycle selection rejects ambiguous time/identity input, partitions history by exact personal/vehicle/class/mount/sensor scope, and retains per-candidate inclusion decisions without requiring an account or network.
- Empty/current/established evidence maps deterministically to uncalibrated/emerging/established; vehicle, class, context, and long-inactivity changes remain recalibrating until ten current observations produce a complete M4.5 profile.
- Only the latest 30 eligible observations after the most recent greater-than-90-day inactivity gap can contribute, while excluded and pre-epoch evidence remains auditable and scoring-v1 history remains unchanged.
- M4.7 full explanation paths, crash decisions, moderation, server enforcement, and persistence remain absent.

## Risks

- Initial deterministic thresholds are synthetic baselines and require later controlled physical tuning under a new version if field evidence contradicts them.
- Dynamic tilt/grade and mount quality limitations propagate from M3.
- M4.2 gap and minimum-window settings are synthetic baselines and require a new merge version if controlled field evidence changes their historical meaning.
- M4.3 integrity thresholds and rank-state reduction are synthetic policy baselines; controlled field false positives require sanitized fixtures and a new integrity version.
- M4.4 eligibility floors, weights, penalties, confidence reduction, and guardrail are synthetic baselines; controlled field calibration requires a new scoring version.
- M4.5 observation floors, median aggregation, and consistency conversion are synthetic baselines; controlled cohort evidence requires a new Drive DNA version.
- M4.6 observation/state/window/inactivity settings are synthetic lifecycle baselines; controlled field evidence requires a new lifecycle version.

## Decisions made during execution

- M4.1 emits analysis-window evidence rather than final merged events, preserving the M4.2 boundary.
- Event confidence remains categorical (`supported`/`limited`) and preserves M3 eligibility/reasons; no false percentage is introduced.
- M4.2 uses one active accumulator per machine ID, same-type 250 ms peak-gap grouping, three-window sustained debounce, one-window transient acceptance, strongest activation-ratio peak selection, and limited-if-any-source confidence reduction.
- Debounced groups remain first-class audit decisions; accepted IDs are deterministic over trip/type/version/time identity fields.
- M4.3 keeps one fixed accumulator per integrity rule, preserves upstream typed reasons/versions, and uses explicit `verified`/`limited_confidence`/`questionable`/`unranked` reduction with no percentage or intent inference.
- Only inconsistency-kind findings carry `EVT_TELEMETRY_INCONSISTENCY`; quality, platform-signal, and corruption findings remain semantically distinct.
- M4.4 uses deterministic integer milli-points, half-up display rounding, 0.5 limited-event weighting, explicit opportunity/coverage gates, and full/provisional/unavailable/unranked states rather than a confidence percentage.
- A single sustained strong event creates scoring opportunity but no automatic penalty; only abrupt evidence and repeated strong/high-load events after the first contribute in version 1. No positive bonus exists without governed positive-event evidence.
- Overall scoring renormalizes available direct-dimension weights, requires at least two dimensions, and is capped at the lowest available dimension plus 15 points. Consistency remains unavailable inside scoring-v1 and is derived separately by Drive DNA v1.
- M4.5 keeps scoring-v1 immutable and derives a separate profile-level consistency value from cross-trip dispersion. Five full/verified observations are required per direct dimension and three available direct dimensions are required for consistency.
- M4.5 profile `complete`/`partial`/`unavailable` states describe evidence coverage only. Personal `uncalibrated`/`emerging`/`established`/`recalibrating` lifecycle and vehicle-aware partitioning were reserved for M4.6.
- M4.6 uses a separately versioned local reducer so M4.5 aggregation and scoring-v1 history stay immutable. Personal lifecycle starts emerging at one eligible observation but requires ten plus a complete profile for established.
- The current cohort is exact-scope only and bounded to the latest 30 valid observations after the latest greater-than-90-day gap. Vehicle/class/context changes stay explicit recalibration reasons until fresh evidence becomes established.
- Opaque local personal/mount/sensor keys are partition labels only; they do not introduce a cloud identity, device fingerprint, permission, or upload path.

## Progress log

- 2026-08-21: M4 and M4.1 authorized; plan activated after confirming clean synchronized `main` and completed M3 contracts.
- 2026-08-21: M4.1 implementation, governed regression tests, full native/Flutter gates, repository validation, and debug/release builds passed. M4.2 returned to the explicit approval gate.
- 2026-08-21: M4.2 authorized and implemented with bounded merge/debounce, deterministic identity, complete merged provenance, and governed raw-to-event regressions. M4.3 returned to the explicit approval gate after all required gates passed.
- 2026-08-22: M4.3 authorized and implemented with versioned categorical integrity/rank states, fixed-dimension evidence, corrupted-input failure, and governed raw-to-integrity regressions. M4.4 returned to the explicit approval gate after all required gates passed.
- 2026-08-22: M4.4 authorized and implemented with fixed-point opportunity-gated dimensions, event/confidence contribution audits, integrity/ranking reduction, governed raw-to-score regressions, and an exact machine-readable configuration. M4.5 returned to the explicit approval gate after all required gates passed.
- 2026-08-22: M4.5 authorized and implemented with versioned compact score observations, per-dimension verified/full eligibility, robust cross-trip profile medians, dispersion-derived consistency, and complete provenance/config snapshots. M4.6 returned to the explicit approval gate after all required gates passed.
- 2026-08-23: M4.6 authorized and implemented with versioned personal/vehicle/context isolation, current-epoch rolling cohort selection, explicit lifecycle/recalibration states, and complete candidate/config/source audit. M4.7 returned to the explicit approval gate after all required gates passed.

## Completion summary

M4.6 complete. Drive DNA lifecycle version 1 now selects an immutable comparable cohort by exact local personal scope, vehicle profile/class, and opaque mount/sensor context; excludes unusable and stale-epoch evidence; bounds the baseline to the latest 30 valid trips; and exposes deterministic uncalibrated, emerging, established, or recalibrating state. Establishment requires ten current observations plus a complete unchanged M4.5 profile. Every candidate decision, selected ID, window, trigger, configuration, and upstream version remains auditable. No schema/persistence, historical recomputation, account/network, permission, recorder, Flutter bridge, replay/UI, comparison/explanation text, scoring/ranking, ML, moderation, server enforcement, or crash behavior changed. Lifecycle settings remain synthetic baselines and `production_ready: false`. M4 stays active behind the M4.7 approval gate.
