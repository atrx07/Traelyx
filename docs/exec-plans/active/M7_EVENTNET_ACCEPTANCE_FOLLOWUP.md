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
was approved. Public-source qualification was the next route; the subsequent
bounded review and protocol sections below record its disposition.

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
- [x] Full source CI: all four jobs 44028381119 pass for `fbaa36d` on attempt 1;
  preserve source/blob hashes in the atomic aggregate evidence closure and
  commit/push/verify remote alignment before reporting this unit complete.

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

The pinned quality report also describes weak cross-IMU acceleration agreement;
this is publisher-reported evidence, not a matched native-preprocessing test.
A bounded follow-up at VTTI's original 100-Car Data V2.1 page confirms CC0,
baseline metadata and reported 1–10 Hz vehicle instrumentation. Public compatible
sensor negatives and a complete pinned inventory were not established; no sensor
file was downloaded. See the public-source reference and aggregate evidence.
The remaining acceptance dependency is suitable independently reviewed driving
exposure with usable timing/quality and independent evaluation groups. Devices
alone cannot supply these labels. M7.4/M7.5 remain open and M8 remains inactive.

## Authorized feature and real-stream feasibility unit — 2026-11-17

The maintainer authorized the proposed provisional extractor and small public
development-recording check. No phone/emulator access is needed. This extends
the earlier metadata-only scope; it is not a training experiment or promotion.

Before opening sensor content, designate Zenodo 6570972 v1 trip 2 acceleration
and gyro streams as qualification-exposed development inputs. All three label
files were already inspected. Other motion streams remain unopened. Record
publisher sizes/MD5 and protocol in `ml/qualification/zenodo-stream-feasibility-v1.json`
before retrieval; verify complete bytes and add SHA-256 before parsing. Inspect
the publisher notebook as source text only, never execute it. Maximum download
budget is 35 MB for these three fixed files; preserve originals locally.

- [x] Implement an unwired provisional native extractor over synchronized M3
  derived/confidence frames: fixed defaults, channel order, complete supported
  window, stable context, provenance and finite float32; preserve quality decisions.
- [x] Test generated pipeline-to-tensor values, boundaries, quality/context/gap
  rejection, immutability and unsupported configuration without a model/runtime.
- [x] Inspect pinned trip-2 streams and notebook for measured timing, units/frame,
  synchronization, label coverage and feasibility. Emit aggregates only; do not
  synthesize Android accuracy, calibration, vehicle frame or negative labels.
- [x] Run appropriate native/Python regressions and builds; all four source CI
  jobs 44035810697 pass for `e2b1445` on attempt 1. Preserve source/blob hashes,
  update evidence/status, commit/push/verify and report compatibility disposition.

The extractor stays outside production callers. No schema, acquisition, sampling,
score, Guardian, dependency or historical model changes; no training, predictions,
large corpus download or new drive. A public preprocessed linear-acceleration
stream cannot silently stand in for native raw accelerometer preprocessing.
Passing software tests or a developmental compatibility check does not close
the independent-normal, grouped evaluation, mobile or M7.5 integration gates.

All ten focused native extractor tests, 519 full native tests and 150 Python
tests, Android lint and debug build pass. Real streams have approximately 400 Hz
timing with no gaps above 5.001 ms; 641 development windows have timing support.
Frame/gravity/quality and independent label-clock alignment remain unverified, so no native public tensor
or model is created. The 33 short event intervals require an explicit future
window-label policy, not silent exclusion or inferred normal background. Original
source/protocol hashes are preserved; the publisher notebook was never executed.
Clean asynchronous native IMU is also rejected by the proposal's strict eligibility
policy in a realistic regression. Establish an explicit feature-quality policy
before a general-use contract; do not rewrite native confidence to hide interpolation.

## Input-quality policy while independent research proceeds — 2026-11-17

The maintainer asked for useful parallel work while their research agent searches
for data. Implement a separate **development v2** extractor admitting only native
bounded IMU interpolation, with mandatory copied quality metadata. Preserve v1's
strict entry point, tests and rejection. M3 confidence/eligibility, production
analysis, scores and Guardian do not change. This is a proposed feature policy,
not an accepted model input/distribution/training protocol or promotion.

