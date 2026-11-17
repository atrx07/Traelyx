# EventNet feature and real-stream feasibility v1

## Scope — 2026-11-17

The maintainer authorized a provisional extractor plus one small public
development-recording check. The existing emulator and both phones were unused.
No candidate is trained, no prediction is made, and M7.4/M7.5 remain open.
See [aggregate evidence](eventnet-feature-feasibility-v1-result.json) and
[native feature contract](EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md).

## Implemented native path

`ProvisionalEventFeatures.kt` reads the existing M3 derived/confidence timeline;
it does not duplicate filters or reinterpret raw samples. With pinned defaults,
one six-second `(start,end]` window becomes float32 NCT `[1,4,600]`: forward,
left and up acceleration in m/s², then upward yaw in rad/s. All 600 targets must
be present, resolved and eligible for the two required native metrics. Missing
samples, limited quality, changed/unresolved context, calibration-provenance
mismatch, unsupported configuration and float32 overflow return typed rejection.
No clipping, second gravity/bias subtraction, padding or model-level gap fill.

The returned tensor is copied on construction/read. Source bounds and maximum
bracketing lookahead remain explicit; a context fingerprint binds calibration and
mount basis. Ten generated native regressions exercise the actual chunk decode →
alignment → derived → confidence → tensor path and bounded failure fixtures.
Neither a numerical window nor its context fingerprint admits driving context,
independent labels, a source artifact or a model. Production analysis has no
caller, and `HybridEventEvidenceBoundary.productionAudit()` stays disabled.

This one-window development API replays native history to preserve filter state.
It is not an optimized rolling scheduler, and no latency/battery claim follows.

One regression also exposes a limitation of the strict proposal itself: clean
gyro samples offset 1 ms from the accelerometer timeline require native
interpolation, which M3 truthfully marks degraded/limited. This extractor rejects
that window. It does not establish a hardware fault. Common asynchronous sensor
sampling therefore needs an explicitly reviewed feature-quality policy before
this proposal is viable as a general training/serving contract. Do not erase
interpolation evidence or silently relax the existing native confidence rules.

## Frozen development exposure and source preservation

Before opening sensor content, trip 2 of the original
[Zenodo release](https://doi.org/10.5281/zenodo.6570972) was designated
qualification-exposed development data. The pre-inspection protocol SHA-256 is
`a03655471887f18677a69c4b818c489aa5438d921e7ce2a9a72b79088772632d`.
The committed `ml/qualification/zenodo-stream-feasibility-v1.json` preserves the
declared role, publisher sizes/MD5, budget and subsequently verified SHA-256 pins.
No unexamined test role is claimed; other sensor trips remain unopened.

Three files totaling 34,308,629 bytes were retrieved under the declared 35 MB
budget: trip-2 linear acceleration, trip-2 gyro and the publisher notebook.
Publisher checksums and complete lengths were verified before content inspection.
The notebook was parsed as JSON/source text and never executed. Already reviewed
trip-2 labels were copied locally and reverified. Input bytes remain unchanged,
ignored and local; committed evidence contains pins and reviewed aggregates only.

## Measured real-signal result

| Observation | Result |
| --- | --- |
| Linear acceleration | 258,971 samples; 646.895241346 seconds |
| Gyroscope | 258,973 samples; 646.900237269 seconds |
| Observed mean rate | About 400.328 Hz for both |
| Maximum adjacent gap | 5.001 ms for both; no gap over native 50 ms limit |
| Development 100 Hz / six-second / one-second-hop probes | 641 with timing support in both streams |
| Maximum diagnostic bracket lookahead | 4.995 ms, rounded for this table |
| Labels in this trip | 38 intervals, including four non-aggressive intervals totaling 17.632 seconds |
| Labels shorter than six seconds | 33 of 38 |

The grid origin is the common stream start, used only for this diagnostic.
Column seconds are explicitly rounded to nearest nanosecond (half even) for
interval arithmetic; no source-clock precision or shared hardware clock is
inferred. The two initial samples differ by 2.501 ms; that alone neither proves
nor corrects a synchronization error. Publisher extraction uses label `start/end`
directly against stream seconds; the probe follows that convention without
applying another `timesync` shift. Independent alignment remains unverified.

Eight timing-supported windows lie wholly inside one published event interval:
three left-turn, two acceleration and three left-lane-change. None lies wholly
inside a labelled non-aggressive interval. This is a coverage diagnostic, not a
requirement that every event last six seconds. A future event-presence/centered
window policy must govern context and overlaps; do not discard short events or
infer background labels automatically.

## Compatibility decision

**Timing is usable for a bounded development study; native input admission is
unresolved.** All 641 timing-supported windows still lack established native
source semantics/quality. Native eligibility is not assessed and zero public
windows are admitted; no public-source tensor is manufactured.

The acceleration file is already gravity-removed linear acceleration. Its
gravity-removal algorithm and a matching raw accelerometer/stationary reference
are not established in the inspected inputs. It cannot silently be passed through
M3's raw stationary-mean removal as an equivalent training signal. Android source
accuracy/flags are absent and are not synthesized.

The notebook reports a dashboard landscape mount and driver audio start/stop
notes. Its plotting permutation/sign choices `[device_y,-device_x,-device_z]`
have determinant −1. That plotting convention is a reflection, not the native
right-handed vehicle rotation; it was not applied or declared a publisher defect.
Landscape orientation alone does not establish the required vehicle basis.

One driver cannot supply independent training/validation/test driver groups.
The unlabelled remainder of the recording is unknown, not verified ordinary
driving. This source remains a development lead; no model-quality, severe-FPR,
calibration or detection-latency acceptance metric is available from this probe.

Attribution: Escottá, Álvaro Teixeira; Beccaro, Wesley (2022), *Driving Events
Dataset: a smartphone inertial measurement unit for driving events*, v1,
DOI 10.5281/zenodo.6570972, CC-BY-4.0. No endorsement implied. No raw source
content is redistributed.

## Reproduce and validate

```text
python -m ml.stream_feasibility --root <ignored-directory-with-pinned-inputs>
python -W error::ResourceWarning -m unittest tests.tool.test_stream_feasibility
./gradlew :app:testDebugUnitTest --tests '*ProvisionalEventFeaturesTest'
```

The real pinned probe, eight generated Python tests and ten native focused
tests pass. Full regression/build/CI status is recorded in the aggregate evidence.
No new dependency, schema/migration, recorder sampling change, score behavior,
private-data access or device operation. No physical benchmark was run; it becomes
useful after an accepted host candidate exists. Further data/native-equivalence
and independent driving evidence remain necessary before a new model experiment.
