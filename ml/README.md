# Local dataset registry and imports (M7.1)

Requires Python 3.12+ and its standard library only. No account, network,
package install or mobile change is required. The importer never downloads or
uploads data and never reads private recordings automatically.

```text
python ml/datasets.py validate
python -m unittest tests.tool.test_ml_datasets
python ml/datasets.py import --dataset traelyx-smoke --version 1
python ml/datasets.py import --dataset mendeley-driving-behavior --version 2 --source ml/data/private/m7-source-review/sensor_raw.csv
```

The public CSV must first be downloaded explicitly from its
[publisher's version-2 record](https://data.mendeley.com/datasets/jj3tw8kj6h/2).
Select `sensor_raw.csv` (113,754 bytes); the registry pins the publisher's
SHA-256. Verify the current license and preserve its attribution. No raw
third-party file is distributed in this repository. Keep source downloads in
ignored `ml/data/private/` as shown above.

Each import writes `samples.csv` and `manifest.json` to
`ml/data/private/imports/<dataset>--<version>--import-v1/`. That tree is ignored.
Existing imports are never overwritten. Failed imports do not publish a
result. The manifest includes the entire registry entry, its canonical hash,
the exact source hash/size, output hash, label/partition counts and versioned
preprocessing contract. Repeating with identical inputs in a separate private
workspace produces byte-identical files; no paths, wall-clock times or random
identities enter the output. Source values are parsed for validity and written
unchanged, without conversion, calibration, resampling, windowing or relabeling.

## Registered sources and limits

- **Mendeley Driving Behavior v3 (M7.2):** adds explicit driver/class/task IDs.
  Registry schema v2 permits only a source-space experiment with fixed grouping,
  clock stripping and coarse relative time. Version 2 remains quarantined. No
  production data/model eligibility follows. See the
  [EventNet contract](../docs/reference/EVENTNET_BASELINE_V1.md) for its isolated,
  optional CPU environment and held-out-driver experiment commands.

- **Mendeley Driving Behavior v2:** licensed public IMU data; rows have no
  driver/trip/time fields. Declared units require verification. Import all rows
  into `quarantine`, with empty driver/trip/time and `training_use: blocked`.
  Never infer sample times from a mean rate, split rows randomly, or treat its
  labels as crash truth. See the registry for citation, population and limits.
- **Traelyx smoke v1:** 558 generated samples, 18 short synthetic sequences,
  six arithmetic motion scenarios. Three fictional driver groups are assigned
  to train/validation/test before any future windowing. Labels describe whole
  scenarios, including quiet portions. Identical signal shapes across groups
  test plumbing only. `training_use: synthetic_only` forbids treating this as
  real-world model evaluation. Generated data is [CC0](DATA_LICENSE.md).

The existing governed **M3 corpus v1** remains in
`android/app/src/test/kotlin/io/github/atrx07/traelyx/telemetry/TelemetryRegressionFixtureCorpus.kt`.
Its native regression tests remain authoritative for decoder-to-replay behavior;
the new ML smoke corpus complements it and does not translate or replace it.
Private `.tripdebug` archives and maintainer trips remain outside this pipeline.

## Contracts and validation

Registry entries follow `docs/reference/dataset-registry.schema.json`, now
explicitly version 1; there were no earlier registry instances to migrate.
`datasets.py` evaluates the schema's bounded vocabulary and rejects unsupported
keywords, unknown fields, missing provenance, unsafe path tokens and promotion
claims. A schema extension must update its validator and tests together.

CSV parsing requires exact allowlisted columns, finite numerics, known source
labels, bounded file/row/field sizes, contiguous synthetic trips, increasing
elapsed time, stable trip provenance and a single partition per synthetic
driver. No real-driver partition is claimed for ungrouped public data. The
schema cannot authorize production model training. The separate v2 registry
contract permits only the reviewed source-v3 experiment; it does not waive
verified grouping/timing/units/labels/consent/licensing or locked-test requirements
for production promotion. V1 source bytes and import outputs remain reproducible.

Changing a source, generator, preprocessing meaning or split assignment requires
a new version and retained historical registry entry/output. Raw removal must
be user-directed; retain manifest provenance so affected experiments/models can
be identified. M7.2 is now explicitly authorized; later substeps/promotion retain
their own gates. Core registry/import commands remain standard-library-only.
