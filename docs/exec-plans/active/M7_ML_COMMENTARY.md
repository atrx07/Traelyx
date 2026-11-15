# Execution Plan — M7 ML & Advanced Commentary

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M7
**Current gate:** M7.9 post-drive corrections authorized; prior acceptance carried forward
**Started:** 2026-11-11
**Last updated:** 2026-11-15

## Context budget / references

Read `ml/AGENTS.md`, roadmap M7.1, dataset governance, ML split/provenance
requirements, the dataset registry schema, and affected tooling/tests only.

## Goal / user-visible result

Current authorized work: M7.9, explicitly continued after M7.8. Deliver local
post-drive event notes and separately consented, reviewed label-only export with
quarantined import. Preserve original event/score evidence and all prior acceptance.
The appended boundaries supersede earlier scope. Stop before M7.10.

M7.1 delivers a reproducible, local-only dataset registry and import command
for reviewed public data and a generated project fixture corpus. No model is
trained or promoted by this substep.

## Authorization / sequencing exception

On 2026-11-11 the maintainer explicitly authorized proceeding with M7.1 while
M6.8 acceptance remains incomplete. This changes development order, not its
acceptance criteria. M6.1–M6.7 remain complete. M6.8 physical active-driver
ingestion/cancellation, process/network recovery, performance and mounted/
vehicle/OEM gates remain open, with vehicle work maintainer-deferred. Its plan
stays active as an outstanding acceptance record; no new live operation is
authorized here. M7 is the current development milestone. Stop after M7.1 and
wait for explicit authorization before M7.2.

## In scope

- Versioned registry entries: license/attribution, source hashes, provenance,
  channels/units/rates, population, label confidence, privacy and limitations.
- Explicit local source import, bounded parsing, integrity verification,
  deterministic output manifests and refusal to overwrite existing results.
- A public licensed source and synthetic, location-free project fixtures.
- Preserve grouping before future windowing; block training eligibility when
  identity, timing, units or label evidence is insufficient.

## Out of scope

Training/windowing, model dependencies, app/recorder/scoring changes, private
trip imports, user contributions, cloud uploads and Guardian operations.

## Preconditions / affected components

Python standard library tooling, `ml/`, registry reference schema, tooling
tests, CI, and roadmap/status documents. Public license/source must be reviewed
before registering or importing data. No new dependency is planned.

## Data/privacy/security and compatibility

Downloaded data and derived imports stay in ignored `ml/data/private/`.
Only metadata and generated non-personal fixtures enter Git. No routes or
private recordings are read. Existing schemas/results and mobile behavior are
unchanged. Dataset/import versions and source/output hashes preserve replay.

## Implementation steps

- [x] Review public source and existing project corpus; record limitations.
- [x] Implement registry validation and deterministic fail-closed import.
- [x] Add governed synthetic fixture and hostile-input/reproducibility tests.
- [x] Run local gates and an actual checksum-verified public import.
- [x] Synchronize documents, inspect diff, commit/push, verify CI and Git sync.

## Tests / validation

- Registry/schema contract checks, Python compilation and unit/integration tests.
- Reimport byte equality; hash, malformed row, non-finite value, privacy-column,
  group leakage, output collision and input/output boundary rejection.
- Offline committed-fixture validation in CI; network-free normal test suite.
- Actual local public import against publisher SHA-256, with raw data ignored.
- Repository contracts/secrets and whitespace checks; full existing CI.
- No device/build-runtime or battery claims; mobile gates run through CI.

## Acceptance criteria

Both public data and generated project fixtures import reproducibly with license,
source and output hashes, source-label provenance and explicit quality limits.
No driver-held-out eligibility is fabricated from anonymous concatenated rows.
Unsafe/malformed input cannot publish a successful import. CI covers the new
tooling without network data dependencies. M6.8 is not marked complete.

## Risks / decisions

The reviewed public source has three drivers but no row-level driver/trip/time
fields. Acceleration magnitudes also warrant unit verification despite the
publisher's declared SI units. Preserve source values and block training use;
do not infer driver boundaries, timestamps, converted units or crash labels.

## Progress log

- 2026-11-11: M7.1 authorized with M6.8 acceptance explicitly carried forward.
  Reviewed Mendeley DOI `10.17632/jj3tw8kj6h.2` and publisher CC BY 4.0 notice;
  downloaded both small source files into ignored local storage and verified
  their publisher SHA-256 values. No personal telemetry accessed.
- Local checks: 22 dataset tests and 3 existing inspector tests pass with no
  failures/errors/skips and resource warnings treated as errors. Python
  compilation and registry validation pass. Actual imports produce 558 synthetic
  samples and 1,114 public rows (class counts 252/288/350/224); an independent
  public reimport is byte-identical. Raw source/summary and outputs are ignored.
  Repository contracts/secrets and whitespace checks pass.
- ADR-0034 records local import/quarantine decisions. The M3 native corpus stays
  authoritative and unchanged; the ML smoke corpus is separate synthetic data.
- Final boundary review added oversized-integer metadata cases: range rejection
  must not convert an arbitrary integer to float or expose a traceback. All
  25 Python checks and registry validation still pass. No valid import changes.