Native derived quality is cumulative since filter reset: an earlier interpolation
can keep a channel degraded even when the current raw alignment is exact. Validate
both current confidence/brackets and accumulated derived evidence/provenance;
never accept arbitrary LIMITED evidence or erase historical faults. Use the native
default 50 ms bracket bound as a development ceiling, not a precision guarantee.

- [x] Version the v2 input/quality-sidecar contract and implement the separate
  factory with shared window packing, preserving v1 behavior.
- [x] Retain current interpolation, historical interpolation and native limited
  eligibility per channel/target, source accuracy and bracket/lookahead bounds.
- [x] Test exact/offset/history-only inputs, gaps, unreliable or flagged sources,
  unsupported context/components, forged provenance and metadata immutability.
- [x] Run full native tests, lint/build and repository validation; all four source
  CI jobs 44042014141 pass for `e8ad83e` on attempt 1. Preserve source/blob hashes,
  synchronize evidence/status, commit/push/verify and report remaining gates.

No phone/emulator, dataset retrieval, private archive access, new source-model
training/prediction, runtime/provider dependency, schema migration or production caller.
The external research agent owns source discovery; review its findings separately
after this bounded implementation is persisted. Formal M7.4/M7.5 remain open.

All 528 native tests pass (ten unchanged v1 feature tests plus nine new v2 tests),
alongside Android lint, debug build and repository validation. Generated 1 ms gyro
offsets now construct a v2 window with 600 current/history/native-LIMITED masks;
v1 still rejects the same input. Earlier unreliable evidence remains rejected,
and history-only interpolation stays visible when current samples become exact.
The native 50 ms bracket boundary is tested without claiming field precision.

## Ferreira primary-source follow-up — 2026-11-17

The maintainer authorized investigating the research report's strongest technical
lead, then resumed this interrupted run. Review publisher statements, the paper,
collection/preprocessing source text and small trip metadata only. No sensor CSV,
new model experiment, held-out feature inspection, author contact or device access.

- [x] Check public author replies for permission, original frames and video access.
- [x] Trace units, target timestamps and Earth-frame conversion in primary sources;
  inspect all four published trip metadata schemas and the R loading path for
  driver assignment without inferring drivers from dates or trip IDs.
- [x] Persist corrected findings/provenance, update the source/priority references,
  validate documentation contracts, inspect diff, commit/push/verify.

Affirmative author permission with attribution exists; the paper specifies units.
The author reports no longer having videos and retaining neither original
device-frame samples nor rotation matrices. Published trip metadata and reviewed
loader do not establish driver assignment. Earth coordinates cannot silently
become vehicle coordinates. Stop planning a fresh normal-driving video annotation
pass from this source unless new footage is actually located. No source/model
admission or M7 completion follows. Only documentation/provenance checks apply;
unchanged runtime/native/model suites need not be rerun for this review.

Repository validation, source/metadata consistency and whitespace checks pass.
Persist this documentation-only unit atomically and verify remote alignment before
reporting it complete. Source/model admission remains false.

## Remaining research candidates — 2026-11-17

The maintainer authorized one bounded pass over the remaining external-report
candidates to decide whether any can support a governed acceptance experiment.
Inspect primary documentation, permissions and schemas only. Stop at a decisive
documented incompatibility; do not download archives or motion streams, assign
splits, train, contact authors or operate devices. Reuse earlier qualification
for baseline sources rather than repeating their investigations.

- [x] Enumerate remaining report candidates and verify their strongest relevant
  claims in publisher documentation or source repositories.
- [x] Record compatible inputs/timing/frame, independent event/normal labels,
  evaluation groups, permission and unresolved evidence distinctly.
- [x] Select a qualifying lead or state the concrete missing evidence; validate
  references/contracts, synchronize status, commit/push and verify.

This is source triage, not model acceptance. Documentation/provenance checks apply;
runtime/native/model tests are unnecessary without implementation changes.

