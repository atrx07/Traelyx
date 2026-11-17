# EventNet native input proposal v1

## When to read

Read when qualifying the next EventNet corpus or implementing its feature
adapter. The numerical target remains proposed. An unwired native development
extractor now implements its window/quality checks; no public-source adapter,
frozen model experiment or production approval exists.
[Machine-readable proposal](eventnet-native-input-proposal-v1.json).
Existing v1 weights, source-space inputs, splits, numerical rejection and results
remain reproducible. M7.4/M7.5 remain open; M8 stays inactive.

## Why this target

The old six-channel/seven-row public experiment is not the app's physical feature
pipeline. The next candidate should consume quantities the native pipeline
actually produces, without silently adopting a publisher's different filters,
frame matrices, sensor units or timestamp reconstruction.

The [native pipeline](../technical/SENSOR_PIPELINE.md#m35-implemented-derived-channel-baseline)
already produces vehicle forward/left/up acceleration and vehicle-up yaw rate.
Its default analysis cadence is **10 ms / 100 Hz**, declared by
`DEFAULT_ANALYSIS_INTERVAL_NANOS` in `RawTelemetryProcessing.kt`. Replay's 100 ms
presentation cadence is a separate contract and is not the model input source.
No recorder, alignment, replay or filter configuration changes in this proposal.

## Proposed numerical contract

| Item | Proposal |
| --- | --- |
| Tensor | float32, channels first, `[1, 4, 600]`; 9,600 value bytes |
| Channel order | forward/left/up derived acceleration (m/s²), up-axis yaw rate (rad/s) |
| Window | Six-second `(start, end]` interval, exactly 600 supported 10 ms targets |
| Bounds | First target `start + 10 ms`, last target `end`; first-to-last sample span is 5.99 s |
| Hop | Initially propose one second; freeze only with the actual experiment/runtime budget |
| Frame | Explicitly established native vehicle forward-left-up; positive up-axis yaw follows the native right-handed frame |
| Normalization | Future train-only fit; identity/configuration embedded in the model manifest and applied identically on host/device |

The source is M3 derived telemetry, not raw Android axes, replay envelopes or
public prealigned columns. Preserve the native stationary-reference removal,
gyro zero-rate subtraction, mount transform, three-frame median and one-pole
filters (200 ms acceleration / 150 ms yaw). Do not subtract gravity or a Tecno
offset again. Double-to-float conversion must reject non-finite results; do not
clip values into a trained range to conceal invalid evidence.

Every target must have available channels with resolved source provenance and
`ELIGIBLE` native `VEHICLE_ACCELERATION` and `YAW_RATE` decisions under the pinned
confidence configuration. A future implementation must bind its configuration,
context/calibration identity and interval bounds, reject gaps, missing/limited/
invalidated evidence or context changes, and respect native movement invalidation.
Preserve the native bounded interpolation and its source-time provenance; its
bracketing sample may arrive after a target. A latency benchmark must include
that lookahead and the window/hop/filter availability, rather than time only the
neural call. Do not add model-level gap filling, future padding, fabricated
accuracy status or uncertainty removal. Dataset adapters must establish equivalent
evidence rather
than invent Android status 3 where a public source omits it.

This four-channel tensor does not itself establish driving context. A separate
explicit admission policy must prevent desk/handheld data becoming normal-driving
examples. GNSS and independent source evidence remain relevant even though GPS
coordinates/speed are not tensor channels in this proposal. The Redmi stationary
QA recording remains excluded from driving-model data.

## Conditions before freezing or implementing the experiment

1. Establish governed event classes and source mappings, including representative
   independently reviewed ordinary-driving exposure. Unlabelled time is unknown;
   generic curves cannot become left/right truth by reading gyro sign, and rule
   detections cannot be the independent truth for beating those same rules.
2. Verify source units, gravity semantics, time quality, frame/calibration and
   preprocessing equivalence. Retain reconstructed/approximate timing as such;
   it cannot support an exact detection-latency claim.
3. Assign independent driver/source groups before windows and fitting. Disclose
   qualification exposure, prevent route/device leakage where possible, separate
   selection/calibration/evaluation and lock test feature access and predictions.
4. Freeze class/value/calibration/error criteria, abstention/coverage, normalization,
   architecture/export configuration and numerical/size/CPU/memory/battery gates.
   Preserve v1's original rejection; do not tune quantizers against its observed test.
5. Implement and compare the host/native adapter on governed fixtures before
   training, then benchmark an accepted candidate and explicitly review promotion,
   integration and rollback. No existing rule/event class is removed by this proposal.

The Q-Motion metadata audit identifies several of these missing prerequisites;
see [source qualification](QMOTION_METADATA_QUALIFICATION_V1.md). No train/validation/
test roles, class set, fitted statistics, learned weights or runtime dependency
are created here.

## Development implementation

`ProvisionalEventFeatureExtractor.extract` consumes the existing synchronized
native derived/confidence timeline with exact default configurations. It produces
one immutable copied tensor or a typed rejection; it has no production caller,
model runtime, fitting, network or storage side effect. It requires one resolved
calibration/mount context across the window, checks per-channel provenance,
preserves source bounds/lookahead and rejects incomplete, limited or overflowing
inputs. Its context hash binds calibration values/flags and mount basis. Repeated
calls replay the native timeline from its beginning to retain filter history;
this development API is not a benchmarked streaming inference scheduler.

A numeric window does not admit a driving context or source artifact. A future
experiment/runtime must additionally bind the source manifest/hash, independently
establish context/labels, and meet all model/mobile gates. Generated native
pipeline tests establish tensor values and rejection behavior. The
[real-stream feasibility probe](EVENTNET_FEATURE_FEASIBILITY_V1.md) measures
source timing but does not manufacture native inputs from preprocessed data.
The strict resolved/eligible policy also rejects clean asynchronous native IMU
that needs interpolation. That is a demonstrated proposal limitation, not a
sensor failure; a general-use feature-quality policy remains to be established.
