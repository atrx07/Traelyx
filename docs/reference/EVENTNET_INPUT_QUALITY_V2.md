# EventNet development input-quality proposal v2

## Scope — 2026-11-17

This bounded M7 follow-up proceeds while the maintainer's research agent qualifies
datasets. It implements a separate **unwired development** feature contract,
`eventnet-native-derived-imu-proposal-v2`. It authorizes no source admission,
new source-model training/prediction, runtime/provider dependency or production promotion.
M7.4/M7.5 remain open; M8 remains inactive. No device or dataset is accessed.
See [machine contract](eventnet-native-input-proposal-v2.json) and
[aggregate validation](eventnet-input-quality-v2-result.json).

The [v1 extractor](EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md) retains its strict
resolved/eligible behavior and original ten regressions. The rejected historical
EventNet model, splits, metrics and numerical gates remain unchanged. This v2
feature proposal does not supersede those experiments or change M3 confidence.

## Problem and decision

The previous real-stream feasibility slice identified that requiring exact native
eligibility rejects normal asynchronous IMU sampling. M3 correctly marks native
interpolation degraded and dependent metrics limited. Moreover, its recursive
filters retain cumulative provenance/degradation until reset: an exact current
sample may still have interpolated evidence in its filter history.

Use the existing native derived values and preserve those limitations in a
mandatory v2 sidecar. Accept only a fully explained interpolation case for
development input construction; do not reinterpret all LIMITED evidence as usable.
This proposed distinction is separate from permission to train, infer, score or
make a safety decision. No downstream boundary or event rule changes.

## Numerical and quality contract

Numerical order, units, window and preprocessing remain the v1 proposal's:
float32 `[1,4,600]`, forward/left/up acceleration in m/s² and upward yaw in rad/s,
six seconds `(start,end]` at 100 Hz. Defaults, context/calibration binding, complete
coverage, finite conversion and immutability checks are shared with v1. The v2
schema produces a distinct context fingerprint even for identical numeric values.

`ProvisionalInterpolatedEventFeatureExtractor.extract` is a separate API. Its
returned v2 window must contain a copied immutable sidecar. Mask order is
`[accelerometer,gyroscope]`, each with 600 aligned targets:

| Bit | Meaning |
| --- | --- |
| 1 | Current native source alignment is interpolated |
| 2 | Derived filter provenance includes interpolation since reset |
| 4 | Native metric eligibility remains LIMITED |

The sidecar also preserves minimum observed Android accuracy status, maximum
current source bracket and lookahead for each channel, and the calibration's
per-sensor interpolation counts. `nativeMetricsLimited` reports mask bit 4;
`hasInterpolationEvidence` includes both masks and calibration counts. Neither
field is a confidence percentage or a physical-precision claim. Calibration-only
interpolation can be present while native current metrics remain supported.

Maximum bracket/lookahead fields describe targets in this window. Existing M3
cumulative provenance does not retain the largest bracket before the window;
historical maxima are **unknown**, bounded only by the pinned native configuration.
An exact-current window with interpolated filter history must not be described as
having an entirely exact source history because its current bracket maximum is zero.

## Admission checks

For each channel and target:

- Native source is present, accuracy is reported in 1–3, current and cumulative
  flags are empty, and cumulative minimum accuracy is present and consistent.
  No missing public-source accuracy is synthesized as Android status 3.
- EXACT requires coincident lower/target/upper times and the exact supported
  assessment. INTERPOLATED requires strict bracketing and only the native
  `IMU_INTERPOLATED` degradation reason. Elapsed and source-clock brackets are
  bounded by the unchanged native 50 ms ceiling, with cumulative provenance
  covering their bounds. This ceiling is a development limit, not field acceptance.
- Derived evidence must exactly match native channel preprocessing plus the
  disclosed interpolation history. Current and historical alignment, channel
  quality, limiting components and metric reasons must agree. Unknown or extra
  degradation cannot pass merely because the numeric value is finite.
- Calibration, orientation and device stability retain their supported native
  assessments. One resolved context spans the window; its calibration/mount
  identity and evidence must match the source provenance. Unreliable/flagged
  calibration is rejected. Native calibration interpolation counts remain visible.

Dropouts, clock/source flags, unreliable or unknown accuracy, missing channels,
oversized brackets, unexplained degradation, context changes, provenance mismatch,
unsupported configurations and float32 overflow remain rejections. There is no
additional model-level interpolation, padding, clipping, gravity removal or flag
rewriting. Current-native and derived-history assessments are never modified.

## Consumer and acceptance limits

Any future consumer must bind schema, numeric values, sidecar, context, source
artifact and interval together. Dropping the sidecar or interpreting v2 as the
strict v1 schema violates this contract. No accepted model manifest or consumer
exists. The API replays native history for one window and is not an optimized
rolling scheduler or a measured real-time/battery implementation.

This is not a public-dataset adapter. It does not establish units/frame/gravity
equivalence for Zenodo/Q-Motion, source accuracy, independent normal/severe truth,
grouped evaluation, calibration, mobile efficiency or model acceptance. Those
remain prerequisites for freezing and validating a new experiment. The external
research agent's findings will be reviewed separately, without silently opening
new held-out streams or promoting this proposal.

## Validation

Nine additional generated regressions pass alongside the ten unchanged v1 tests.
They exercise the actual decoder → alignment → M3 derived/confidence → feature
path, compare numeric outputs and verify native evidence is unchanged:

- Exact input: v1/v2 numeric tensors match, with distinct schema/context identity.
- A 1 ms gyro offset: all 600 yaw targets retain interpolation/history/LIMITED
  bits, a 10 ms bracket and 1 ms lookahead. Strict v1 still rejects this input.
- Interpolation only before the window: current interpolation count is zero,
  while all 600 yaw targets retain history and native LIMITED evidence.
- One missing gyro sample: a bounded 20 ms bracket is disclosed. The native
  50 ms ceiling is accepted as development data; an oversized gap is rejected.
- Current unreliable/dropout/clock flags and an unreliable filter-history sample
  are rejected. Forged reasons, brackets, provenance accuracy or limiting
  components do not bypass checks. Sidecar copies cannot mutate stored metadata.
- Calibration faults, context changes, unsupported configuration and invalid
  bounds remain rejected. Native calibration interpolation counts are preserved.

All 528 native tests, Android lint, the debug build and repository validation pass.
All four [source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/44042014141)
pass for `e8ad83e` on attempt 1, including full app tests and debug/release-validation
builds. Source Git-blob hashes are preserved in the aggregate evidence. Existing
generated-model regression experiments run in CI; no new source-data experiment
or held-out model prediction is made by this unit.
No new dependency, migration, recorder sampling, scoring/Guardian effect, private
data access or upload. Physical performance and field accuracy remain untested;
neither the emulator nor the physical phones are needed for this development unit.