Fifteen leads establish no complete acceptance corpus. Official Kaggle metadata
resolves Popescu v2 as CC BY 4.0 and Large-Scale v1 as CC BY-NC-SA 4.0; two-Hz
inputs and label limitations still preclude native acceptance. The newer accepted
V-SenseDrive article explicitly identifies released speed-rule labels. Preserve
positive partial evidence (including Brain4Cars straight annotations) without
inventing matched IMU/driver/normal truth. See
`docs/reference/EVENTNET_REMAINING_SOURCE_TRIAGE_V1.md`.

Repository validation, all 15 decision/non-admission assertions, documentation
links, five Git blob pins and three captured HTTP metadata pins (including both
Kaggle versions/licences) pass, as does whitespace validation. No archive, model,
device, private telemetry, code, dependency or migration change. Stop the repeated
same-report search; the next dependency is a concrete collection/independent
annotation and locked-evaluation protocol before any new recording or governed
public reannotation. No such protocol or model experiment is implemented here.
Persist this bounded review and verify the remote before reporting completion.

## Collection / annotation protocol preparation — 2026-11-17

The maintainer authorized continuing with the next evidence protocol after the
bounded source review. Prepare an actionable capture/review packet and empty local
templates; do not collect, contact contributors, operate devices, select a source,
assign real split roles or freeze a model experiment. Vehicle recording remains
deferred. Refer to dataset/ML governance, native v2 quality and the existing private
export/manual-phone procedure. Preserve all previous exclusions and model results.

- [x] Define collection preflight, independent synchronization/reference evidence,
  label review, severity limits and privacy/retention handling.
- [x] Provide empty session/review and experiment-freeze templates; distinguish
  planning targets, missing resources and actual admission evidence.
- [x] Define grouping, reviewed exposure, event matching, uncertainty, evaluation
  and device-efficiency prerequisites without claiming collected data or results.
- [x] Check templates/references/statistical examples and repository contracts;
  synchronize status, inspect exact diff, commit/push and verify.

Documentation/templates only: no runtime, native or model test changes required.

Prepared `EVENTNET_EVIDENCE_COLLECTION_V1.md` and the empty v1 packet. The initial
six-driver role allocation is a revisable planning target, not a statistical
sufficiency claim or actual group assignment. A single-driver diagnostic pilot
can check feasibility. Human review, independent physical strength and clock
evidence remain necessary; video-only maneuver labels do not establish strong
event truth, and invalidated device movement remains an abstention/quality slice.

Repository contracts/secret checks, template non-admission/empty-state and role
counts, documentation links, and all four model-based Poisson planning examples
pass; whitespace checks pass. No rate/performance gate is adopted by the examples.
Numeric experiment gates remain mandatory open freeze fields until baseline
feasibility justifies them before test access. No collected data, phone/emulator,
new dependency, migration, scoring/model/runtime change or M7 completion. Persist
the reviewed packet/status atomically and verify the remote before reporting.

## Parked synchronization pilot tooling — 2026-11-17

The maintainer authorized making the pilot executable. Implement a separate
permission-free Android software-marker app and standard-library host clock
checker, with generated tests. It must not modify the recorder/app, start a trip,
read old recordings, contact anyone, or claim screen draw times are physical
presentation times. Preserve unknown display/camera delay, same-boot/recording
binding, reference provenance and physical strength as unresolved evidence.

- [x] Build bounded persistent marker journals, explicit parked start/stop and
  local SAF export in an isolated package; test pure journal invariants.
- [x] Check pinned journals and reference observations using exact centered
  affine arithmetic, disjoint fit/check anchors, bounded time support and explicit
  uncertainty. Reject corruption, reset/order/range faults and silent precision.
- [x] Add meaningful host/CLI/privacy regressions and CI build/lint/APK checks;
  validate an authorized existing emulator if available, leaving physical phones
  for later optical/reference verification.
- [x] Document exact limits, synchronize evidence/status, run appropriate checks,
  inspect diff, commit/push and verify source CI before reporting completion.