- Final source `460539f9a9872972e63a0d7531045a24fbbad956` passes full
  [CI 42970700095](https://github.com/atrx07/Traelyx/actions/runs/42970700095),
  all three jobs: Flutter/native tests, offline dataset checks, debug/release-
  validation APKs, cloud SQL/RLS, Edge and artifact gates. No gate was waived.
  Implementation and numeric-boundary follow-up are pushed on `origin/main`;
  final closure synchronizes this plan, STATUS, NEXTSTEPS and README.

## Completion summary

**M7.1 complete (2026-11-11).** Two governed registry entries and an operational
local importer preserve licensed source evidence and deterministic audit outputs.
Twenty-five Python tests, actual public import/reimport, repository checks and
full exact-source CI pass. No dependency/provider, app/schema migration, sampling,
scoring, private-data upload or device operation. Registry schema v1 replaces an
unused draft; no existing registry instances or historical results are migrated.
Public data remains training-blocked; synthetic data is plumbing evidence only.
M6.8 physical/vehicle acceptance remains open/deferred. M7 stays active as a
milestone plan, with M7.2 pending explicit maintainer authorization; no M7.2 work
was started. Real-device/battery behavior is unchanged and not newly validated.

## M7.2 boundary — authorized 2026-11-11

The maintainer's explicit continuation authorizes only M7.2. M6.8 acceptance
remains open under the existing sequencing exception. Stop before M7.3.

### Scope and data decision

Review found publisher version 3 of the existing Mendeley source has explicit
driver/class/task fields: 1,114 rows, three drivers, 109 contiguous labeled
tasks. Version 2 remains unchanged and training-blocked. Version 3's units,
axis frame, exact sampling and annotation quality remain unverified. A new
registry contract may permit **source-space experiment only**, never production
training eligibility. Preserve numerics, strip source wall-clock columns, retain
coarse relative time and anonymous grouping, and do not interpolate/infer times.

Use one predeclared split (driver 1 train, driver 2 validation, driver 3 locked
test), fixed seven-row trailing task windows, train-only normalization, and
validation-only checkpoint selection. These sample-index windows are not claimed
to be the proposed production 5–8 second aligned vehicle-frame features. Output
classes are the publisher's four maneuver labels; no normal, impact, phone-move
or crash evidence exists. Report unsupported metrics as unavailable.

### Implementation / acceptance checklist

- [x] Freeze the experimental feature/data contract and dependency evaluation.
- [x] Add a separately versioned source-v3 registry/import without changing v1
  registry entries, synthetic corpus or previous imports.
- [x] Implement CPU PyTorch causal TCN, deterministic training/checkpointing,
  manifest/model hashes, train-only normalization and sealed test evaluation.
- [x] Report per-class precision/recall/F1, macro F1, confusion, uncalibrated
  probability metrics and a majority baseline, with provenance/limits.
- [x] Validate leakage, causality, serialization, training behavior, integrity
  and reproducibility in offline synthetic tests; run the actual public baseline.
- [x] Run affected local gates and full CI; persist completion atomically,
  verify Git alignment and stop before M7.3.

### Out of scope / risks

No private/contributed data, unsafe collection, app/model runtime dependency,
on-device export, calibration/promotion, scoring/Guardian change or upload.
PyTorch is an isolated optional development dependency; core imports remain
standard-library-only. The tiny shared-route/device population and missing
negative/severe classes prohibit safety/generalization claims. If this source
cannot support the declared experiment, retain M7.2 as incomplete rather than
fabricating held-out evidence. Historical M7.1 restrictions above remain its
completion record; this section records the new authorization.

### M7.2 local evidence

Forty-one Python tests pass (16 new EventNet tests plus 25 registry/inspector checks).
The source-v3 public import verifies publisher SHA-256 and produces 109 grouped
tasks. A provisional, explicitly dirty-source run selected epoch 60 and reports
macro F1 0.5378 versus majority 0.0851; Brier 0.8891 versus prior 0.7614 and NLL
2.5048 versus prior 1.4090. The probability regression prevents promotion; no
configuration was changed after seeing held-out results. A final clean-commit
run/repeat, compatibility checks and exact-source CI remain pending. CPU wheel
and complete transitive requirement hashes reinstall successfully in an ignored
local virtual environment; v1 import tooling remains standard-library-only.

- 2026-11-14: resumed after the usage-limit interruption. The outstanding test
  process completed successfully: 41 tests, no failures/errors/skips; pip check
  passes. Remote main still equals the M7.1 closure commit. Version-2 public
  reimport remains byte-identical to its historical samples and manifest. No
  training configuration changed after the provisional held-out evaluation.
- Clean-source commit `e858ebf` now has two byte-identical actual baseline
  checkpoints/reports, with dirty-source false. Macro F1/Brier/NLL match the
  provisional result exactly. Aggregate evidence is retained in
  `docs/reference/eventnet-baseline-v1-result.json`; raw data, weights and
  task predictions stay ignored. Full source CI 43604983837 passes all four
  jobs, including Linux CPU, cloud/Edge, Flutter/native tests, debug/release
  builds and artifact gates. No acceptance gate was waived.

### M7.2 completion summary — 2026-11-14

M7.2 is complete as the explicitly bounded source-space experiment. Source
`e858ebf22dca4e7d0dcd5f1c4129063d265ef83b` passes full
[CI 43604983837](https://github.com/atrx07/Traelyx/actions/runs/43604983837),
all four jobs. All 41 local Python tests, compilation, pip consistency,
repository/whitespace gates, source-v2 byte compatibility and actual frozen
clean-source experiment/repeat pass. Model and report bytes match exactly.

Held-out macro F1 improves over majority, but Brier/NLL regress versus prior;
probabilities remain uncalibrated and production eligibility false. The aggregate
result preserves hashes, metrics, supports, split, runtime/config and limits;
raw data/weights/task predictions stay ignored. PyTorch/transitive dependencies
are optional development-only and hash-pinned; the app gains no dependency,
migration, sensor/scoring/Guardian behavior, upload or on-device model. Registry
v2 is additive; historical v1 entries/results and M3 fixtures remain unchanged.
Real-device latency/battery and physical/vehicle acceptance are not validated.
The completion commit synchronizes this plan, STATUS, NEXTSTEPS, README and
aggregate evidence. Stop before M7.3 pending explicit maintainer authorization;
M6.8 acceptance remains open/deferred.

## M7.3 boundary — authorized 2026-11-14

The maintainer explicitly continued after M7.2 and the device-requirements
discussion. Only M7.3 is authorized; stop before M7.4. No phone/emulator,
new dependency, dataset collection, app integration or live operation is needed.

### Frozen calibration / analysis protocol

Preserve M7.2 weights, data/import hashes, split, normalization, source labels
and historical report. Add versioned, validation-only scalar temperature scaling
(Guo et al., PMLR 2017). Fit validation NLL over positive temperature [0.1, 100]
using 80 deterministic golden-section iterations in inverse temperature, with
identity and endpoints included; ties prefer identity. No other calibrator,
range, bin count or model is selected against test results.

Compute before/after per-class metrics, confusion, Brier, stable-logit NLL,
10-bin top-label/classwise reliability/ECE, and source-label error counts.
Temperature scaling must preserve class decisions. Validation data were already
used for checkpoint selection and the held-out driver was already reported in
M7.2: disclose this reuse; the audit is not fresh blinded validation. Sparse
bins, only 35 validation/39 test tasks and unresolved source semantics cap all
interpretation. Never infer causal driving errors from model/source disagreement.

False severe events/hour, severe PR-AUC and timed detection remain unavailable:
this four-label source experiment has no normal/severe truth or production
severe-event mapping. Report reasons, not zero rates. Engineering completion
of this bounded calibration audit is not production safety/ML acceptance; those
evidence requirements remain blocked and no promotion follows automatically.

### M7.3 acceptance checklist

- [x] Implement frozen, bounded calibration and reproducible data-only artifacts.
- [x] Test validation-only fitting, stable numerics, argmax preservation, exact
  reliability bins, invalid input/provenance rejection and repeatability.
- [x] Run the frozen audit against the preserved checkpoint; retain both gains
  and regressions plus class-error/support limitations in aggregate evidence.
- [x] Run local gates/full source CI; synchronize status/README/plan, commit,
  push and verify main alignment. Stop before M7.4 pending explicit approval.

### M7.3 local gates

All 53 Python tests pass (12 calibration, 16 EventNet, 22 registry, 3 inspector),
with no failures/errors/skips and ResourceWarnings treated as errors. Frozen
checkpoint/source hashes match before any actual audit outcome evaluation.
No method/range/bin count was selected using this audit's test results. Raw
weights and prior records are unchanged; final clean-source run/repeat and CI
are still required before completion.

- Frozen source `5e8d2ff` produced two clean, byte-identical real audit reports
  and calibrators. Validation-only T=1.1457625347025238 preserves original model/
  normalization and all decisions. Test NLL 2.504756→2.216558 and Brier
  0.889123→0.868231 improve; top-label ECE 0.415610→0.416560 worsens, as does
  source-braking classwise ECE. Macro F1 stays 0.537838. Probability scores still
  trail the frozen class-prior baseline. Retain these regressions and the 19/39
  source-label disagreements; causal attribution and severe rates remain unknown.
  Aggregate evidence is `docs/reference/eventnet-calibration-v1-result.json`.
  Full exact-source CI 43607386501 passes all four jobs, including CPU/Linux,
  cloud/Edge, Flutter/native tests and debug/release builds. No gate was waived.

### M7.3 completion summary — 2026-11-14

M7.3's explicitly bounded retrospective experimental audit is complete. Source
`5e8d2ff19824ab1aa045186ce7f77cb4e158c97e` passes full
[CI 43607386501](https://github.com/atrx07/Traelyx/actions/runs/43607386501),
all four jobs. All 53 local Python tests, compilation, dependency/repository/
whitespace checks, preserved source/model/data verification and byte-identical
actual calibrator/report repeat pass. The original model and all historical
M7.1–M7.2 records remain unchanged. No new dependency, app/schema migration,
sampling/scoring/safety-state change, device operation or private-data upload.

T=1.1457625347025238 improves retrospective test NLL/Brier but worsens top-label
ECE and source-braking classwise ECE; class predictions/F1 are unchanged. Frozen
prior scores remain better. Per-class source-label disagreements, uncertainty,
reuse and sparse-bin limits are preserved in aggregate evidence; raw/private
artifacts stay ignored. False severe events/hour and production safety acceptance
remain blocked on normal/severe evidence and an appropriate event mapping. No
unavailable metric became zero and neither model nor scalar is promoted.

The completion commit synchronizes plan, STATUS, NEXTSTEPS, README and evidence.
Stop before M7.4 pending explicit authorization. M6.8 physical/vehicle acceptance
remains open/deferred; no real-device performance or battery claim was validated.

## M7.4 boundary — authorized 2026-11-14

The maintainer explicitly continued M7.4. Only mobile export/inference and its
isolated benchmark are authorized; stop before M7.5. Preserve all historical
weights/calibrator/data/split/results and keep production eligibility false.

### Scope / dependency choice / privacy

Evaluate ONNX/ONNX Runtime as a replaceable experimental runtime, not a new app
dependency. The reviewed ExecuTorch 1.6 export wheel requires broader tooling
(including pandas/torchao and platform-conditioned CoreML/sklearn); ONNX Runtime
1.32 has verified Windows CPython 3.14 tooling and an Android AAR. Record this
bounded choice in an ADR and dependency evaluation; no production-runtime
selection follows. ONNX/ORT/NumPy and transitive development wheels must be pinned.

The official ORT Android AAR contains default telemetry provider/network
permissions. Before loading ORT, set `ORT_DISABLE_TELEMETRY=1` on host/device,
remove the provider and network permissions from the benchmark manifest, and
disable environment telemetry explicitly. Verify the merged/packaged manifest
and permissions before any install; abort on failed privacy checks. Never load
arbitrary downloaded models. Verify generated artifact/runtime hashes.

Use a separate, permission-free `io.github.atrx07.traelyx.mlbenchmark` APK,
with no Flutter/core-app dependency, Auth/Guardian/recorder access, sensors,
network changes, driving or UI interaction. An authorized physical TECNO LH8n
is available (Android API 34, arm64). Install only the verified standalone APK,
run bounded generated-input instrumentation, save aggregate results and remove
only that task-owned package afterward. Do not update/reinstall the core app or
read its private recordings/accounts. Device identifiers stay ignored locally.

### Frozen export / numerical gates

- Export fixed batch-1 `[1,6,7]` raw-source inputs, embedding preserved train
  normalization, with four raw logits and the separately versioned experimental
  temperature postprocessing. No new feature/scoring/event mapping.
- Float32 ONNX versus frozen PyTorch: max absolute logit error <=1e-4.
- One predeclared static S8S8, per-channel QDQ export, MinMax ranges fitted only
  from the 35 training task windows. Never use validation/test for quantization
  ranges or tune the quantization configuration after their results.
- Report quantized drift for every partition. Gate maximum source-class
  probability error <=0.05 and test macro F1 loss <=0.02 against the frozen
  float model. Retain any failure as a rejected artifact, not a passing model;
  do not try alternatives against the test to manufacture a pass.
- On-device parity uses generated inputs only: raw logit drift versus the
  same host runtime/artifact <=1e-3 and probability drift <=1e-4. Quantization
  and runtime evaluation do not authorize production model promotion.

### Benchmark / acceptance checklist

- [x] Pin/evaluate optional export/runtime dependencies and document ADR.
- [x] Implement deterministic bounded export, training-only quantization,
  source/data/model/runtime hashes and numerical comparisons; test failures.
- [x] Build/test isolated Android harness; verify package, manifest, permissions
  and telemetry defenses, with generated inputs only.
- [x] Measure cold session/first inference, warm distribution, thread/process
  CPU, memory and runtime/APK/model sizes on the physical phone. Record test
  conditions, charging/temperature and uncertainty. Short USB-connected tests
  do not establish battery drain/hour; keep that gate explicitly unverified.
- [x] Verify native outputs against host references, retain aggregate evidence,
  remove the task-owned harness, preserve the core app and verify cleanup.
- [x] Run local/CI gates, synchronize documents, commit/push, verify Git alignment
  and stop before M7.5 pending explicit authorization.

### Source validation

Implementation source `3e04ebe` passes 63 local Python tests, native numeric
helpers, compilation/dependency/repository checks, standalone APK build/lint and
packaged privacy verification. Two clean-source runs are byte-identical for both
graphs, generated fixtures and export report. Three physical generated-input
runs pass native parity; the task-owned package is removed and both installed
core APK hashes are unchanged. No core private app files were read or mutated.

Source CI 43611283110 and 43611645609 pass Linux export tests/helpers but expose
two new-job setup assumptions: `sdkmanager` is not on the runner PATH, and an
ML-only fresh checkout has no Flutter-generated Gradle wrapper. Use the existing
SDK's explicit command-line-tools path and run the same checksum-verified Gradle
9.1 distribution directly; do not alter SDK/dependency versions or weaken hashes.
Numerical int8 rejection remains 0.0509469 >0.05, with
unchanged macro F1. Corrected source `140e671` preserves export/harness source
text and passes full CI 43611844686: all four jobs, Linux generated
export/standalone APK build/lint/privacy, Flutter/native tests, debug/release,
cloud/Edge and artifact gates. M7.4 numerical acceptance is not complete and
M7.5 is not authorized.

### M7.4 measured outcome / open acceptance

Aggregate-only evidence: `docs/reference/eventnet-mobile-v1-result.json`.
No model binaries, task windows, private telemetry or device identifiers enter
Git. Preserved baseline/calibrator evidence and data hashes identify inputs;
model/fixture/report hashes and source files identify outputs. Both clean runs
are byte-identical. Executed local source bytes and CI Git-blob hashes are both
recorded; only `requirements-mobile.txt` has CRLF versus Git's LF, with identical
dependency text/hashes. No weights, source partitions, normalization, calibration,
thresholds or quantization settings were altered after evaluating held-out data.

- FP32 host maximum logit error 5.7220458984375e-6 passes <=1e-4.
- Training/validation/test int8 max probability drift is respectively
  0.00117648 / 0.02885900 / 0.05094693. Test exceeds <=0.05: rejected.
  Test F1 stays 0.537838; Brier 0.868231→0.871556 and NLL
  2.216558→2.219991 regress slightly. Severe/normal truth remains unavailable.
- Graphs: float 20,013 bytes, int8 22,927 bytes. Tiny-model QDQ metadata exceeds
  weight savings. Official AAR is 59,335,382 bytes; standalone arm64 debug APK
  is 37,371,185 bytes, with 36,399,584 uncompressed packaged native-library bytes.
  This substantial optional-runtime overhead is not added to the core app.
- Three fresh processes on TECNO LH8n, API34/arm64, USB charging at battery49%,
  35–36 C reported battery temperature. All eight generated cases/variant/run
  pass native parity. Float max logit/probability errors are 1.91e-6/1.59e-8;
  int8 matches its host reference exactly. Runtime init is 64.9–162.5 ms;
  cold float/int8 sessions 16.2–19.2 / 7.9–13.4 ms, first inference
  1.79–3.30 / 0.69–1.02 ms. Ordered within-process measurements have cache/JIT effects.
- Warm medians float/int8 0.082–0.144 / 0.106–0.127 ms; p95
  0.170–0.696 / 0.133–0.206 ms. Process busy-loop CPU is 116.5–126.7% /
  98.7–101.0% of one core, including JIT/GC. Session PSS snapshots are
  63,428–65,489 / 71,982–74,089 KiB, not peak memory. No consistent speed win,
  no production sampling-load, sustained battery or recorder reliability claim.
- Exact packaged manifest/assets verified before install: zero permissions,
  zero providers, preinit telemetry disable, no app components except own
  instrumentation. Only generated inputs reached the phone. The task-owned
  package was removed; both core APK hashes are unchanged. Core private app
  files/accounts/recordings/settings were neither read nor mutated. No migration,
  new core dependency, cloud operation or upload occurred.

- [ ] Quantized probability gate passes. **Failed**; keep the rejected artifact
  and all original thresholds. M7.4 numerical acceptance remains blocked.
- [x] Corrected full source CI and final evidence/status persistence verified.

Any follow-up model/export experiment requires an explicitly scoped, versioned
protocol and suitable unseen evaluation evidence. No alternate configurations,
test-guided tuning or gate waiver is authorized. Stop before M7.5; deferred
M6.8 physical/vehicle/OEM and production safety/battery gates remain open.

## M7.5 foundation boundary — authorized 2026-11-14

The maintainer accepted continued M7 development while tackling model acceptance
later. This authorizes provider boundaries, local audit provenance and explicit
rules-only fallback, not loading/promoting the rejected model, waiving M7.4,
or proceeding continuously through later substeps. M7.5 full hybrid model
integration stays pending model/feature acceptance. Stop after this bounded
foundation; M7.6 needs separate authorization.

### Scope / invariants

- Add a versioned pure native evidence boundary. Production has no ML-enabled
  mode, model asset/runtime/provider, feature extraction, or per-frame overhead.
- Add one explicit disabled/model-acceptance-deferred record to newly requested
  local analyses. Existing audit JSON retains it; no DB migration or historical
  recomputation. Event IDs, confidence, severity, merge/scoring versions and
  results stay unchanged. No Guardian, recorder, acquisition or UI changes.
- Separately exercise a generated-fixture-only provider interface with bounded
  finite features/probabilities, immutable metadata, input digest/time/schema
  binding, quality gates, lazy provider creation, attempt budget, sanitized
  failures and cancellation propagation. Never map source classes to governed
  events or use predictions to alter events/scores/confidence/safety.
- Audit generated probabilities alongside original rule identity/evidence,
  quality and model/calibrator hashes. No raw features/routes/exception strings
  in audit records. Generated harness is not connected to the app's analysis.
- No new dependency, network/data upload, provider service, phone operation,
  battery/sampling/lifecycle change or production-performance claim.

### Acceptance / validation

- [x] Document contract/ADR and preserve deferred acceptance checklist below.
- [x] Implement boundary, generated-only evaluation and production status audit.
- [x] Verify rejection/disabled paths never construct provider/features, malformed
  or mismatched inputs/outputs fail closed, budgets/cancellation hold and audit
  metadata cannot mutate after creation.
- [x] Replay governed corpus: original event evidence and scoring are identical
  across disabled, opposite generated predictions and provider failure paths.
- [x] Validate additive local audit persistence/legacy compatibility and absence
  from compact public summary fields; no migration or historical rewrite.
- [x] Native/Flutter targeted checks, full relevant suites, analysis, repository
  validation, app builds and full CI; atomic persistence and Git alignment.

### Deferred model acceptance — must revisit before enabling ML

- [ ] New explicitly scoped/versioned experiment with suitable unseen held-out
  evidence; preserve rejected int8 artifact, old splits/results and thresholds.
- [ ] Verified production feature units/frame/timing and governed label mapping.
- [ ] Representative normal/severe truth, per-class/calibration/error evaluation
  and false severe events/hour; unavailable metrics must never become zero.
- [ ] IntegrityNet: compare strengthened deterministic consistency alternatives
  and suitable unseen legitimate/inconsistent data; generated signal alone does
  not establish model value, calibrated probability or field false-positive rate.
- [ ] Accepted numerical export, runtime/size efficiency, sustained battery/CPU,
  physical/vehicle/device validation, explicit promotion and rollback plan.
- [ ] Finish M7.5 real-model corroboration only after those gates pass.

M6.8 remains separately open/deferred. This checklist is durable repository
memory for the maintainer's instruction to tackle model acceptance later.

### Foundation validation / bounded closure

All 501 app-native tests plus dependency suites pass, including nine new
generated-boundary tests and the ten-scenario governed corpus comparison.
All 19 targeted local-analysis/ranking Flutter tests, full Flutter analysis,
formatting, repository checks, debug APK and app lint pass. The known Windows
local.properties escaping/stale-lint issue was handled with temporary normalized
paths, forced app-lint analysis/report, and verified byte-for-byte restoration.
No production device or model operation occurred. Source `3046201` passes full
CI 43615278473: all four jobs, full Flutter/native tests, generated ML/standalone
APK checks, debug/release builds, cloud/Edge and artifact gates. Aggregate-only
evidence is `docs/reference/hybrid-event-evidence-v1-result.json`.

The authorized foundation is validated and persisted with synchronized status
documents. This closes only that bounded work: M7.4/model acceptance and full
M7.5 model corroboration remain open, with their checklist retained above.
No runtime/model, dependency, migration, scoring/safety/recorder change, phone
operation or upload was introduced. Stop before M7.6 pending explicit scope and
authorization; do not prepare it while waiting.

## M7.6 boundary — authorized 2026-11-14

The maintainer explicitly continued M7.6. Only a CPU IntegrityNet experiment and
comparison against unchanged deterministic integrity rules are authorized. No
production promotion, ranking/integrity/Guardian/scoring changes, device work,
new public download, private recording use or new dependency. Stop before M7.7.
M7.4 acceptance, M7.5 real-model integration and M6.8 gates remain open.

### Frozen experiment (before observing results)

- Public maneuver labels do not establish integrity ground truth. Use a new
  generated-only experiment manifest (separate from frozen M7.1 registry/imports)
  and native test exporter built on the existing governed M3 corpus. Export
  aggregate features and actual `IntegrityPipeline` results only, never positions,
  raw samples, trip/device/account identity or wall clocks.
- Nine fictional profiles: train 1/3/5/7/9, validation 2/8, test 4/6. Assign
  groups before generating cases/aggregating; shared scenario templates mean
  these are plumbing splits, not independent real-driver generalization.
- Forty training cases: eight coherent corpus scenarios per training profile.
  Each held-out profile has those eight plus three numeric injections, one
  platform signal, two quality scenarios and two decoder-corruption cases.
  Total 104 cases (40/32/32). Ground truth is injection provenance, not rule
  output. Keep clean, numeric inconsistency, platform, quality and corruption
  categories distinct. Decoder rejection abstains from learned inference.
- Eight whole-trip raw-signal summary statistics: GNSS source speed mean/max/std,
  acceleration norm mean/std and gyro norm mean/max/std, in explicit generated
  SI units. No baseline finding/label/profile ID enters the model. This loses
  timing/direction/local structure and is not a production feature contract.
- One 98-parameter autoencoder: 8→4→2→4→8, ReLU hidden, linear output. CPU
  PyTorch 2.15.0+cpu from the existing hash-pinned lock, one thread, seed 7606,
  Adam lr0.01, 200 epochs, all training-clean cases, train-only mean/std with
  1e-6 floor. No hyperparameter search, early stopping or test-driven retries.
- Freeze threshold at validation-clean reconstruction-MSE nearest-rank 97.5th
  percentile plus 1e-12. Validation anomalies never fit anything. Evaluate test
  once thereafter; fixed sensitivity multipliers 0.5/1/2 are diagnostics only.
- Compare synthetic clean false-flag rate and numeric-injection recall against
  native `INCONSISTENCY` findings. Report each family, coverage/abstentions and
  platform/quality/corruption slices separately. Generated added-value requires
  no clean-FPR or numeric-recall regression and a strict improvement in one;
  never implies production eligibility. Real legitimate-drive FPR remains null.
- Preserve source/fixture/model hashes, config/threshold/provenance, safe JSON
  checkpoints and byte-identical within-platform repeats. No pickle, old artifact
  overwrite, unit/label reinterpretation, malicious-intent or safety claim.

### Acceptance / checks

- [x] Freeze versioned contract/manifest and native generated baseline exporter.
- [x] Implement bounded loader, training-only fitting, validation-clean threshold,
  comparator/slices, safe checkpoint and audit/provenance; test leakage/failures.
- [x] Run native generated-fixture regression/export and CPU generated comparison;
  preserve all outcomes and clean-source repeats without searching configurations.
- [x] CI exercises generated native export→CPU experiment on the same fixture;
  retain existing full native/Flutter/build/cloud/ML gates.
- [x] Record aggregate results/limitations and model decision, synchronize status,
  commit/push/verify Git and stop before M7.7.

### Local implementation validation

All 74 Python tests (including 11 new IntegrityNet tests), compilation,
dependency/repository checks, all 502 app-native tests plus dependency suites and
debug build pass. Native export is repeatable at 104 cases (40/32/32), 24,913
bytes in this host environment. No model result from the native fixture has yet
been inspected. Commit the frozen source before its comparison and repeats.
No new package or production app behavior, private data or device operation.

### M7.6 generated outcome / bounded closure — 2026-11-15

Source `4e0fe9a` produces identical native CSV bytes (SHA-256
`ae0489d3c276d49653b2bea86947e722dc4306447fd61a667c78beaea7cfa205`)
and two byte-identical clean-source checkpoint/report runs. The checkpoint is
4,732-byte JSON with 98 parameters (SHA-256
`d3b57208444989057838fabad33c6c6598348235babc3b24d42d9d9f6ca7e636`).
No fitting/configuration/gate/threshold changed after test results were seen.

Frozen validation-clean threshold 3.49100923538308 yields 0/16 clean test flags
for both model/native baseline and 6/6 numeric-injection detections vs native
4/6. The extra signal is two acceleration/speed mismatch injections; native
gyro/source-speed findings are preserved. Quality cases receive no model flags;
native limited-confidence findings remain distinct. The model flags 0/2 explicit
mock signals, which native platform findings still identify, and abstains on
all four raw-corruption cases, which native decoding marks unranked. Diagnostic
0.5× threshold flags 2/16 clean cases; 1×/2× flag zero and detect 6/6. No diagnostic
was used to change the threshold or select another model.

This is generated added signal against existing rules v1 only. Clean families
were already-governed fixtures expected to be verified; shared templates and
fictional profile holdout do not establish field FPR or real driver/device
generalization. Strengthened deterministic alternatives were not evaluated and
may offer the same signal; that comparison is retained in deferred acceptance.
Real legitimate-drive FPR, calibrated anomaly probability, mobile latency and
battery metrics remain null/unavailable. Production eligibility/inference stays
false, and no integrity/rank/scoring/Guardian state consumes these outputs.

All 74 Python tests, 502 app-native tests plus dependency suites, compile/pip/
repository checks and debug build pass locally. Full source CI 43689186048
passes all four jobs, including Linux generated native→CPU fit/replay and
byte-identical repeats, full Flutter/native tests, both APK builds, cloud/Edge
and artifact checks. Linux reaches the same qualitative decision; numeric/
artifact byte identity across platforms is not claimed. Aggregate-only evidence
is `docs/reference/integritynet-generated-v1-result.json`; data/checkpoints stay
ignored. No new dependency, app/runtime change, migration, private recording,
phone or production operation. The M7.6 experiment is complete, with all prior
acceptance/physical gates carried forward. Stop before M7.7 pending authorization.

## M7.7 boundary — authorized 2026-11-15

The maintainer explicitly continued M7.7. Only a bounded CPU ContextNet value
experiment is authorized. No model promotion, narrator/event/scoring/integrity/
Guardian change, new dependency, private-data use, public download or device
operation. Stop before M7.8. All prior acceptance gates remain open.

### Frozen comparison (before observing model results)

- Existing procedural commentary uses deterministic event repetition/cooldown;
  it is not a five-state context classifier. Compare against a separately
  versioned experimental temporal-rule baseline, not a fabricated production
  classifier. Do not modify narration, source thresholds or historical results.
- Original analytical generated sequences at 1 Hz cover 30/60/120 seconds.
  Do not tile/stretch M3's 12-second corpus or claim recorded/field evidence.
  Four vehicle-frame generated channels: speed m/s, longitudinal acceleration
  m/s², lateral acceleration m/s² and longitudinal jerk m/s³. One analytical
  midpoint sample per one-second bin; explicit relative times/support/missingness.
- Five *fixture* programs: steady cruise, stop/go, high lateral load, repeated
  abrupt transitions and smoothly varying speed. Labels come from generation
  programs, not rule/model predictions; mutually exclusive programs do not prove
  real context labels are disjoint. Mixed-load/abrupt and stationary diagnostics
  are intentionally outside this closed label set and require abstention.
- Nine fictional groups assigned first: 1/3/5/7/9 train, 2/8 validation, 4/6 test.
  Each group has 5 programs ×3 lengths ×2 variants: 270 labelled cases (150/60/60).
  Held-out groups add 20 quality-unavailable and four open/mixed diagnostics per
  partition: totals 150/84/84 (318). Shared generators are not real-driver holdout.
- Missing spans/unsupported evidence abstain in both methods; no zero-filling,
  interpolation, sample repair, quality-derived label feature or padded training
  statistics. Normalization fits valid training frames only; packed lengths
  exclude batch padding from GRU state. Source IDs/labels/split do not enter features.
- One GRU: input4/hidden8/head5, 381 parameters; CPU PyTorch2.15.0+cpu, one thread,
  seed7707, Adam lr0.01, 80 full-batch epochs, no search/selection/early stopping.
  Mean/population-std fitted on training only, std floor1e-6. Final model only.
- Frozen temporal rules use stopped speed<=0.5 m/s, stop fraction0.15–0.8 plus
  at least one stop/move transition; high lateral-load occupancy>=0.5 at |ay|>=2;
  at least three |jerk|>=3.5 signed episodes (a sign change starts a new episode);
  otherwise moving fraction>=0.85,
  speed span<=1/max|ax|<=0.75 for cruise or span>1/max|ax|<=1 for smooth variation.
  Multiple dynamic matches abstain. These are experiment rules, not production
  context/score definitions. Baseline receives the same sequence/quality as GRU.
- Model's selective prediction uses fixed max-softmax>=0.6; probabilities are
  explicitly uncalibrated. Report argmax/selective per-class precision/recall/F1,
  confusion, coverage, Brier/NLL and missing/open-case abstention diagnostics.
- Validation gate: selective macro F1 >= rules+0.02, no per-class recall or
  labelled coverage regression, no increase in non-abstained open/mixed cases,
  and matching quality abstention. If it fails, reject added-value claim and do
  not compute test predictions/metrics. Test metadata/schema validation is not
  claimed to be physically unseen data. If it passes, evaluate test once with
  the same gate; no calibration/search or retry after either outcome.
- Preserve safe JSON checkpoint, manifests, source/data/model hashes, validation
  result and within-platform byte-identical repeats. A negative result closes
  the experiment with rules retained. Any result stays production-ineligible;
  real context accuracy/calibration, runtime/battery and suitable data stay open.

### Acceptance / checks

- [x] Freeze generated manifest/license, comparison protocol and explicit value gate.
- [x] Implement bounded generation/loading, temporal baseline, packed GRU,
  train-only normalization, optional test opening and safe checkpoint/replay.
- [x] Test time/shape/quality validation, padding invariance, split/leakage controls,
  baseline diagnostics, model reproducibility and failed-gate test non-evaluation.
- [x] Run clean-source experiment/repeats and full CI, retaining every outcome;
  no production change or post-result tuning.
- [x] Persist aggregate evidence/status, commit/push/verify Git and stop before M7.8.

Local implementation gate: all 86 Python tests (including 12 ContextNet tests),
compile, pinned CPU dependency check, repository JSON/YAML/secrets validation and
diff checks pass. No complete ContextNet experiment result has been observed at
the source freeze. At that point full source CI and clean-source repeats remained
required; their completed evidence follows.

### Observed comparison / closure — 2026-11-15

Clean implementation/protocol source `657f6bc4365c3ca01c00bbd0a07aeebd25f4fb7c`
produces two byte-identical local source/checkpoint/report runs. Source generation
SHA-256 is `a02be4088aa2759f2da675e6784c3dbcaabf8bab4aa1a12ed5c2cc3f277c8fd8`;
the 12,493-byte JSON checkpoint hash is
`b615782441e065398818d62f4b137c49b493e0be69a4b2111f28fbfa251f69d7`.
Train-only statistics cover 150 sequences/10,500 valid frames; 381 parameters.

Validation (60 labelled, 20 quality-unavailable, four open cases): temporal-rule
macro F1/coverage are 1.0/1.0; GRU argmax F1 is 0.7829565 and fixed-selective
F1/coverage are 0.6/0.6. All 12 cruise and 12 smooth-variation selective outputs
abstain. The GRU labels all four stationary/mixed cases, while rules abstain;
both abstain on all 20 quality-unavailable cases before GRU invocation. Four of
five value checks fail; quality handling passes. No added value is validated.
Test predictions/metrics remain uncomputed; no model, cutoff or rule was retuned.

Linux CI's downloaded generated-only report confirms the same classification,
abstention and gate decision, with test predictions also unopened and clean
source hashes matching frozen Git blobs. Each platform repeats byte-identically;
cross-platform source/model/report identity is not asserted. This bounded negative
result is not field accuracy or a verdict on every possible context model.
Aggregate evidence is `docs/reference/contextnet-generated-v1-result.json`;
data/checkpoints stay ignored. Full source
[CI 43692438655](https://github.com/atrx07/Traelyx/actions/runs/43692438655)
passes all four jobs, including formatting/analysis, full Flutter/native tests,
generated/schema/privacy checks, debug/release builds, standalone benchmark,
ContextNet repeats and existing native→CPU IntegrityNet comparison. All 86 local
Python tests (12 new ContextNet checks), compile, pinned dependency, repository
validation and diff checks pass. Historical dataset/EventNet/calibration/
IntegrityNet code, licenses and dependency locks remain unchanged.

M7.7 is complete at the explicitly bounded experiment level. No new dependency,
app/runtime/provider, migration, private-data, phone/emulator, narrator or
production operation. Real context labels/overlap/open-set/calibration, accepted
features and runtime/battery/physical evidence remain open alongside all prior
acceptance gates. The deferred follow-up is retained in `NEXTSTEPS.md`. Stop
before M7.8 pending explicit authorization; no next-step work is prepared.

## M7.8 boundary — authorized 2026-11-15

The maintainer explicitly continued M7.8. Implement only a bounded generated CPU
embedding experiment after the deterministic baseline. No production dimensions,
scoring, lifecycle/cohorts, history, narrator, Guardian, provider or device changes.
No new dependency, real/private data or promotion. All prior acceptance remains
open/deferred; stop before M7.9.

### Frozen protocol before results

Authoritative experiment contract: `docs/reference/DRIVEDNA_EMBEDDING_V1.md` and
`ml/experiments/drivedna-v1.json`. Use 408 original mathematical summary fixtures
(200/104/104), fictional groups split first, five program diagnostics, two vehicle
scopes and two contexts. Eight physical summaries omit identities, routes and
maximum speed. Missing/unsupported and insufficient stationary evidence abstain.

Fit one self-supervised denoising 8→6→3→6→8 autoencoder (155 parameters), fixed
seed/noise/200 epochs and training-only normalization. Labels/groups/scope tags
do not enter the encoder loss. Compare distances to the same eight normalized
summaries, not a claimed replacement for native Drive DNA dimensions. Fit each
method's stable-pair distance cutoff from training pairs only; program metadata
is diagnostic generation provenance, not field style truth or probability.

Report program retrieval per-class F1/recall/confusion, hit rate/MRR, stable false
flags and controlled changed detections, including cohort slices. Validation
requires material gain and no recall/retrieval/deviation/quality regression;
failure retains the baseline and leaves test predictions uncomputed. Exact
model/normalizer version, dataset, vehicle/context, sensor/mount scope must match
before any distance comparison. Do not expose raw vectors to app users or infer
impairment/fatigue. Shared templates cannot establish real-driver generalization.

### Acceptance / checks

- [x] Freeze manifest/license/protocol before observing the experiment result.
- [x] Implement strict generated source, self-supervised candidate, deterministic
  comparator, scoped/versioned distance contract, train-only cutoffs and safe replay.
- [x] Validate split/quality/scopes, label-independent training, cutoff isolation,
  reproducibility, failure paths and failed-gate test non-evaluation.
- [x] Run clean-source repeats and full CI; retain negative results without tuning.
- [x] Persist aggregate evidence and synchronized status; commit/push/verify Git
  and stop before M7.9.

Implementation gate: all 99 Python tests (13 new embedding tests), compile,
pinned CPU dependency check, repository contracts/secrets and diff checks pass.
The first combined suite hit a Windows rename permission failure in an unchanged
calibration test; its targeted retry and the complete 99-test rerun pass without
assertion changes. No complete embedding experiment result has been observed
before the source freeze. At that point clean-source comparisons/repeats/full CI
remained required; their completed evidence follows.

### Observed comparison / closure — 2026-11-15

Clean source `ac2e1eec595012682b1934c31b90f7a627351504` produces byte-identical
local source/checkpoint/report repeats. The source SHA-256 is
`f0f7d3522a07b1b7fb93cf2b4e0e1a87d78eef3daa16224bc6d900a0ca4a1669`;
the 6,466-byte safe JSON checkpoint hash is
`46aa9f25a2675e86039af8be47817e00eb63311b4dec1c8bafc05314b9b7ad13`.
The 155-parameter denoiser fits 200 training summaries; both distance cutoffs use
100 training correspondence pairs only (embedding 0.1128645472, summary 0.2137519959;
these are different coordinate units, not comparable probabilities).

On 80 supported validation queries, both methods have macro F1/hit rate/MRR1.0;
both detect all 40 controlled changed pairs. Embedding stable-pair false flags
are 2/40 versus 5/40 for summary distances, with no generated cohort regression.
Both abstain on all 24 missing/unsupported/stationary diagnostics before inference.
The lower false-flag count is a synthetic signal, not field FPR. The prespecified
material gate requires retrieval-F1 or changed-detection improvement, so it fails
despite the lower stable count; the criterion was not broadened after results.
No source, model, noise, cutoff or baseline was tuned. Test predictions/metrics
remain uncomputed. Aggregate evidence is
`docs/reference/drivedna-generated-v1-result.json`; all prior acceptance remains
open/deferred.

Linux's downloaded generated-only report matches the complete local validation
metrics/gate decision and unopened test status. Its source files match frozen Git
blobs and its model/report repeat comparisons pass. Source/float artifacts differ
between Windows Python3.14 and Linux Python3.12; no cross-platform byte identity
is claimed. Local repeat and clean-source provenance checks pass. Full source
[CI 43716929988](https://github.com/atrx07/Traelyx/actions/runs/43716929988) passes
all four jobs, including formatting/analysis/full Flutter/native tests, generated/
schema/privacy checks, debug/release builds and size/artifact gates, standalone
benchmark, DriveDNA/ContextNet repeats and native→CPU IntegrityNet comparison.
All 99 local Python tests, compile, pinned CPU dependency, repository validation
and diff checks pass. Historical ML source, data licenses and dependency locks
remain unchanged. No tests or gates were weakened.

M7.8 is complete at the bounded experiment level, without production adoption.
No new dependency/provider/runtime, database migration, private data, phone/
emulator, recorder, dimensions/lifecycle/scoring/narrator/Guardian change.
Real style/deviation evidence, accepted extraction/uncertainty and mobile/battery/
physical acceptance remain open along with all prior gates. `NEXTSTEPS.md` retains
the follow-up. Commit/push/verify this closure and stop before M7.9; no next-step
work is prepared or authorized.

## M7.9 boundary — authorized 2026-11-15

The maintainer explicitly continued M7.9. Deliver safe post-drive labeling and a
manual consented contribution pipeline. No production model, scoring, ranking,
Guardian, sample rate, account/cloud endpoint or background upload is enabled.
All prior model and physical/vehicle gates remain open/deferred. Stop before M7.10.

### Contract / implementation plan

See `docs/reference/EVENT_CORRECTION_V1.md` and ADR-0041. Add schema 4 local
corrections separately from immutable detections/scores, bind exact source
snapshots, use optimistic revisions, and preserve stale annotations after analysis
replacement until user removal. Whole-trip deletion cascades; raw cleanup does not
delete notes. Bound notes to 128 per trip and exports to 128 categorical reports.

No automatic prompts or live-drive labels. Open from a completed trip explicitly;
require recorder idle, known finalized trip, foreground/parked confirmation and
fresh action checks. Unknown/error/active recorder states fail closed. Missing or
unsupported detector versions cannot silently become contribution evidence.

Local notes default to no contribution permission. Changes require renewed
permission; clear/remove and revocation are local actions. Export reviews exact
consented current-source notes and serializes app actions through picker completion.
Only categorical detection/report and detector/telemetry versions leave the app,
via an explicit Android document destination. No route, raw samples, measurements,
IDs, wall/relative timestamps, free text or account binding. Saved copies cannot
be recalled. No transport/server retention or automatic training is implied.

The standard-library receiver validates strict fields/limits/digest/declared
consent and stores a versioned private quarantine manifest. Unverified reports,
missing grouping/features and consent provenance remain explicit; they do not
enter existing datasets/models or become training-eligible.

### Checks / acceptance

- [x] Implement domain, additive schema/migrations and guarded correction store.
- [x] Implement parked post-drive UI, opt-in/revocation/review and bounded native
  document export with strict cross-language privacy validation.
- [x] Implement explicit quarantine-only receiver and consent/provenance contract.
- [x] Test unchanged source scores/events, stale revisions/evidence, quality,
  safety gates, consent races, deletion, privacy rejection and v1/2/3 upgrades.
- [ ] Format/analyze, generated/schema drift, full Flutter/native/Python tests,
  app lint/builds, repository validation and relevant UI QA; run source CI.
- [ ] Persist evidence/spec/status/README, commit/push/verify Git and stop before M7.10.

No new dependency/provider is planned. The additive migration preserves all prior
evidence and queues. Core sensor/recording behavior and all model decisions stay
unchanged. Real active-driver, field-label truth and physical/vehicle acceptance
are not claimed by synthetic/widget/emulator checks.


### Local validation / source freeze - 2026-11-15

All 503 Flutter tests (25 correction tests plus the new migration regression),
506 app-native tests and 105 Python/tool tests pass. Format/analysis, exact
regeneration/schema equality, repository privacy/secret checks, app lint and
normal-entrypoint debug/release validation builds pass. The ignored lint path
normalization was restored byte-for-byte. Old schemas 1-3 remain unchanged.
The universal release validation APK is 64,203,046 bytes (61.23 MiB); no ML/runtime
or other dependency was added. This is a build size, not a sensor/battery claim.

An isolated offline Android API37/x86_64/16KiB emulator with generated trip data
verified parked/default-off notes, explicit opt-in/review, document picker/save,
cancellation without changing the prior copy, cold persistence, revocation and
removal. The final callback-enabled build saves a 404-byte categorical export
(SHA-256 `56cc59d5361715fdb9f0acef9c37ee7b64818f40e4d4ed3d996c2a0d33b6ccfb`)
which the receiver accepts into private quarantine with training blocked.
A one-use native-to-Dart callback rechecks exact source/revision/consent after
picker return before any write; absent/failed/timed-out authorization refuses it.
Tests cover another writer withdrawing notes while the picker is pending.
The physical phone, user ADB server, real telemetry and accounts were untouched.
These generated checks do not validate field label truth, physical driving,
OEM/background behavior or battery. No original evidence/model gate changed.

Commit/push this validated source for full CI; M7.9 remains in progress until
all source jobs pass and the aggregate result/status closure is persisted.
M7.10 remains unauthorized; no next-step work was prepared.
