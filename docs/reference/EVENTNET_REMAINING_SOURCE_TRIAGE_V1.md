# EventNet remaining-source triage v1

## When to read

Read before restarting the external report's dataset search or proposing a new
M7 acceptance experiment. This bounded review covers 15 remaining main and
supplementary leads using primary documentation, permission statements and
schemas. It opens no recording archive and assigns no experiment split. See the
[aggregate decision and source pins](eventnet-remaining-source-triage-v1-result.json),
[native input contract](EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md),
[v2 quality policy](EVENTNET_INPUT_QUALITY_V2.md) and
[active plan](../exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md).

## Decision — 2026-11-17

**No candidate establishes all acceptance prerequisites in the evidence reviewed.**
Do not start another model fit or continue an unbounded search through the same
report. This is a bounded evidence decision, not a claim that a suitable dataset
cannot exist. Unknown metadata is unresolved, not proof that information was
never collected. Existing rejected models/results and M7.4/M7.5 gates stand.

Admission needs compatible input semantics/quality, independently reviewed event
and ordinary-driving exposure, independent driver groups and permission for the
intended use. A standard licence is not the only possible permission evidence;
the [Ferreira review](FERREIRA_SOURCE_REVIEW_V1.md) records a custom author grant.
Non-commercial permission can support restricted research, but is not unrestricted
app/model distribution approval. This review does not decide that Traelyx is a
commercial use or that every trained model has identical licence obligations.

## Candidate decisions

Each linked source was inspected in this pass. Stop reasons refer to the current
acceptance contract, not all possible scientific uses of a dataset.

