# DRIVE_DNA_SPEC.md — Driver Profile Semantics

## When to read

Read when implementing scoring dimensions, long-term baselines, Drive DNA UI, comparison logic, or ML representations of driving style.

## 1. Purpose

Drive DNA is a multidimensional profile describing observed driving behavior across valid trips. It is designed to be more useful than a single opaque score and to recognize that two drivers can achieve similar aggregate quality with different styles.

Drive DNA does **not** claim to be a legal, medical, insurance, or universal driver-competence assessment.

## 2. Initial dimensions

Initial candidate dimensions:

### Smoothness
How gradually control inputs and vehicle motion change over time, considering jerk and transition behavior while avoiding simple punishment for every strong maneuver.

### Braking Control
Progressiveness, stability, repeated abrupt deceleration patterns, jerk, and recovery surrounding braking events.

### Acceleration Control
Progressiveness/consistency of positive longitudinal acceleration and transitions.

### Cornering Control
Consistency and smoothness of lateral-load buildup/release, yaw behavior, entry/exit transitions, and event confidence. High lateral load alone is not automatically "bad" or "good."

### Consistency
Variance in comparable behavior over segments/trips and stability relative to the user's established baseline.

### Anticipation (experimental until validated)
May represent patterns such as repeated late abrupt control changes versus earlier progressive transitions. Must not be presented until measurable from available telemetry with acceptable validity.

## 3. Evidence requirements

Each dimension must define:

- eligible input channels/events;
- minimum telemetry confidence;
- minimum duration/event count;
- how missing data is handled;
- vehicle/context normalization;
- personal baseline requirements;
- scoring version.

If there is insufficient evidence, show "insufficient data" rather than inventing a score.

## 4. Personalization lifecycle

Possible states:

1. **Uncalibrated** — insufficient valid driving history.
2. **Emerging** — baseline being formed; comparisons have larger uncertainty.
3. **Established** — sufficient valid history for meaningful personal comparisons.
4. **Recalibrating** — vehicle/mount/sensor change or long gap warrants baseline adjustment.

Do not overfit a driver's first few trips.

## 5. Vehicle-aware behavior

Drive DNA should account for vehicle class where materially relevant. A motorcycle, hatchback, and bus should not share naive thresholds.

Vehicle-specific personalization may gradually learn empirical distributions. Changes to vehicle selection should not silently contaminate another vehicle's baseline.

## 6. Historic reproducibility

Persist:

- Drive DNA/scoring schema version;
- dimension values;
- contributing evidence references or compact audit summary;
- confidence/eligibility state;
- vehicle profile ID;
- model versions involved.

Historical values should not silently change merely because a new scoring algorithm ships. A separate "recalculate with latest algorithm" feature could exist later.

## 7. Long-term trends

Useful outputs:

- rolling median/mean where statistically appropriate;
- percentage/absolute change vs last N valid trips;
- personal percentile relative to own history;
- streaks for consistent/smooth drives;
- variance and confidence.

Avoid false precision. A 0.1-point visual difference is not meaningful unless the scoring model justifies it.

## 8. ML embedding — later layer

A lightweight self-supervised encoder may eventually generate a compact driving-style embedding used for similarity/deviation detection.

Rules:

- embedding does not replace explainable dimensions;
- do not expose meaningless raw vectors to ordinary users;
- embeddings must be versioned;
- comparisons across incompatible model versions require migration/re-encoding or must be prevented;
- unusual deviation should be described cautiously, not as impairment/fatigue diagnosis.

## 9. UX language

Prefer:

- "Your braking was more abrupt than your recent baseline."
- "This was among your most consistent recent drives."

Avoid unsupported claims:

- "You are a bad driver."
- "You were distracted."
- "You were intoxicated/tired."

## 10. M4.5 implemented Drive DNA v1 baseline

Drive DNA version 1 is a deterministic local reducer over compact observations extracted from scoring-version-1 trip audits. It does not alter or recompute a trip score. The four direct profile dimensions are the robust median of fully eligible, integrity-verified trip dimension values in the caller-supplied comparable cohort. Eligibility is dimension-specific, so a trip may contribute one valid dimension without fabricating another.

A direct profile dimension requires at least five eligible trip observations. Empty, early, provisional, limited, questionable, unranked, or unavailable evidence cannot silently become a baseline value. Every dimension audit retains the exact contributing trip IDs, eligible/candidate counts, source values and states through the compact observation snapshot, mean absolute deviation from the median, producing configuration, and complete upstream version sets.

Profile consistency is distinct from scoring-v1's unavailable per-trip consistency slot. It requires at least three available direct profile dimensions and measures cross-trip stability: take each contributing dimension's mean absolute deviation from its median, average those deviations with deterministic half-up fixed-point arithmetic, then subtract twice that dispersion from 100 and clamp to 0–100. This governed synthetic formula is a descriptive stability baseline, not a probability or universal competence claim. It does not enter scoring-v1 overall or ranking eligibility.

Profile state is `complete` when all four direct dimensions plus consistency are available, `partial` when at least one dimension is available, and `unavailable` when none are available. These are evidence-completeness states, not the `uncalibrated`/`emerging`/`established`/`recalibrating` personalization lifecycle. M4.5 requires a caller-supplied comparable cohort but does not choose history, mix or partition vehicles, persist profiles, compare a driver with prior history, emit UI text, or implement lifecycle transitions; those boundaries remain M4.6+.

The exact machine-readable configuration is `docs/reference/drive-dna-v1.yaml`. Any change to eligibility, aggregation, dispersion, consistency conversion, or profile-state meaning requires a new Drive DNA version. Historical profile results must retain their original Drive DNA and scoring versions rather than silently changing after an update.
