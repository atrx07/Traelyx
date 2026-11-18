# M7 engineering wrap-up and acceptance carry-forward v1

## When to read

Use before M8 development, any inference activation, or distribution. Historical
experiments remain in the [exit audit](M7_EXIT_AUDIT_2026-11-16.md) and retained
source results. This ledger records the 2026-11-17 sequencing decision; it does
not rewrite those audits or call unfinished acceptance complete.

## Decision and distribution boundary

The maintainer authorizes wrapping feasible M7 work and proceeding to M8 hardening
while a future ordinary Tecno/Redmi journey supplies diagnostic evidence. This
supersedes the earlier acceptance-before-M8 sequencing preference. M7.4 mobile
acceptance and M7.5 real hybrid integration are deferred/open. Production sensor
inference stays disabled; deterministic rules/scores remain authoritative. The
local neural narrator remains unavailable and the built-in narrator remains.

The bounded wrap-up passes all four source CI jobs 44090880412 for `1bb6bdf`.
M8 is activated for hardening; M8.1's bounded stationary matrix is complete in the
[Android hardening plan](../exec-plans/active/M8_ANDROID_HARDENING.md), with full
source CI 44168836701 (`63d4826`). M8.2's qualified baseline is complete in the
[performance plan](../exec-plans/active/M8_PERFORMANCE_BASELINE.md), with all four
source CI jobs 44239049290 (`dfc316a`) passing. M8.3 awaits explicit authorization. The
normal explicit gate between later numbered substeps remains. **Stop before main
distribution:** M8.10 publication, release/tag/assets, store submission, public
download links and external APK distribution are unauthorized. Prior private
device QA and source pushes are not a distribution release. Signing/keystore
steps still need their normal maintainer-controlled procedure; no key is created
or requested here. Release-validation builds in CI do not grant release approval.

The [release checklist](release-checklist.yaml) must retain this hold. Publication
requires a new explicit maintainer instruction plus applicable acceptance gates
and deliberate disposition of all carried-forward limitations. This ledger is an
approval boundary, not a claim of automated prevention of every publishing path.

## Current acceptance ledger

| Area | Current disposition | Evidence needed to change it |
| --- | --- | --- |
| M7.1–M7.3 | Complete at bounded experimental scope; no production promotion | New source/native-feature and independent label/group evidence before a new candidate protocol. Preserve prior calibration/test-reuse disclosure. |
| M7.4 | Deferred acceptance; v1 int8 remains rejected | New versioned candidate with frozen independent evaluation; parity, size, latency/CPU/memory/battery and subgroup budgets. Existing drift 0.0509469 exceeds 0.05 and cannot be retuned away. |
| M7.5 | Validated disabled-inference/generated foundation; real integration deferred | Accepted feature/model/class mapping, corroboration policy, auditable runtime/fallback and real integration/fixture/device checks. |
| M7.6 | Generated IntegrityNet experiment complete; no field promotion | Independent legitimate/anomaly exposure, stronger baseline, calibration and device cost. |
| M7.7/M7.8 | Experiments complete; value gates failed, rules/dimensions retained | Separately justified future experiments; never open old test predictions to chase a pass. |
| M7.9 | Local correction/export/quarantine pipeline complete | Contributions remain unverified and training-blocked; separate consent, grouping, features and independent labels required. Signed-history upgrade rehearsal belongs to M8. |
| M7.10 | Reviewed Groq wording selection complete | No free-form generation claim or repeated live request. Existing explicit payload/credential controls remain. |
| M7.11 | Architecture complete; optional runtime/source unavailable | Reviewed/licensed runtime/model and separate physical quality/performance admission before activation. |
| Native input v1/v2 | Unwired development APIs only | Source SI/frame/time/quality agreement; retain quality masks, status and limited-history metadata. |
| Public/old recordings | Reviewed sources and Tecno data remain diagnostic | Current leads do not supply the complete native feature/label/group contract. Offset estimates do not repair recorded status, mounting or truth. |
| Sync pilot | Pixel/Tecno software/lifecycle/export checks pass | Physical presentation/reference timing and recorder boot binding remain unverified. ADB screenshots cannot establish them. |
| Future ordinary trip | Defined, not yet collected | [Trip procedure](M7_FUTURE_ROUTINE_TRIP_V1.md); one journey/two phones is diagnostic, not independent drivers or calibrated truth. |
| M6.8 / field reliability | Existing active-driver/recovery/performance/vehicle/OEM gates carried forward | Relevant real lifecycle, physical/vehicle/OEM and Guardian evidence; no live alert operation authorized by handoff. |
| Distribution | Explicit hold | Applicable M8/acceptance/security/upgrade gates, disposition of limitations and new publication authorization. |

No new real-source model experiment, threshold change, historical score rewrite,
new provider, runtime package, sensor correction or production activation is part
of wrap-up. CI may repeat the existing fixed generated experiments; that supplies
software regression evidence, not new source/candidate acceptance.

## Tightened now / verification

Normal exported tripdebug files now have hash-pinned aggregate sensor-quality
intake through `python -m tool.inspect_field_recording`. It reuses structural
validation and backup-intake quality semantics, preserves legacy inspector output,
and omits private identities/paths/hashes/vectors/timestamps from the new report.
It checks the same unbuffered read-only descriptor before/after parsing; mutation,
wrong hashes, invalid archives and private failure messages have generated tests.
Success always remains diagnostic-only with training/evaluation admission false.

Source inspection confirms `HybridEventEvidenceBoundary.productionAudit()` still
returns `DISABLED_MODEL_ACCEPTANCE_DEFERRED`; `LocalTripAnalysis` uses that boundary.
The local commentary provider binds `UnavailableLocalRuntime` and
`UnavailableLocalSource`. These bindings were reviewed, not modified. Reuse
full source CI for existing application behavior; do not manufacture new physical
or scientific evidence from its passing software tests.

Validation and final source CI are recorded in the
[wrap-up result](m7-wrapup-v1-result.json) and
[execution plan](../exec-plans/active/M7_WRAPUP_HANDOFF.md). The earlier
[Tecno pilot source](sync-pilot-tecno-v1-result.json) passed all four jobs
44085930694 for `68d91d6`. No device was operated during this wrap-up.
