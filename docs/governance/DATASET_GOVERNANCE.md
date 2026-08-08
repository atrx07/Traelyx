# DATASET_GOVERNANCE.md — Telemetry Dataset Policy

## When to read

Read when importing public datasets, adding real-drive fixtures, collecting user labels, publishing a dataset, or training ML.

## 1. Dataset registry

Every dataset used for production training needs a registry entry including:

- dataset ID/version;
- source;
- license;
- consent/provenance;
- sensor types/rates;
- vehicle/device population;
- label definitions;
- preprocessing version;
- privacy transformations;
- known biases/limitations.

## 2. Public datasets

Verify license permits the intended training/distribution. Preserve attribution requirements. Public datasets can bootstrap but do not automatically represent our user/device/motorcycle population.

## 3. Maintainer/real-drive data

Before committing real trip fixtures:

- remove account/name/device identifiers not needed;
- transform/remove precise location if not needed;
- inspect metadata for home/work leakage;
- document scenario label and consent/source.

## 4. User-contributed data

Must be opt-in and separate from ordinary account terms.

Prefer contribution of short event windows with location stripped rather than whole routes where feasible.

## 5. Label quality

Labels may be:

- self-correction after drive;
- controlled experiment notes;
- expert/manual annotation;
- weak labels from deterministic rules;
- public dataset labels.

Store label provenance/confidence.

## 6. Splitting

Split by driver/group before windowing where possible to prevent leakage. Keep a locked test set not used for tuning.

## 7. Safety

Do not intentionally collect dangerous maneuvers on public roads. Use controlled conditions or naturally occurring events.

## 8. Retention/removal

If contributed data must be removed for policy/consent reasons, maintain enough provenance to identify affected training sets/models and retrain where necessary.
