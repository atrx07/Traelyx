# EventNet public-source qualification v1

## When to read

Read before choosing data for the M7.4/M7.5 acceptance follow-up. This is a
source-qualification result, not a trained candidate or model acceptance. The
[active plan](../exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md) governs the
work. Historical EventNet v1 weights, splits, rejection and thresholds are intact.

## Protocol and boundaries

Before opening source data, qualification was limited to pinned licensed source
documentation, schemas and development inputs. Inspected raw samples are
qualification-exposed and must not later be described as unexamined test data.
Metadata/label review does not automatically exclude additional uninspected
motion streams or groups from a future frozen protocol. Qualification assigns
no training/evaluation split. No model is trained, selected, quantized or evaluated here.

`ml/qualify_eventnet_sources.py` uses the standard library only, has no networking
and accepts two explicit source profiles. Verify file length and SHA-256 before
parsing the immutable byte snapshot. Publisher MD5 checksums were also checked at
download; SHA-256 pins and reviewed aggregates are in the companion result.
Source bytes, wall times and sensor vectors remain ignored/local.

The SQLite profile is bounded to 16 MiB/200,000 rows and deserializes into memory,
with extensions disabled, trusted schema off, query-only mode, bounded VM work,
fixed queries and an explicit table/column allowlist. No source SQL, view, trigger,
WAL or sidecar is executed. It emits no raw time/vector/speed values. The label
profile is bounded to 16 KiB/1,000 intervals per file and checks exact columns,
finite decimal times, ordering, non-overlap, sequential sample IDs, constant sync
offset and label/target identity. The release's Portuguese non-aggressive spelling
and trailing whitespace are explicit aliases; no maneuver-to-Traelyx mapping is
inferred. Reported sync offsets are not verified cross-stream alignment.

Successful CLI exit means qualification completed. Every output still declines
current training, production evaluation and fresh locked evaluation admission,
and computes no model predictions. A later experiment must explicitly govern
eligible sources/groups and disclose inspection before assigning roles; these
outputs grant no automatic admission. Unknown metrics/exposure stay unavailable.

## Pinned-source findings — 2026-11-16

| Source | Findings | Acceptance dependency |
| --- | --- | --- |
| [Driving Events, Harvard Dataverse V1](https://doi.org/10.7910/DVN/F5JZHF), CC0-1.0 | 128,512 sensor rows, nine activity labels; `TIME` contains only time of day to whole seconds, with 125,780 adjacent equal-time pairs. No driver/trip or sensor/GNSS accuracy column. | Independent grouping, subsecond alignment, feature units/frame/quality, interval truth and ordinary-driving exposure are unverified. Idling rows do not establish normal-driving exposure. |
| [Driving Events Dataset, Zenodo 6570972 v1](https://zenodo.org/records/6570972), CC-BY-4.0 | 169 intervals across three trips; one publisher-reported driver. The 26 non-aggressive intervals total 129.037 seconds. Interval structure passes; motion streams have not been inspected. | A single driver cannot supply independent training/validation/test driver groups. Sparse labelled negatives are not continuously reviewed ordinary driving. Feature/sync/quality and road-impact/phone-movement truth remain unverified. |

The Harvard [primary paper](https://doi.org/10.12688/f1000research.73134.2)
describes dashboard-mounted Samsung Galaxy S10 collection and a nominal 100 ms
recording period. Its 87-byte README adds no driver/units/frame/annotation
contract. Neither the nominal rate nor row order reconstructs missing measured
subsecond timestamps. The paper's reported classifier accuracy is not a Traelyx
acceptance metric and its random window split is not adopted.

The Zenodo metadata/license/version were rechecked against its official API and
latest-version link. Only the three small label files were downloaded. Class
names remain publisher labels, including lane changes; they are not silently
converted into strong-corner or severe-event truth. Unlabelled trip time remains
unlabelled. One trip lacks some maneuver classes, so trip splitting would also
need class-coverage checks even if it provided independent drivers.

Attribution: Goh, Vik Tor; Jamal Mohd Lokman, Eilham Hakimie; Yap, Timothy Tzen Vun;
Ng, Hu (2021), *Driving Events*, Harvard Dataverse V1, DOI 10.7910/DVN/F5JZHF,
CC0-1.0. Escottá, Álvaro Teixeira; Beccaro, Wesley (2022), *Driving Events Dataset:
a smartphone inertial measurement unit for driving events*, v1, DOI
10.5281/zenodo.6570972, [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/).
No endorsement implied. Source files were not modified or redistributed.

## Reproduction and validation

```text
python -m ml.qualify_eventnet_sources --source harvard-f5jzhf-v1 --input <ignored-pinned-database>
python -m ml.qualify_eventnet_sources --source zenodo-6570972-v1-labels --input <ignored-directory-with-three-pinned-label-files>
python -W error::ResourceWarning -m unittest tests.tool.test_qualify_eventnet_sources
```

All 131 local Python tests pass, including 11 new generated-data regressions for
numeric/time/label integrity, explicit UTF-8 aliases, bounds, schema/SQL-object
rejection, pinned source preservation, output privacy and false admission.
Both real pinned-source qualification commands pass. All four
[source CI jobs](https://github.com/atrx07/Traelyx/actions/runs/43911237347) pass for
`da80f6a` on attempt 3. Earlier attempts stopped at an invalid NDK download and
SQLite asset API HTTP 403; source, versions, checksums and checks were unchanged. See
[aggregate evidence](eventnet-public-qualification-v1-result.json).

## Next acceptance work

Neither source is admitted to a production model split. Other metadata leads
remain in [recording intake v1](EVENTNET_RECORDING_INTAKE_V1.md); this is not an
exhaustive search or proof that no suitable public source exists.

The maintainer confirmed a Redmi Note 9 / Android 10 can install an APK and export
manually without ADB, and subsequently supplied a valid stationary export. The
[stationary phone check](M7_MANUAL_PHONE_QUALITY_CHECK.md) verifies 92 chunks,
9,305 accelerometer and 9,300 gyro samples, all status 3 without recorded flags;
GNSS is absent. Original and ignored private copy match. This establishes this
session's motion status and record/export path, not driving-event truth, GPS
recovery, driver diversity or sustained battery acceptance. Further trips are
unavailable this week; Redmi remains a fallback. M7.4/M7.5 remain open and M8
stays inactive.

## Additional metadata leads

- [Q-Motion V1](https://doi.org/10.17632/p5376m6xfc.1): official DOI metadata
  records CC-BY-NC-4.0. Publisher-checksummed annotation/quality documents were read
  without downloading the 5.05 GB telemetry ZIP. Passenger labels cover perceived
  aggressive maneuvers with approximate timing; normal sessions were not manually
  annotated, and missed aggressive events are possible. Unlabelled intervals
  cannot become verified negatives. License/distribution, feature/group and
  independent-negative acceptance remain unresolved. The anonymous file-list API
  works despite the page's failing author-profile lookup; no gated terms accepted.
- [Schuster maneuverRecognition](https://github.com/Schuster-j/maneuverRecognition):
  its README describes three drivers, manual dashcam maneuver labels and 2 Hz
  smartphone streams. Explicit data licensing was not established; no raw data
  downloaded. Maneuver type does not automatically establish strong-event truth.
- The original [Ferreira dataset repository](https://github.com/jair-jr/driverBehaviorDataset)
  is linked by its primary PLOS paper; the earlier reviewed `umi001` repository
  is a fork. Neither reviewed page establishes an explicit dataset license.
  Paper access/copyright alone is not recorded as a grant for repository data.

These remain metadata/documentation leads, not production training admissions.
