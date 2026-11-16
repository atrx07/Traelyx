# EventNet public-source qualification v1

## When to read

Read before choosing data for the M7.4/M7.5 acceptance follow-up. This is a
source-qualification result, not a trained candidate or model acceptance. The
[active plan](../exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md) governs the
work. Historical EventNet v1 weights, splits, rejection and thresholds are intact.

## Protocol and boundaries

Before opening source data, qualification was limited to pinned licensed source
documentation, schemas and development inputs. All inspected inputs are
qualification/development-only; they cannot later be described as a fresh locked
evaluation partition. No model is trained, selected, quantized or evaluated here.

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

Successful CLI exit means qualification completed. Every output still has
training, production evaluation, fresh locked evaluation and model predictions
disabled. Unknown metrics/exposure stay unavailable; they are never zero.

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
unlabelled. Two trips lack some maneuver classes, so trip splitting would also
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
Both real pinned-source qualification commands pass. CI is pending. See
[aggregate evidence](eventnet-public-qualification-v1-result.json).

## Next acceptance work

Neither source is admitted to a production model split. Other metadata leads
remain in [recording intake v1](EVENTNET_RECORDING_INTAKE_V1.md); this is not an
exhaustive search or proof that no suitable public source exists.

The maintainer confirmed a Redmi Note 9 / Android 10 can install an APK and export
manually without ADB. The [stationary phone check](M7_MANUAL_PHONE_QUALITY_CHECK.md)
can establish source sensor status/timing availability on that device. It cannot
provide driving-event truth, driver diversity or sustained battery acceptance.
Further field collection remains a separate decision; no drive is requested by
this unit. M7.4/M7.5 remain open and M8 stays inactive.
