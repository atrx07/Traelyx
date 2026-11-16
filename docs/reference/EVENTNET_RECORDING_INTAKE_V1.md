# EventNet recording intake v1

## When to read

Read while working on M7.4/M7.5 acceptance, before treating a private recording as
training or evaluation evidence. This is a diagnostic intake contract, not a new
accepted model, training protocol or promotion waiver. The [active follow-up](../exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md)
governs the remaining work. Frozen EventNet v1 exports/results remain unchanged.

## Upstream handling review and phone result — 2026-11-16

Before phone access, `origin/main` was fetched and checked at `6582922`; the
repository has no separate upstream remote. Reviewed the upstream M2.8 field
record, M5 preservation/export record, M6 recovery plan, storage spec and
[precise-private archive contract](TRIPDEBUG_FORMAT.md).

The authorized physical Tecno (Android 34) was inspected read-only with an inactive
recorder. Its seven recorder directories contain 11,865 chunks. All 11,857 original
chunks match the preserved local recovery backup byte-for-byte; the eight added
chunks belong to the maintainer's already excluded accidental recording. That
recording was preserved and not selected. No app update, recording, force-stop,
radio/account/Guardian operation, database query or device write was performed.

The matching local backup was used for quality inspection, avoiding another
copy of phone telemetry. Only recorder chunks were decoded; backup metadata and
database entries were not extracted or interpreted. The whole backup is read for
checksum verification, so this is not a claim that hashing skips database bytes.
All source paths, device/trip identifiers, raw vectors, routes, source times and
per-recording output remain ignored/local. Only reviewed aggregates are recorded
here and in [the intake result](eventnet-recording-intake-v1-result.json).

**The old recordings are not enough to close M7.4/M7.5.** Six original recordings
span approximately 129.21 archived minutes and contain 1,471,506 accelerometer
samples; every one retains Android accuracy status 0 (`UNRELIABLE`). Gyroscope
samples remain independently available. One recording has no GNSS; another has
an approximately 680-second maximum GNSS coverage gap. These are measured source
limitations, not labels inferred from the data and not proof of a broken sensor.

The M2.8 record explicitly describes a pocket-carried motorcycle trip, unknown
vehicle frame and approximate rider notes. It disclaims confirmed event truth.
M5 UI/replay acceptance preserved old recordings; it did not establish new
independent event annotations. Previous inspection/replay also prevents claiming
these are a fresh unseen evaluation set. More rows or a longer trip cannot repair
unknown labels, frame, driver grouping or source quality by themselves.

Keep these recordings as quality/abstention, storage/decoder, replay and legacy
compatibility evidence. Do not assign normal labels to unlabelled intervals, strip
unreliable flags, pretend pocket axes are vehicle axes, or move these bytes into
an accepted train/test split. No new private recording has been uploaded,
published, trained on or admitted by this work.

## Implemented host tool

`tool/inspect_ml_recordings.py` accepts an explicitly selected, checksum-pinned,
uncompressed private recorder TAR backup. It uses the existing native-v1 chunk
decoder and has no network access or non-standard-library dependency.

```text
python tool/inspect_ml_recordings.py --backup <ignored-private-backup.tar> --expected-sha256 <sha256> --excluded-trips <ignored-exclusion-ledger.json>
```

The exclusion ledger is the existing private version 1 maintainer ledger; the tool
uses its trip IDs/preservation flags without emitting those IDs or editing it.
Excluded recordings are structurally verified but never selected for acceptance.
No tar member is extracted. Only fixed recorder chunk paths are decoded; links,
duplicate identities, unknown recorder entries, gaps, unsupported versions,
corruption and reordered timelines fail closed. Known finalization/active-state
metadata is skipped and finalization state stays `not_assessed`.

The tool verifies the expected SHA-256 before and after inspection using the same
open descriptor, and checks size/mtime. It does not follow archive paths into the
filesystem. Limits: 512 MiB input, 100,000 members, 64 recordings, 10,000 chunks per
recording and existing 4 MiB encoded/16 MiB decoded chunk bounds. Decompression now
enforces its limit during inflation and rejects unfinished/trailing streams,
rather than checking the limit only after unbounded allocation. Archive format,
telemetry/chunk versions and valid legacy inspector output remain unchanged.

Output contains only ordinal recording numbers, counts, archived spans, channel
coverage gaps, Android accuracy distributions, flagged/mock counts and explicit
blocking evidence. It is `aggregate_private_diagnostic`, not anonymized/public
data. Runtime failures print no source path or exception details. The default
admission fields are always false: this tool does not verify consent for training,
mounting, labels, driver identity or a held-out experimental protocol.

## What is needed next

