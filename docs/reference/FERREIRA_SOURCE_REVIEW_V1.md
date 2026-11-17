# Ferreira source review v1

## When to read

Read before using `jair-jr/driverBehaviorDataset` for EventNet development,
requesting its videos, or repeating the external research report's licensing and
frame conclusions. This is a primary-source documentation review, not a data
import, adapter, model experiment or production admission. See
[aggregate evidence](ferreira-source-review-v1-result.json) and the
[acceptance plan](../exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md).

## Verified findings — 2026-11-17

| Question | Primary-source finding | Consequence |
| --- | --- | --- |
| Permission | Repository owner `jair-jr` publicly permits dataset/code use with paper and dataset attribution in issue 1. | Record affirmative custom permission evidence; do not describe the source as having no permission statement. No SPDX licence is inferred, and intended model/data distribution scope is not adjudicated here. |
| Units | The paper, section 4.1, defines acceleration in m/s² and angular rate in rad/s; accelerometer includes gravity and linear acceleration excludes it. | The publisher's intended units are documented. Actual file scale/calibration and native preprocessing equivalence are not measured by this review. |
| Videos | In issue 3 the author says he no longer has the recordings. | The proposed new video-review pass cannot proceed from this evidence. No current replacement footage was established. |
| Original axes | Issues 2 and 6 confirm that only Earth-transformed values were stored; original device-frame readings and rotation matrices were not retained. | A gravity-present acceleration file is not an original device-frame recording. Do not pass it to native device-axis calibration or infer a vehicle-forward axis from event labels. |
| Driver assignment | The four `viagem.json` files contain clock/device fields but no driver field. The reviewed R loader has no driver mapping; the paper states two drivers. | Trip IDs, dates and one handset model do not establish driver-held-out groups. Mapping remains unresolved, not proven absent from every possible external source. |

The permission statement is linked directly in
[issue 1](https://github.com/jair-jr/driverBehaviorDataset/issues/1#issuecomment-601881123).
The author's phrase “use the dataset and the source code as you wish” is stronger
evidence than a missing LICENSE file alone. The original question concerned
academic use/publication. Preserve that context and the attribution request;
do not silently substitute MIT, CC-BY or another standardized licence. This
review records the statement, without declaring every intended distribution use
approved. The paper's own open-access licence is a separate fact.

## Label evidence and unavailable footage

The [author's explanation](https://github.com/jair-jr/driverBehaviorDataset/issues/3#issuecomment-767632619)
describes a fixed windshield mount, a visible trip timer, a back-seat camera,
the driver announcing an instructed maneuver and the author later reading its
type/start/end from the video. A
[second reply](https://github.com/jair-jr/driverBehaviorDataset/issues/3#issuecomment-769462209)
states that aggressive versus normal execution depended on driver experience.
This establishes a manual video-timing procedure, not threshold-generated labels.
It does not establish independently validated severity or reviewed ordinary-driving
coverage. Controlled events and manual annotation are not mutually exclusive.

The external report's claim that only isolated sensor clips exist is too strong:
the repository describes trip sensor files and sparse event intervals. This review
does not measure waveform continuity. Unlabelled time remains unknown even when
sensor data exist outside labelled events. It cannot become negative truth by
default, and the author's reported loss of the videos prevents the proposed
re-annotation route. Do not repeatedly request the same known-unavailable footage
without a concrete alternative archive lead.

## Collection and clock semantics

The author links the companion
[EarthAxesConverterFunction](https://github.com/jair-jr/driverBehavior/blob/master/AndroidStudioProjects/AnalisePerfilMotoristas_v1/app/src/main/java/br/com/j2/apm/function/EarthAxesConverterFunction.java).
Inspection of that source text shows:

- Gravity and magnetic-field events supply the Android rotation matrix. Target
  vectors are multiplied by the 3×3 matrix before export.
- The function buffers the latest gravity, magnetic and target events until all
  three exist, then clears them. It has no explicit source-age/clock-error bound
  in this function; output rate need not equal the target sensor's requested rate.
- Output retains the target's timestamp and `uptimeNanos`. The linked
  `DataCollectionEvent` constructor obtains the latter from `SensorEvent.timestamp`.
- `MotionDataCollectionEvent` exports only `timestamp,uptimeNanos,x,y,z`: no
  per-row Android accuracy, raw flags, matrix or contributing gravity/magnetic
  source timestamps are serialized by that class.

Android's [rotation-matrix contract](https://developer.android.com/reference/android/hardware/SensorManager#getRotationMatrix(float[],%20float[],%20float[],%20float[]))
uses an Earth/world basis: horizontal X approximately east, Y toward magnetic
north and Z upward. It does not define vehicle forward/left/up. The code and
[author's clarification](https://github.com/jair-jr/driverBehaviorDataset/issues/6#issuecomment-3417843238)
explain the intended conversion, but do not restore missing per-sample matrices,
vehicle heading, original values or source-quality evidence. The exact collection
build used for the 2016 recordings was not established from the current source.

The companion `apm_R/apm.R` loader supports optional sensor/GPS files and omits
missing ones. Its `calcularElapsedUptimeNanos` subtracts each data frame's first
`uptimeNanos`; this is not proof of a common trip/label origin. Do not adopt
independent per-file zeroing as verified synchronization or execute the publisher
pipeline to manufacture missing alignment. No publisher code was run or copied
into Traelyx.

## Disposition and next dependency

Ferreira remains useful as a research/diagnostic lead with documented permission,
units and acquisition code. The research report's approximately 51 Hz measurement
is not remeasured here. A 100 Hz analysis grid does not demand a 100 Hz raw sensor;
the [v2 development policy](EVENTNET_INPUT_QUALITY_V2.md) can retain bounded native
interpolation. That does not resolve frame, quality, label-origin, driver grouping
or normal-exposure gaps. No timing pilot is needed merely to reconfirm the known
frame/video limitations, and no sensor stream is opened by this unit.

For the current native feature contract, source admission remains false. Driver
mapping alone would not repair missing frame/quality information or create reviewed
normal intervals. Do not treat author permission as model acceptance or rotate
signals using event labels to obtain desired class signs. A future world-frame
or invariant-feature experiment would require its own explicit contract and
evaluation evidence; this review does not implement or authorize one.

The immediate corpus dependency remains independently reviewed driving exposure
with a usable feature/quality contract and independent evaluation groups. New
primary evidence or a separately governed compatible source is needed; no author
was contacted, no phone/emulator was used and no new drive is requested.

## Evidence and checks

The aggregate records primary URLs, public comment IDs, reviewed Git-blob IDs and
the four metadata schemas. It commits no source code bodies, trip wall times,
sensor values, private identifiers or external report copies. Metadata/annotation
review does not assign a train/validation/test role. Any future experiment must
disclose the external research report's existing trip-21 inspection.

Validation for this documentation-only unit is repository JSON/YAML/secret-name
validation, reference/provenance consistency and `git diff --check`. No product
code, dependency, schema, score, runtime or existing model result changes; native,
ML and device tests are not rerun or newly claimed by this review. M7.4/M7.5 remain
open and M8 remains inactive.
