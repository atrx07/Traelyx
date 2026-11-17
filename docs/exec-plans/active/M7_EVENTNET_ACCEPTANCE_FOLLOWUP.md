# Execution Plan — M7.4/M7.5 model acceptance follow-up

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M7
**Started:** 2026-11-16
**Last updated:** 2026-11-17

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

On 2026-11-16 the maintainer authorized continued acceptance work and explicitly
required M7 closure before M8. The next bounded unit is public-source
qualification. It may inspect small licensed source documentation, schemas and
bounded development samples after pinning publisher metadata/checksums. Any
inspected raw sample is disclosed as qualification-exposed, not unexamined test
evidence. Metadata/label review does not assign a future split or open additional
uninspected motion streams/groups; those need a new frozen protocol before
feature inspection or model evaluation. This is not a model experiment: no
training, model selection or held-out predictions occur in qualification.

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
- Review primary upstream public-dataset metadata and the bounded licensed
  qualification inputs described above. Do not accept gated research terms,
  contact anyone, download large datasets or inspect a new held-out partition
  before freezing its governed protocol. Keep precise public telemetry ignored
  locally as well; commit only attribution, hashes and aggregate findings.

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
- [x] Required format/static/regression/contract checks and bounded source CI.
- [x] Persist scoped result, remaining concrete acceptance needs and next action;
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
All four source CI jobs 43904210026 pass for `02f2a9f`; pushed source matches
`origin/main`. This bounded intake does not close M7.4 or M7.5. Next qualify
public event-interval data, licensing and production-feature compatibility before
freezing any new model experiment.

## Public-source qualification and manual-phone fallback

- [x] Pin official release/license metadata and bounded development inputs before
  schema/label inspection; no held-out model predictions or training.
- [x] Implement offline bounded public qualification, privacy/failure regressions
  and raw-source preservation checks. Both real pinned-source commands pass.
- [x] All 131 local Python tests pass, including 11 new source-qualification tests.
- [x] Build ordinary unconfigured debug APK; verify APK signature, package,
  minSDK 24 and arm64 Flutter/SQLite libraries for Redmi Note 9 / Android 10.
- [x] Full source CI: all four jobs 43911237347 pass for `da80f6a` on attempt 3;
  preserve source/blob hashes, failed-download history and aggregate result in the
  bounded atomic evidence closure. M7.4/M7.5 remain open.
- [x] Maintainer manual stationary record/save/private export result: 92 chunks,
  91.590 seconds, high reported IMU accuracy without flags, no GNSS fixes. Preserve
  original/private copy and exclude the stationary QA recording from model data.

The maintainer confirmed manual installation/export is possible without ADB and
completed the stationary check, but cannot collect trips this week. Public data
remains primary; Redmi is the last resort for later field evidence. No drive or
additional device interaction is authorized by the stationary instructions.
See [public-source qualification](../../reference/EVENTNET_PUBLIC_QUALIFICATION_V1.md)
and [manual procedure](../../reference/M7_MANUAL_PHONE_QUALITY_CHECK.md).

The inspected Harvard DB lacks driver/trip grouping, measured subsecond timing,
quality and independently verified interval truth. The inspected Zenodo labels
cover 169 intervals from one driver and only 129.037 seconds of explicitly
non-aggressive intervals. Neither source closes feature/label/split acceptance.
Do not infer normal labels for unlabelled time, fabricate timestamps or claim a
random window split provides independent drivers. Further public-source metadata
research may continue while CI/manual results are pending. M8 remains inactive.

## 2026-11-17 bounded source/feature-contract qualification

The maintainer authorized continued host work and made the existing emulator
available if useful. No device is required for this unit. Read the remaining two
small Q-Motion methodology/processing documents, session/rotation metadata and
manual-event annotation metadata (publisher size/SHA-256 verified, aggregate
output only). No telemetry ZIP, feature stream or model predictions are opened.
Inspect driver/class coverage before proposing any split; metadata review does
not automatically assign a test role. Keep all inspected inputs disclosed.

- [x] Verify remaining document and session/annotation pins; quantify grouped
  independent-label coverage and preprocessing mismatches.
- [x] Record a native-derived feature-contract proposal and source-admission
  conditions, separating measured timestamps, reconstructed timing, independent
  labels, forced normal labels and rules-generated labels.
- [x] Implement bounded metadata qualification and eleven generated regressions;
  all 142 local Python tests, pinned-source run and repository validation pass.
- [ ] Full source CI, aggregate evidence closure, commit/push/remote alignment.

No training, quantizer search, production model activation, release of NC-derived
weights, new dependency, contact with authors or large download is authorized by
this qualification unit. The old v1 rejection and required acceptance metrics
remain intact; the experiment can only be frozen after its data gates are met.

Results: 81 sessions / five driver groups, 13 annotation logs / 294 manual driving
intervals; group 4 has no zig-zag label. Baseline/unlabelled time is not verified
negative exposure. Edited manual intervals overlap and are not safe to convert
silently into a single-label target. Stored frame matrices do not all meet the
native orthonormal-frame contract. The input proposal targets existing 100 Hz M3
derived acceleration/yaw (`[1,4,600]`), with no extractor/model wired. See
`QMOTION_METADATA_QUALIFICATION_V1.md` and `EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md` in
`docs/reference/`. No class set, split, architecture or quantizer is selected.