1. **Qualify a public source and its sensor/frame pipeline.** The maintainer
   reports permanent Tecno damage and no available second ADB phone. Public data
   is the primary route; another Tecno drive is not a prerequisite for this work.
   Verify explicit units, gravity semantics, source quality, timing and vehicle
   orientation under the existing M3 contract before admitting features.
2. **Obtain appropriate independent labels and normal exposure.** Consent/source
   provenance, driver/trip/device/mount grouping, synchronised event intervals,
   label confidence and reviewed negative intervals are required. Existing rule
   detections may be weak labels, never independent truth for beating those rules.
   Do not request dangerous public-road maneuvers or manufacture crash labels.
3. **Freeze the follow-up before evaluating it.** Establish the exact production
   feature units/frame/timing/missing-quality contract and governed event mapping;
   assign driver-held-out training/validation/unseen evaluation groups before
   windows; predeclare model/runtime/export configurations and quality, parity,
   efficiency and calibration/value gates before opening the held-out partition.
   Old v1 numerical rejection remains retained. No alternate quantizer was tried
   against the old observed test set in this intake.
4. **Then complete M7.4 and M7.5 in dependency order.** Accepted numerical export,
   calibrated per-class/false severe-event evidence, real size/CPU/memory/battery
   and device acceptance precede production model integration and explicit
   promotion/rollback. Integration must preserve explicit scoring/Guardian policy.

## Maintainer six-face desk observations

The maintainer confirmed Physics Toolbox reports g (total about 1 at rest).
Opposing-face pairs suggest device-axis offsets of approximately
(+0.005, +0.005, +0.04) g and raw reading gains of (0.995, 0.995, 0.99).
A candidate diagnostic conversion would be `(raw - offset) / reading_gain`,
with offset converted by 9.80665 when raw acceleration uses m/s². This applies
only to raw device accelerometer axes, never directly to gravity-subtracted or
vehicle-frame features. These rounded observations leave residual cross-axis
values up to about 0.0202 g after that fit; face alignment is uncertain.

This proposal is not accepted calibration or evidence that a single constant
offset corrects historical trips. It does not repair pocket mounting, independent
labels, missing GNSS or Android status 0. Existing M3 stationary-mean subtraction
already cancels a constant additive offset at the calibration orientation;
applying this proposal again to those derived features would double-correct.
Raw observations and the proposed transform remain ignored/local. No archived
sample, production algorithm, historical result or quality flag was changed.

## Public-source metadata review

No new raw dataset or held-out partition was downloaded. Primary metadata was
reviewed for alternatives; these are leads, not admitted datasets:

- [Zenodo driving events 6570972](https://zenodo.org/records/6570972): official API
  metadata declares CC-BY-4.0; one driver, three trips, 169 labelled events.
  Potential external pilot, but a single driver cannot alone supply independent
  train/validation/test driver groups. Frame, quality and annotation suitability
  still need verification under a frozen protocol.
- [Original driverBehaviorDataset repository](https://github.com/umi001/driverBehaviorDataset):
  timestamped event intervals and smartphone streams from two drivers/four trips
  are documented. No explicit license was found in the repository page reviewed;
  do not equate public GitHub access with permission for model distribution.
- [DriverSVT 7385340](https://zenodo.org/records/7385340): official API metadata
  declares CC-BY-4.0 and the record describes 633 drivers. Its published description
  includes neural-derived driver-state attributes; those are not verified Traelyx
  maneuver/severe-event ground truth. Do not download the 9.1 GB CSV just for its
  row count or infer event labels from those attributes.
- [STRIDE v4](https://doi.org/10.6084/m9.figshare.25460755.v4): the Figshare API
  declares the dataset CC-BY-4.0 (separately from its paper's license). The
  [primary paper](https://www.nature.com/articles/s41597-024-04193-0) describes
  mounted smartphone streams from three drivers, driving-style and road-anomaly
  labels. These do not establish independently reviewed maneuver/severe-event
  intervals or accepted Traelyx production features. No raw file downloaded.
- [UAH-DriveSet official page](https://www.robesafe.uah.es/personal/eduardo.romera/uah-driveset/)
  returned 502 during this review; current licensing/admission was not established.
- [DriveDNA/CANTraj release](https://huggingface.co/datasets/HenryYHW/CANTraj)
  declares gated research-only terms and CAN/GNSS provenance. No terms accepted,
  gated file accessed or raw data downloaded; it is not an accepted phone-feature
  or independently labelled maneuver source for this follow-up.

No claim is made that this small source review exhausts all possible datasets.
Data eligibility, rather than another run on the old test set, is the current
dependency. M8 and production model activation remain inactive.
