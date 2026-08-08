# VEHICLE_PROFILE_SPEC.md — Vehicle Profiles & Class-Aware Analysis

## When to read

Read when adding vehicle fields, calibration/baselines, vehicle-aware scoring, or selection UX.

## 1. Principle

Vehicle profiles improve analysis without demanding sensitive registration identity.

## 2. MVP fields

- local/cloud ID;
- user-defined display name;
- vehicle type/class;
- optional manufacturer;
- optional model;
- optional year;
- optional notes;
- active/default status.

Do not require registration number, VIN, insurance details, chassis number, or ownership proof for ordinary use.

## 3. Classes

At minimum distinguish motorcycle and car if telemetry calibration demonstrates meaningful differences. Additional classes should be data-driven rather than decorative.

## 4. Baselines

Personal Drive DNA baseline should prefer same vehicle profile. Switching vehicle must not silently mix calibration/statistics unless explicitly designed.

## 5. Mount/device changes

A vehicle profile is not equal to a phone mount profile. If mount/orientation materially affects sensor behavior, track calibration/device context separately.

## 6. Ranking

Rankings may compare within vehicle classes when that improves fairness/interpretability. Avoid fake precision from tiny cohorts.
