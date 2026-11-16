# Execution Plan — M7.4/M7.5 model acceptance follow-up

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M7
**Started:** 2026-11-16
**Last updated:** 2026-11-16

## Goal / authorization

The maintainer explicitly chose to tackle M7.4 acceptance and M7.5 real-model
integration before M8. Preserve the frozen rejected v1 artifact, data splits,
results and thresholds. No promotion follows from this authorization alone.
M7.5 depends on a valid M7.4 candidate and accepted production feature/label data.

The maintainer subsequently authorized read-only inspection of old physical-phone
M2.8/M5 recordings, after checking upstream storage/handling documentation.
`origin/main` was fetched and matches `6582922`; no separate upstream remote exists.
Read the upstream M2.8 field record, M5 preservation/export record, recovery plan,
storage spec and precise-private tripdebug contract before phone access.

The maintainer reports permanent Tecno accelerometer damage and no available
second ADB phone, and authorized public-data research or derived bias correction.
Six rounded Physics Toolbox desk readings were confirmed to use g. Opposing-pose
pairs suggest device-axis offsets (+0.005, +0.005, +0.04) g and reading gains
(0.995, 0.995, 0.99). These are provisional diagnostics: tilt, rounding, residual
cross-axis error and historical stability are not validated. No correction was
applied to archived data, no quality flag was changed and no sensor exception
was approved. Public-source qualification is the primary next route.

## Current bounded scope

- Inventory authorized physical Tecno and existing recorder artifacts read-only.
- Preserve original recorder files, exports, accounts, pairing and accidental-trip
  exclusion ledger. Check idle state before any snapshot; never force-stop or
  update the main app, invoke live Guardian/Auth, change radios, start recording,
  clear data, or mutate device files during this intake.
- Keep source bytes, device identifiers, trip identifiers, routes, timestamps,
  vectors, database copies and per-trip diagnostics ignored/local. Prefer existing
  verified local recovery backups when they match, rather than copying more data.
- Assess data eligibility and feature-quality evidence, not model predictions or
  labels invented from the current rules. Known/reviewed recordings are diagnostic
  evidence, not a fresh held-out test set. Approximate rider notes are weak labels.
- Build/test a reusable bounded privacy-safe recording/acceptance intake tool if
  existing inspection lacks needed quality/split/annotation checks.
- Review primary upstream public-dataset metadata only for additional eligible
  data. Do not accept gated research terms, contact anyone, download large datasets
  or inspect a new held-out partition before freezing its governed protocol.

## Next dependencies

Freeze an explicitly versioned experiment only after suitable data and production
feature units/frame/timing/labels are established. Predeclare training/validation/
locked evaluation groups, numerical/value/calibration/efficiency criteria and
runtime comparison before observing outcomes. Preserve the old rejection; do not
try quantizers against its observed test set. Do not add a runtime dependency or
wire a model into the app before its own review and acceptance.

## Checks

- [x] Upstream handling/field-evidence review and safe physical device inventory.
- [x] Read-only preservation/QA exclusion checks and aggregate data assessment.
- [x] Meaningful intake regressions for format, timing, sensor quality, evidence
  provenance, labels/splits and privacy boundaries as applicable.
- [ ] Required format/static/regression/contract checks and bounded source CI.
- [ ] Persist scoped result, remaining concrete acceptance needs and next action;
  commit/push/verify without claiming M7.4 or M7.5 complete prematurely.

## Known constraints

M2.8 is pocket-carried, not vehicle-frame, with accelerometer status0 throughout.
Its approximate impact note is explicitly not confirmed event truth. M5's UI
checks preserved existing trips and do not imply new independent event labels.
The recovered 45m trip has a preserved raw-byte backup; recovery success is not
sensor/model quality acceptance. Mounted/vehicle/OEM and sustained battery gates
remain open. M8 remains inactive.

## Intake validation / next action

All 120 Python tests pass locally, including 18 focused decoder/intake tests.
The backup matches all 11,857 original phone chunks; before/after hashes of all
11,865 phone chunks are identical. Six original recordings remain diagnostic
only. See [intake contract and aggregate result](../../reference/EVENTNET_RECORDING_INTAKE_V1.md).
Source CI and persistence are pending. This bounded intake does not close M7.4
or M7.5. Next qualify public event-interval data, licensing and production-feature
compatibility before freezing any new model experiment.
