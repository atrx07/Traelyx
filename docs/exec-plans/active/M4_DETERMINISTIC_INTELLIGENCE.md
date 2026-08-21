# Execution Plan — M4 Deterministic Intelligence v1

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M4
**Started:** 2026-08-21
**Last updated:** 2026-08-21

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

Completed trips can eventually produce explainable maneuver evidence, integrity state, scores, Drive DNA, and reason paths entirely on-device. M4.1 itself establishes typed event evidence; product presentation remains M5 scope.

## In scope

- M4.1 deterministic event taxonomy implementation.
- M4.2 event merge/debounce after separate authorization.
- M4.3 integrity rules v1 after separate authorization.
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

M4 remains local-native and consumes derived/aggregate evidence. M4.1 adds no network flow, permission, secret, raw route logging, or Flutter bridge payload.

## Compatibility/migration implications

M4.1 adds event-taxonomy version 1 without changing Drift, raw telemetry, M3 contracts, or historical stored results. Later persistence must retain the producing algorithm version.

## Implementation steps

- [x] M4.1: Add versioned event types, rule/config snapshots, evidence windows, confidence/quality provenance, and fail-closed deterministic detection over synchronized M3.5/M3.6 frames.
- [x] M4.1: Lock thresholds and expected/non-expected classifications against focused unit cases and the governed M3 synthetic corpus.
- [ ] M4.2: Merge/debounce candidate windows into coherent maneuver events. Pending authorization.
- [ ] M4.3: Add deterministic integrity rules v1. Pending authorization.
- [ ] M4.4: Add explicit confidence-weighted scoring v1. Pending authorization.
- [ ] M4.5: Add the Drive DNA baseline. Pending authorization.
- [ ] M4.6: Add personal/vehicle baseline lifecycle states. Pending authorization.
- [ ] M4.7: Add complete user-facing explanation data. Pending authorization.

## Tests / validation

- [x] Kotlin compilation and diff whitespace checks applicable to changed sources
- [x] focused event taxonomy unit tests
- [x] complete native unit-test suite
- [x] governed synthetic fixture replay through M4.1
- [x] affected debug and release builds
- [x] repository validation and secret/privacy review
- [x] real-device validation not required because M4.1 makes no new physical acquisition/reliability claim

## Acceptance criteria

- All M4.1 roadmap event classes are stable machine IDs with a versioned configuration snapshot.
- Detection consumes exact synchronized M3 derived/confidence evidence, never replay-reduced display values.
- Missing, unavailable, or invalidated required metric evidence cannot produce a maneuver event claim; limited evidence remains explicitly limited.
- Every emitted window retains source times, physical measurements/units, activation rules, severity calibration, eligibility, confidence reasons, and M3/M4 versions.
- Phone movement requires M3's explicit orientation-invalidated device-movement evidence and is never inferred from an arbitrary acceleration spike.
- Stationary, smooth, GNSS-loss, and motorcycle-vibration fixtures do not produce unsupported maneuver/impact claims; governed positive fixtures produce their intended taxonomy evidence.
- M4.2 merging, scoring, integrity verdicts, crash decisions, and persistence remain absent.

## Risks

- Initial deterministic thresholds are synthetic baselines and require later controlled physical tuning under a new version if field evidence contradicts them.
- Dynamic tilt/grade and mount quality limitations propagate from M3.
- Per-window M4.1 evidence is intentionally verbose until M4.2 supplies maneuver-level merging.

## Decisions made during execution

- M4.1 emits analysis-window evidence rather than final merged events, preserving the M4.2 boundary.
- Event confidence remains categorical (`supported`/`limited`) and preserves M3 eligibility/reasons; no false percentage is introduced.

## Progress log

- 2026-08-21: M4 and M4.1 authorized; plan activated after confirming clean synchronized `main` and completed M3 contracts.
- 2026-08-21: M4.1 implementation, governed regression tests, full native/Flutter gates, repository validation, and debug/release builds passed. M4.2 returned to the explicit approval gate.

## Completion summary

M4.1 complete. Event-taxonomy version 1 now emits deterministic, confidence-aware per-window evidence for all ten authorized classes while retaining M3 provenance and excluding unusable evidence. No schema, network, permission, recorder, Flutter bridge, or UI behavior changed. Thresholds remain synthetic baselines; M4.2 merging/debounce and controlled physical tuning remain unimplemented. M4 stays active behind the M4.2 approval gate.
