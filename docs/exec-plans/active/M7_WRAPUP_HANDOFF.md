# Execution Plan — M7 bounded wrap-up and M8 handoff

**Status:** Complete (bounded engineering wrap-up; formal M7 acceptance deferred)
**Owner:** agent/maintainer
**Milestone:** M7; authorized sequencing handoff to M8
**Started:** 2026-11-17
**Last updated:** 2026-11-17

## Context budget / references

Root/test/ML agent rules; documentation and ML governance; roadmap M7/M8;
M7 exit audit and acceptance follow-up; tripdebug codec/quality intake and tests;
collection protocol. Expand only for an observed dependency.

## Goal / user-visible result

Finish the feasible M7 engineering wrap-up, prepare the maintainer's future
ordinary Tecno/Redmi trip, and retain explicit acceptance/distribution holds while
allowing M8 hardening. This is not formal M7 completion or model promotion.

## Authorization / scope

On 2026-11-17 the maintainer superseded acceptance-before-M8 sequencing: tighten
available M7 gaps, define the later routine trip, then move into M8 and stop before
main distribution. Carry M7.4/M7.5 and M6.8 gates forward. M8.1 is the next
authorized development substep; later numbered steps retain the normal approval
gate. Publishing/distributing a release is explicitly unauthorized.

In scope: checksum-pinned, read-only quality intake for exported tripdebug files;
generated regression tests and CI; future diagnostic trip procedure; current
acceptance/distribution ledger and status synchronization. Review production
disabled-inference/local-runtime bindings without activating them.

Out of scope: new trip/device operation, offset correction, sensor-quality waiver,
new real-source training/reopened experiment test access, model/runtime activation, live provider/Guardian action,
release signing or distribution, and M8 implementation in this wrap-up unit.

## Components / privacy / compatibility

Host tooling and generated tests only; no new library, app/schema/algorithm
migration, recorder sampling, battery, score or provider change. Raw exports stay
private/ignored; aggregate intake omits IDs, paths, hashes, vectors and timestamps.
Ordinary legacy inspector output remains compatible. Diagnostic inspection never
supplies labels, training consent, clock alignment or model admission.

## Implementation and validation

- [x] Add pinned exported-file quality intake reusing archive/quality validation;
  reject mismatch/change and emit only aggregate diagnostics.
- [x] Test valid/unreliable/unknown/flagged/missing sensor evidence, malformed
  archives, source mutation, single-descriptor reuse and private CLI failures.
- [x] Define future paired/single-phone routine diagnostic trip and private
  handoff, failure preservation and eventual model-acceptance boundary.
- [x] Record current gate ledger, distribution hold and M8.1 authorization;
  verify production inference and local runtime remain disabled/unavailable.
- [x] Run affected host regressions, repository/privacy and diff checks; source
  CI; commit/push/verify atomic work and record final source evidence.

## Acceptance / risks

All relevant software checks pass; no historical result or quality flag is
rewritten. No formal M7 acceptance is claimed. Both phones in one journey count
as one diagnostic session, not two independent drivers or ground truth. Unmeasured
clock uncertainty remains unknown; the Tecno's status/bias stays diagnostic.
Metric gates and real device/model efficiency remain unresolved until supported.

## Progress / completion

Baseline: clean `a19eba2`; repaired pilot source `68d91d6` passes all four CI jobs
44085930694. Previous exit audit supports conditional hardening with unaccepted
inference disabled. This unit has no dependency on a connected phone/emulator.

Completed: source `1bb6bdf4ba7da4ffefc8cf61bab990ccdd9bfd71` passes all four
[CI jobs 44090880412](https://github.com/atrx07/Traelyx/actions/runs/44090880412),
including the full application/native suites, both main APK builds, pilot/ML
tooling and existing generated experiments. All 42 affected local host tests
(13 new), actual module CLI smoke, full legacy-output comparison against the
retained baseline, repository/privacy checks and new local reference links pass.
The mutation test initially exposed buffered stale reads in the new implementation;
the finalized reader uses one unbuffered descriptor and rejects that mutation.

No private export or device was accessed; no sensor correction, app/runtime,
schema, score, provider or real-source model experiment changed. The final
evidence-only closure preserves every source pin and records the successful run;
unchanged runtime suites are not rerun. Commit/push/verify the synchronized
closure. M8 is activated, M8.1 is authorized but implementation has not started,
and later substeps keep normal approval gates. Main distribution remains held.
Formal M7 acceptance and all carried-forward physical/model gates stay open.
