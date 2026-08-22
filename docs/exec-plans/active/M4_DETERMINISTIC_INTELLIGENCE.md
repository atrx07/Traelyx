# Execution Plan — M4 Deterministic Intelligence v1

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M4
**Started:** 2026-08-21
**Last updated:** 2026-08-22

## Context budget / references

Read only:

- `AGENTS.md` and `android/AGENTS.md`
- `docs/technical/EVENT_ENGINE.md`
- M3.5–M3.7 contracts in `docs/technical/TELEMETRY_SPEC.md` and `SENSOR_PIPELINE.md`
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization rules in `DOCUMENTATION_POLICY.md`
- affected native telemetry/intelligence code and tests

Do not read scoring, Drive DNA, integrity, UI, ML, cloud, or unrelated documentation until its canonical substep is explicitly authorized.

## Goal

Deliver a deterministic, versioned, auditable local intelligence pipeline over the accepted M3 telemetry and confidence contracts, without an ML or network dependency.

## User-visible result

Completed trips can now produce coherent typed maneuver evidence and categorical integrity/rank-trust audits entirely on-device; later authorized M4 substeps add scores, Drive DNA, and reason paths. Product presentation remains M5 scope.

## In scope

- M4.1 deterministic event taxonomy implementation.
- M4.2 event merge/debounce.
- M4.3 integrity rules v1.
- M4.4 scoring v1 after separate authorization.
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

M4 remains local-native and consumes local raw/derived/aggregate evidence. M4.1–M4.3 add no network flow, permission, secret, raw route logging, or Flutter bridge payload.

## Compatibility/migration implications

M4.1 adds event-taxonomy version 1, M4.2 event-merge version 1, and M4.3 integrity-rules version 1 without changing Drift, raw telemetry, M3 contracts, or historical stored results. Later persistence must retain all producing algorithm versions.

## Implementation steps

- [x] M4.1: Add versioned event types, rule/config snapshots, evidence windows, confidence/quality provenance, and fail-closed deterministic detection over synchronized M3.5/M3.6 frames.
- [x] M4.1: Lock thresholds and expected/non-expected classifications against focused unit cases and the governed M3 synthetic corpus.
- [x] M4.2: Merge/debounce candidate windows into coherent maneuver events with versioned gap/debounce policy, deterministic IDs, conservative confidence, and explicit rejected-group decisions.
- [x] M4.3: Add deterministic integrity rules v1 over raw validity, GNSS decisions, sensor flags, cross-sensor confidence, and merged phone-movement evidence.
- [ ] M4.4: Add explicit confidence-weighted scoring v1. Pending authorization.
- [ ] M4.5: Add the Drive DNA baseline. Pending authorization.
- [ ] M4.6: Add personal/vehicle baseline lifecycle states. Pending authorization.
- [ ] M4.7: Add complete user-facing explanation data. Pending authorization.

## Tests / validation

- [x] Kotlin compilation and diff whitespace checks applicable to changed sources
- [x] focused event taxonomy unit tests
- [x] focused merge/debounce, separation, transient, limited-evidence, repeatability, and fail-closed ordering tests
- [x] focused integrity state/kind/dimension, mock, jump, speed, clock, dropout, disagreement, missing-corroboration, phone-movement, and corruption tests
- [x] complete native unit-test suite
- [x] governed synthetic fixture replay through M4.3
- [x] affected debug and release builds
- [x] repository validation and secret/privacy review
- [x] real-device validation not required because M4.1–M4.3 make no new physical acquisition/reliability claim

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
- M4.4+ scoring, crash decisions, moderation, server enforcement, and persistence remain absent.

## Risks

- Initial deterministic thresholds are synthetic baselines and require later controlled physical tuning under a new version if field evidence contradicts them.
- Dynamic tilt/grade and mount quality limitations propagate from M3.
- M4.2 gap and minimum-window settings are synthetic baselines and require a new merge version if controlled field evidence changes their historical meaning.
- M4.3 integrity thresholds and rank-state reduction are synthetic policy baselines; controlled field false positives require sanitized fixtures and a new integrity version.

## Decisions made during execution

- M4.1 emits analysis-window evidence rather than final merged events, preserving the M4.2 boundary.
- Event confidence remains categorical (`supported`/`limited`) and preserves M3 eligibility/reasons; no false percentage is introduced.
- M4.2 uses one active accumulator per machine ID, same-type 250 ms peak-gap grouping, three-window sustained debounce, one-window transient acceptance, strongest activation-ratio peak selection, and limited-if-any-source confidence reduction.
- Debounced groups remain first-class audit decisions; accepted IDs are deterministic over trip/type/version/time identity fields.
- M4.3 keeps one fixed accumulator per integrity rule, preserves upstream typed reasons/versions, and uses explicit `verified`/`limited_confidence`/`questionable`/`unranked` reduction with no percentage or intent inference.
- Only inconsistency-kind findings carry `EVT_TELEMETRY_INCONSISTENCY`; quality, platform-signal, and corruption findings remain semantically distinct.

## Progress log

- 2026-08-21: M4 and M4.1 authorized; plan activated after confirming clean synchronized `main` and completed M3 contracts.
- 2026-08-21: M4.1 implementation, governed regression tests, full native/Flutter gates, repository validation, and debug/release builds passed. M4.2 returned to the explicit approval gate.
- 2026-08-21: M4.2 authorized and implemented with bounded merge/debounce, deterministic identity, complete merged provenance, and governed raw-to-event regressions. M4.3 returned to the explicit approval gate after all required gates passed.
- 2026-08-22: M4.3 authorized and implemented with versioned categorical integrity/rank states, fixed-dimension evidence, corrupted-input failure, and governed raw-to-integrity regressions. M4.4 returned to the explicit approval gate after all required gates passed.

## Completion summary

M4.3 complete. Integrity-rules version 1 now audits raw validity, GNSS consistency, IMU health, cross-sensor agreement, temporal integrity, and M4.2 phone movement without claiming malicious intent. Findings retain typed evidence and reduce to explicit trip/rank states; invalid raw input fails closed without trusting a trip identity. No schema, network, permission, recorder, Flutter bridge, replay/UI, scoring, ML, moderation, server enforcement, or crash behavior changed. Integrity settings remain synthetic baselines. M4 stays active behind the M4.4 approval gate.