No new external dependency/runtime: reuse existing AGP/SDK/Java versions and
Python standard library. The isolated package has no permissions, sensors,
camera/microphone/network, service, receiver, account, score or Guardian access.
Private marker journals/anchor mappings remain local; commit only generated tests
and aggregate results. No migration, model experiment or M7 completion follows.

All 11 focused Python / 29 pilot+archive-intake tests pass, alongside Java journal
invariants, independent Python reading, build/lint and packaged permission/runtime
checks. Pixel_10/API37 software smoke verifies explicit stop, pause, no restart,
prior-journal preservation and byte-identical local export, including the final
local-only picker build. A transient system-process dialog was handled with Wait;
no reset or attribution to the pilot is claimed. Physical phones and the main app
were untouched. Private journals/mappings remain ignored; aggregate source pins
and evidence are `docs/reference/sync-pilot-v1-result.json`. All four source CI
jobs 44077691270 pass for `52bd0ea`, including new pilot cross-language/build/lint/
packaged checks and full app/native/debug/release regressions. Existing generated
CI model experiments rerun; no real-source candidate is trained. The evidence-only
closure preserves every pinned source blob and adds explicit outward rounding of
reference PTS bounds. Persist/verify the final evidence without rerunning unchanged
runtime suites or describing physical timing/model acceptance as achieved.

## Tecno parked software pilot — 2026-11-17

The maintainer connected/authorized the Tecno and approved the parked pilot after
clarifying that any camera is external test equipment, not a Traelyx feature.
The Tecno's Z bias does not qualify its IMU, but the separate marker app reads no
sensors. Use only the reviewed permission-free APK and explicitly selected device.
Do not start a trip, update/force-stop the main app, read old telemetry/accounts,
change settings or operate the emulator. Keep private identifiers and journals
ignored/local. External optical/capture and recorder-binding evidence remain a
separate dependency; do not synthesize camera observations from draw timestamps.

- [x] Verify physical model/API, main recorder idle evidence and reviewed APK hash;
  preserve existing pilot state and install only the separate package if needed.
- [x] Check visible markers, explicit stop, pause/reopen preservation and private
  local export against retained source bytes on the Tecno.
- [x] Run the strict journal/diagnostic reader without manufacturing independent
  reference observations, and record measured limits plus remaining resources.
- [x] Validate aggregate evidence/references, update status, inspect exact diff,
  commit/push and verify without claiming optical/model/IMU acceptance.

This unit adds device evidence only. Rerun runtime/build suites only if a product
defect requires code changes; retain the earlier fully passing source CI.

The physical two-run cancel/export check exposed a selection reset in the isolated
pilot: inactive `onPause` refreshed the selector to the last captured run rather
than retaining the selected export. No source was overwritten or exported under
the wrong expectation; the filename guard stopped the test. Move history refresh
to the active-run finalization branch, retain inactive selection, and rerun the
two-run cancellation regression plus affected build/lint/host/full-source CI.

API34 device capture and pinned journal reading pass. Repaired v1.0.1 passes the
actual two-run picker cancel/retry and byte comparison. A separate platform-only
instrumentation APK invokes real pause/resume with a nondefault selection; it
passes on the Tecno and removes its unsupported synthetic fixtures, retaining
existing journals. CI now builds that test APK; no new JUnit/Robolectric/library
dependency or main-app instrumentation is introduced. All 29 affected host tests,
build/lint and packaged boundary pass. The original completed journal survives
the data-preserving pilot update unchanged. All four source CI jobs 44085930694
pass for repair `68d91d6`, including full app/native/debug/release checks and
pilot/test APK build/lint. The instrumentation regression ran on the Tecno;
CI compiles/lints its APK without executing a device test.

No external reference was supplied and no optical fit was attempted. ADB screen
inspection proves software behavior only. Main recorder service was absent at
pre/post snapshots; no trip, camera/mic/sensor, old archive/account or emulator
operation occurred. The aggregate evidence closure preserves all pinned source
blobs and records the verified source CI. No unchanged runtime suite is rerun
for this documentation-only closure. M7.4/M7.5 remain open and M8 stays inactive.