| Candidate / primary evidence | Useful evidence | Decisive unresolved or incompatible evidence |
| --- | --- | --- |
| [Schuster maneuverRecognition](https://arxiv.org/html/2506.23147v1) / [README](https://github.com/Schuster-j/maneuverRecognition) | Manual dashcam maneuver classes, continuous-driving category, three persons/vehicles and documented units. | Published rows captured every 500 ms exceed the native 50 ms bracket ceiling. Dataset permission, severe-event truth and active normal-interval review are not established. A shared route and one vehicle per person confound evaluation. |
| [UAH-DriveSet](http://www.robesafe.uah.es/personal/eduardo.romera/uah-driveset/) | Six drivers/vehicles, performed trip styles, sensor/video review tool and explicit custom permission. | App-generated maneuver scoring and instructed trip styles do not establish independent interval event/normal truth. Native gyro/frame/quality contract is not established by the page. Terms restrict use to non-commercial purposes and prohibit raw/modified dataset redistribution; abstract derivatives have conditions. |
| [Honda HDD](https://usa.honda-ri.com/hdd) | Instrumented driving and behavior/video examples. | Access requires university affiliation/email and a request; use is non-commercial. Driver mapping and native inputs/independent normal evidence are not established by the page. No request was submitted. |
| [Brain4Cars paper](https://arxiv.org/html/1601.00740) / [repository](https://github.com/asheshjain399/ICCV2015_Brain4Cars) | Manual lane-change/turn starts and sampled straight-driving events: affirmative straight-label evidence. | The paper's released modalities are video, GPS and speed, not an established compatible accel/gyro contract. Straight maneuvers are not automatically reviewed severe-event-free exposure. Repository terms explicitly restrict code/data to educational/non-commercial purposes. |
| [KITTI Raw](https://www.cvlibs.net/datasets/kitti/raw_data.php) | GPS/IMU, calibration, raw/synchronized variants and timestamps. | Published labels describe object tracklets, not the required maneuver/normal truth or driver mapping. The synchronized representation is 10 Hz; this does not prove the original unsynchronized IMU is limited to 10 Hz. No login/download or intended-use permission review was performed. |
| [comma2k19](https://github.com/commaai/comma2k19) | Phone-like EON IMU, boot-time arrays, forward/right/down basis, gyro bias outputs, CAN and video. | No independent maneuver/normal annotation or driver mapping established. Two vehicle/dongle groups are not two verified drivers. MIT text defines software/documentation; a recording/data grant remains unresolved. Native preprocessing/quality equivalence is unverified. |
| [KAIST Complex Urban](https://sites.google.com/view/complex-urban-dataset) / [format](https://sites.google.com/view/complex-urban-dataset/format) | ROS clocks, calibration and later gyro/acceleration streams. | Early sequences have only orientation; versions cannot be mixed as equivalent IMU. Independent event/normal labels and driver groups are not established. Publisher states CC BY-NC-SA 4.0. |
| [Ford Multi-AV Seasonal](https://registry.opendata.aws/ford-multi-av-seasonal/) | Ford-managed registry describes vehicle IMU, calibration, ROS bags and pose/map truth. | Pose truth is not event/normal truth; driver groups and phone/native equivalence are unverified. Registry states non-commercial academic use and CC BY-NC-SA 4.0. |
| [Drive360 challenge](https://www.aicrowd.com/challenges/iccv-2019-learning-to-drive-challenge) / [paper](https://arxiv.org/html/1803.10158v2) | Paper describes 200 Hz GoPro IMU acquisition. Challenge publishes camera/maps and 10 Hz future CAN control targets. | Acquisition does not prove native-compatible IMU is distributed in the challenge. Steering/speed prediction and route/chapter splits are not independent event/normal truth or driver-held-out evaluation. No credentials were retrieved. |
| [V-SenseDrive-PK accepted article](https://link.springer.com/article/10.1007/s44196-026-01657-6) | Four drivers, 10 Hz phone IMU and measured video alignment; useful acquisition/label-leakage evidence. | Authors identify released rule labels as largely speed bands. Enacted trip styles are separate from independent maneuver/normal annotations. Raw logs/video/code are described as on request. Article licensing is not automatically a dataset grant. |
| [Wawage / Deshpande v2](https://data.mendeley.com/datasets/9vr83n7z5j/2) | CC BY 4.0, nominal default 50 Hz, accel/gyro units and three drivers/cars documented. | Independent event/normal label procedure, driver-to-file mapping and native frame/gravity/quality evidence are not established by the metadata. We did not verify the report's stronger assertion that all released files lack labels. |
| [Kaggle Large-Scale v1](https://www.kaggle.com/datasets/shakilofficial0/large-scale-driver-behavior-sensor-dataset/versions/1) | Official metadata now establishes CC BY-NC-SA 4.0; describes gravity-removed accel/gyro. | Two samples/s cannot meet current native timing. Preassigned style labels lack established independent provenance; driver grouping is unresolved. Relative/1970-derived dates alone do not establish clock corruption. |
| [Kaggle Popescu / Cojocaru v2](https://www.kaggle.com/datasets/outofskills/driving-behavior/versions/2) / [paper](https://rochi.utcluj.ro/articole/10/RoCHI2022-Cojocaru-I-1.pdf) | Official metadata establishes CC BY 4.0; paper documents collection and units. | Two samples/s and publisher gravity removal do not satisfy native input semantics. Labels inherit separate enacted style rides, not independently annotated maneuver/normal intervals; driver grouping is unverified. |
| [Nazirkar v1](https://data.mendeley.com/datasets/5stn873wft/1) | CC BY 4.0; dashboard phone recordings and merged-file normal/aggressive labels documented. | No established units/rate/gravity/frame/clock contract, independent label procedure or driver mapping. Two source filenames do not establish two drivers. |
| [Zenseact Open Dataset](https://zod.zenseact.com/) | Publisher permits commercial/non-commercial use under CC BY-SA 4.0; 100 Hz GNSS/IMU, 50 Hz consumer vehicle IMU and controls documented. | Listed annotations concern objects/lanes/roads/signs/surfaces. Independent maneuver/normal labels, driver mapping and native phone input/quality equivalence remain unverified. Licence obligations still need intended-use review. |

## Corrections and evidence limits

- Kaggle's rendered pages exposed no readable metadata to the web tool. Its
  official public dataset-view APIs returned licence fields, versions and total
  sizes without authentication or recording download. Popescu v2 is CC BY 4.0;
  Large-Scale v1 is CC BY-NC-SA 4.0. These correct the report's unknown-licence
  conclusions. Byte totals are publisher metadata, not measured downloads.
- The Large-Scale description expressly calls its dates relative session time.
  Epoch-1970 rendering is not itself fake data or corruption. Missing session
  grouping/alignment remains unresolved; this review does not compute its timing.
- Prefer the newer 2026 accepted V-SenseDrive article's explicit speed-label
  limitations over optimistic claims in the 2025 preprint. Neither establishes
  independent EventNet maneuver truth from the existing labels.
- Approximately 50 Hz raw input is not inherently excluded by a 100 Hz analysis
  grid. Actual gaps/provenance must satisfy the bounded policy. Two-Hz inputs
  cannot be restored by filling 500 ms intervals into that policy. No raw timing
  distribution is remeasured in this documentation pass.
- UAH web-tool retrieval timed out; its direct public HTTP terms page succeeded.
  Kaggle API responses succeeded with an explicit review user agent; one follow-up
  without that header returned 404. Preserve successful evidence and access limits
  without inferring withdrawal. Wawage paper retrieval was blocked; its affirmative
  dataset metadata is verified, while file/label contents remain uninspected.
- GitHub README previews included illustrative sensor rows. This is disclosed
  documentation/qualification exposure, not an untouched test set. No new sensor
  CSV, recording archive or video was retrieved, and no publisher code executed.

The earlier Ferreira, Q-Motion, Zenodo, Harvard and VTTI audits remain authoritative
within their recorded limits. The external report's other excluded/gated sources
are not exhaustively re-audited here. This review neither validates every report
claim nor searches every possible dataset.

## Next evidence needed

The next useful unit is a concrete collection/annotation and evaluation protocol,
not another fit on weak labels. It must specify independently reviewed ordinary
driving and natural events, compatible sensor/clock/quality evidence, distinct
driver groups, review uncertainty, exposure duration and locked evaluation before
feature/model inspection. No new drive is requested by this review. The Redmi
remains a later manual-export option when available; only its stationary QA is
verified, not driving/GNSS performance.

The subsequently prepared [v1 collection/review packet](EVENTNET_EVIDENCE_COLLECTION_V1.md)
now specifies that procedure and empty templates. Collection and experiment
activation remain deferred; unresolved resources and numeric gates are explicit.

Public video-plus-IMU sources such as comma2k19 or ZOD could only become new
annotation projects after resolving permission, driver mapping, feature/quality
equivalence and review access. They are not selected or admitted now. Pairing
labels from one corpus with IMU from unrelated drives cannot manufacture joint
accuracy, false-severe/hour or latency evidence. Device benchmarking alone cannot
repair missing truth, and no phone/emulator is required for this triage.

## Checks and impact

Validate repository contracts, source-pin/metadata/reference consistency and
whitespace; review the exact diff and persist status together. Runtime/model/device
tests are not rerun for documentation-only changes. No new dependency, migration,
model weights, product behavior, private telemetry access, author contact or terms
acceptance. M7.4/M7.5 stay open and M8 stays inactive.
