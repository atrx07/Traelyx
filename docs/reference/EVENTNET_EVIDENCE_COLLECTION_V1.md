# EventNet evidence collection and review v1

## When to read

Use when planning the next M7 acceptance corpus after the
[15-source review](EVENTNET_REMAINING_SOURCE_TRIAGE_V1.md). The
[fillable packet](eventnet-evidence-packet-v1.template.json) is a planning template,
not a dataset importer or a frozen experiment. Actual collection, contributors,
reviewers, source access and devices are not scheduled by this document. M7.4/
M7.5 remain open; M8 remains inactive.

Follow [dataset governance](../governance/DATASET_GOVERNANCE.md),
[ML promotion policy](../governance/ML_GOVERNANCE.md), the
[native feature proposal](EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md) and
[v2 quality policy](EVENTNET_INPUT_QUALITY_V2.md). No app behavior changes here.

## Packet and completion states

Copy the empty JSON into ignored `.dart_tool/m7-evidence-planning/` before filling
it. All completed packets, identity mappings, routes, raw hashes, file references,
annotations and footage stay private/local. Keep the repository copy empty.
Use random local aliases; keep any driver-to-person mapping separately. Consent
for recording, private ML use and public redistribution are distinct records.

The JSON provides session, artifact, clock-anchor, reviewer-decision, annotation,
segment and experiment-freeze templates. Copy entry templates into their named
arrays (anchors into `fit_anchors`/`check_anchors`, reviewer decisions into
`reviewer_decisions`); use multiple packets for sessions. `null` means unresolved,
never zero or pass.
An empty `unresolved_items` array does not establish readiness. Every required
freeze field needs evidence and review; the booleans are review decisions, not
computed guarantees. There is no new admission validator or automatic workflow.

| State | Required evidence | What it permits |
| --- | --- | --- |
| Planning (current) | This packet and explicit resource gaps. | Preparation only. |
| Diagnostic pilot | Separately arranged stationary/capture check, verified export and proposed sync/reference method. | Check feasibility; keep pilot qualification-exposed and out of locked evaluation. |
| Collection-ready | Consent, intended population, driver grouping, capture/reference procedure and parked preflight reviewed. | Separately authorized routine collection; no model fitting. |
| Corpus-ready | Integrity/quality, independent labels, clock uncertainty and reviewed exposure audited. | Freeze a specific experiment and its split/custody policy. |
| Experiment-frozen | Every freeze field resolved, manifests hashed, test sealed, review recorded. | The separately approved development experiment; no production promotion. |

## Collection resources and grouping

Plan for **six distinct drivers**: two training, one selection, one calibration
and two locked-evaluation drivers. This is an initial operational allocation,
not a claim of statistical sufficiency or available participants. More drivers/
episodes may be needed per class and subgroup. If this allocation is infeasible,
revise the plan before collecting evaluation data or inspecting features; do not
silently reuse a selection driver for calibration/test.
A single-driver pilot remains useful as exposed diagnostic development evidence;
the six-driver allocation applies to planning the later independent experiment.

One working phone can be reused across drivers; six phones are not required.
Record phone, vehicle, mount, route and recording-day groups. Shared hardware or
routes limit generalization claims; declare deliberate holdouts and remaining
confounds before fitting. One driver cannot become independent groups by making
more trips. Duplicate or overlapping drives belong to one role. Assign driver
roles before windowing/feature inspection; log qualification exposure. Raw labels
may be reviewed by the test custodian while model developers remain blinded.

Declare the intended vehicle/device/mount population and supported classes before
collection. Car evidence alone cannot establish motorcycle/pocket performance.
Existing Tecno archives and the Redmi stationary QA export retain their exclusion
status. Redmi driving/GNSS reliability remains unverified. No new Tecno bias
correction, accuracy override or damaged-sensor exception is introduced.

## Parked preflight and later capture

1. Use the [existing manual installation/export procedure](M7_MANUAL_PHONE_QUALITY_CHECK.md)
   when a phone is available. Preserve the installed app/data; do not uninstall,
   clear storage or configure accounts/cloud/Guardian to collect evidence.
