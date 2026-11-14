# Execution Plan — M7 ML & Advanced Commentary

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M7
**Current gate:** M7.5 foundation validated; real-model integration/acceptance carried forward
**Started:** 2026-11-11
**Last updated:** 2026-11-14

## Context budget / references

Read `ml/AGENTS.md`, roadmap M7.1, dataset governance, ML split/provenance
requirements, the dataset registry schema, and affected tooling/tests only.

## Goal / user-visible result

Current authorized work: the M7.5 foundation, explicitly continued by the
maintainer after accepting development with model integration gated. Preserve
M7.4 numerical rejection and model acceptance as open follow-ups. The appended
boundaries supersede earlier step-specific scope. Stop before M7.6.

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
