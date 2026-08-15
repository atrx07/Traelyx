# ADR-0014 — Categorical, metric-scoped telemetry confidence

**Status:** Accepted

## Context

M3.6 must propagate GNSS, IMU, calibration, orientation, device-movement, source-agreement, and clock quality into later event, scoring, integrity, and replay work. A single confidence percentage would imply statistical calibration that Traelyx does not yet possess and would also let one unavailable source unnecessarily poison independent healthy channels. Conversely, exposing raw flags without governed eligibility would force every downstream consumer to reinterpret the same evidence differently.

## Decision

Traelyx telemetry confidence version 1 uses categorical `supported`, `degraded`, `unavailable`, and `invalidated` component states with machine-readable reasons and retained upstream evidence. It does not produce a global percentage.

Eligibility is aggregated per metric as `eligible`, `limited`, or `excluded`. GNSS-dependent metrics and vehicle-frame IMU metrics consume only their relevant components, so one sensor failure cannot erase independent healthy evidence. A separate corroborated-vehicle-motion aggregate requires confirmed movement, available GNSS and inertial channels, calibration/orientation/device stability, source agreement, and clock integrity.

Yaw/heading disagreement is cross-sensor evidence, not a verdict about which sensor is correct and not a crash, fraud, or safety decision. Version-1 preferred-quality and agreement thresholds are explicit configuration: 15 m preferred GNSS horizontal accuracy, at most one-second source age for agreement, and at most 0.5 rad/s absolute yaw/heading-rate difference. These thresholds create auditable quality tiers and do not claim calibrated probabilities.

Confidence stays in the native local telemetry boundary in M3.6. It does not rewrite raw or derived evidence, cross the Flutter bridge, or introduce persistence.

## Consequences

Positive:

- downstream scoring and events can weaken or exclude evidence consistently and explain why;
- missing, degraded, invalidated, and conflicting sources remain distinguishable;
- healthy GNSS or IMU evidence survives unrelated-source failure;
- algorithm versions and thresholds remain reproducible without false precision.

Negative:

- consumers must handle component and eligibility records rather than one convenient number;
- categorical tiers and agreement limits still require physical multi-device calibration;
- corroborated motion is intentionally unavailable when independent sources cannot be compared.

## Revisit if

Governed fixture and multi-device evidence supports statistically calibrated probabilities, new independent orientation sources change agreement semantics, or downstream safety requirements demand a separately validated corroboration policy. Any change must preserve versioned historical reproducibility.