2. While parked, verify storage, source units/timestamps/status/flags, stationary
   behavior, stable mount/calibration, GNSS and the independent driving-context
   evidence. Waiting a fixed number of seconds does not prove GPS readiness.
   Preserve failed diagnostics; do not turn them into normal examples.
3. Prove the independent reference and clock mapping on a diagnostic pilot before
   reserving an evaluation recording. Recorder-aligned physical presentation times
   remain unmeasured. The separate
   [software-marker pilot/checker](EVENTNET_SYNC_PILOT_V1.md) now provides draw
   journals and candidate clock checks; actual display/camera delay and recorder
   binding remain unverified. A visible UI timer alone does not establish them.
4. When separately arranged, record routine journeys with a fixed mount and an
   independently synchronized view/reference. Set up and stop while parked; the
   driver does not operate recording/review controls while moving. Capture
   naturally occurring events only. Do not stage harsh public-road maneuvers,
   impacts, crashes or distracted driving to fill a class quota.
5. Finalize normally, verify idle/save state and export a private `.tripdebug`.
   Transfer locally by USB/MTP; ADB is optional. Hash/preserve original bytes and
   independent reference files. Use the [archive inspector](TRIPDEBUG_FORMAT.md)
   and existing intake tooling for their documented integrity/quality scope.
   Export success does not establish calibration, labels or corpus admission.

Keep video private; road-facing footage can expose other people/plates/routes.
No upload, sharing, identity publication, release fixture or retention deletion is
authorized here. Record contributor withdrawal/retention decisions and affected
artifact/model provenance. Public summaries contain reviewed aggregates only.

## Independent clocks and physical reference

Keep native boot-time nanoseconds, reference time units and any wall clock
distinct. Preserve a versioned mapping, original reference hash, fit anchors,
separate check anchors, residuals, uncertainty and its validated time range.
Use at least two fit anchors and two additional independent check anchors covering
the claimed recording interval for an affine clock mapping. More anchors or a
piecewise model may be necessary; never extrapolate across an unchecked restart.
Markers must be captured safely while parked or by automatic instrumentation.
If check evidence does not bound drift between anchors, retain that uncertainty.
Do not align clocks or choose axes using the event labels or model/rule outputs.

Clock acceptance limits must be fixed for the selected annotation/latency claim
before evaluation. An unknown or excessive uncertainty prevents that claim; it
does not become zero. Keep boundary uncertainty with each interval and exclude
ambiguous margins from normal exposure. Report detection times as intervals when
reference timing cannot support exact onset latency.

Video can establish a maneuver and its direction without establishing physical
strength. To call braking/acceleration/cornering *strong* or an impact a specified
severity, require an independently calibrated physical reference, documented units/
rate/clock/frame/error and a reviewed versioned strength rubric. This may be an
appropriate independently measured vehicle/reference signal; its suitability is
unverified until tested. Native model inputs, current-rule detections, GNSS/CAN
thresholds without a justified independent rubric, and driver impressions alone
do not establish that truth. A video-only pilot may remain maneuver research.

## Review instructions

Review all proposed ordinary-driving exposure, not just interesting clips.
Two independent human passes use the same instructions and remain blind to model
predictions, rule detections and input-channel plots. Preserve both decisions.
Disagreements require an independent third adjudication or stay unknown. Repeating
one person's pass is not an independent reviewer; LLM suggestions are not verified
truth. Publisher annotations may be reused only after documenting an equivalent
provenance/review contract.

| Observation | Record | Admission limitation |
| --- | --- | --- |
| Ordinary-driving candidate | Continuous reviewed range, view/context quality, all in-scope events and gaps considered. | Becomes normal truth only when absence of the governed target events is supportable, including strength evidence where needed. |
| Acceleration/braking | Observable maneuver interval and boundary uncertainty. | Strength remains unknown without the independent reference/rubric. |
| Left/right turn or curve | Direction and interval from independent scene/reference. | Neither turn direction nor visible curvature proves high lateral load. |
| Surface transition | Visible road/suspension event and reference if available. | No crash or severity inference from a bump or IMU spike. |
| Device handling | Visible handling/mount change or explicit invalidation reference. | Quality/abstention slice; the current native extractor rejects invalidated movement rather than supplying an ordinary-driving tensor. |
| Unknown/unreviewable/stationary | Reason, interval and uncertainty. | Never default to normal. Stationary QA is outside driving-model truth. |

Use boot-time `[start, end)` annotation intervals inside a verified session range.
Keep multiple simultaneous observations (for example braking while turning).
Native windows remain `(start, end]`; freeze window-label overlap, multi-event,
warmup and unknown-boundary treatment before fitting. Do not force majority labels
or discard difficult windows after seeing predictions. Retain reviewer coverage,
disagreement/unknown rates and per-class independent episode counts per driver.

## Exposure and evaluation freeze

Freeze driver/source manifests and duplicate audit before windows; fit normalization
on training only. Use selection data for architecture/search/quantizer decisions,
training-only representative inputs for quantizer calibration, and the separate
calibration role for temperature/decision thresholds. Freeze the final candidate,
merging, one-to-one event matching/IoU/onset tolerances and baseline comparator
before opening locked evaluation. Compare on identical reviewed support. The
old observed v1 test cannot become a fresh test or a quantizer tuning loop.

Report elapsed driving, independently reviewed exposure, quality-eligible time,
actually scored time, abstention and unknown time separately. Compute exposure
from the union of eligible reviewed ranges after uncertainty/warmup exclusions,
not the sum of overlapping windows. Match episodes one-to-one; extra detections
remain false detections under the frozen policy. Unknown truth stays unscorable
and is reported; low coverage cannot hide behind a small false-event rate.

Predeclare per-class precision/recall/F1, macro F1, severe PR-AUC, event false-rate
confidence method, minimum exposure/positive episodes and driver/subgroup coverage,
calibration NLL/Brier/ECE, and end-to-end latency. Latency includes the six-second
window/placement, filter history, hop, source lookahead, scheduling and inference;
do not report neural-call time as detection latency. Unsupported classes/strata
remain unsupported, not passed. Numeric performance thresholds stay unresolved
until baseline feasibility and the intended claim can justify them, and must then
be frozen before test access. The template deliberately contains those open fields.

For exposure planning only, zero observed false events in `T` comparable reviewed
eligible hours gives a one-sided 95% Poisson upper rate of `-ln(0.05)/T`, under a
constant-rate event model. This follows by taking the reciprocal of the
[NIST zero-failure MTBF bound](https://www.itl.nist.gov/div898/handbook/apr/section4/apr451.htm).

| Reviewed eligible hours (hypothetical) | Upper false-event rate/hour with zero observed |
| --- | --- |
| 1 | 2.996 |
| 3 | 0.999 |
| 10 | 0.300 |
| 30 | 0.100 |

These are planning calculations, not adopted gates or measured results. Counts
are merged events, not correlated windows; driver/route clustering and the target
population require their own justified uncertainty analysis. Do not stop/extend
the locked test after seeing favorable results; fix exposure/stopping first.
Zero errors in a short pilot does not prove a zero population false-event rate.

## Device efficiency and remaining resources

After valid corpus/feature evidence exists, freeze export parity, size, cold/warm
latency, CPU, memory, sustained battery/thermal and recorder-interference budgets
on named real target devices. Preserve old numerical rejection and all M6.8 field
gates. The emulator supports integration checks, not sensor or battery acceptance.
No model runtime/integration or score/Guardian change follows from this packet.

Currently unresolved: driver/reviewer availability, intended population/class scope,
working synchronized reference/strength instrumentation, routine recordings,
reviewed exposure, group manifests and numeric experiment/device gates. None is
claimed available by writing this protocol. The next practical use is a separately
arranged parked pilot proving sensor/export and synchronization/reference
feasibility; collection remains deferred until resources are available.
