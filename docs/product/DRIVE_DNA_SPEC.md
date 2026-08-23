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

Profile state is `complete` when all four direct dimensions plus consistency are available, `partial` when at least one dimension is available, and `unavailable` when none are available. These are evidence-completeness states, not the `uncalibrated`/`emerging`/`established`/`recalibrating` personalization lifecycle. The M4.5 reducer itself still requires a caller-supplied comparable cohort; M4.6 selects that cohort without changing M4.5 aggregation semantics.

The exact machine-readable configuration is `docs/reference/drive-dna-v1.yaml`. Any change to eligibility, aggregation, dispersion, consistency conversion, or profile-state meaning requires a new Drive DNA version. Historical profile results must retain their original Drive DNA and scoring versions rather than silently changing after an update.

## 11. M4.6 implemented personal/vehicle lifecycle v1

Lifecycle version 1 is a deterministic local reducer over compact M4.5 trip observations. It orders candidates by completion time and trip ID, rejects duplicate trip IDs or future evidence, and selects a cohort only from the exact personal scope, vehicle profile, vehicle class, mount context, and sensor context requested by the caller. Personal scope and context values are opaque local application keys; they must not be derived from hardware serials, advertising identifiers, route fingerprints, or a required cloud identity.

A lifecycle-valid observation must contain at least one fully eligible, integrity-verified direct dimension. This preserves M4.5's dimension-specific evidence rule: a trip may help one dimension without fabricating another. Fully provisional, non-verified, or entirely unavailable evidence does not advance the lifecycle. The current cohort contains at most the latest 30 valid observations after the most recent inactivity gap longer than 90 days.

`Uncalibrated` means no current eligible observation and no active change trigger. `Emerging` begins with one current observation but cannot become established merely because an early M4.5 profile happens to be numerically complete. `Established` requires at least ten current observations and a complete M4.5 profile. Vehicle profile/class, mount context, sensor context, or long-inactivity changes produce `recalibrating` until the fresh cohort meets that established gate. Separate vehicle profiles never share evidence, and returning to an already established vehicle cohort may restore established state without rewriting it.

Every result retains the immutable candidate observations, per-candidate inclusion/exclusion decisions, selected trip IDs, current epoch/window bounds, active recalibration reasons, personal/vehicle/context scope, previous active vehicle scope, exact lifecycle and Drive DNA configuration, and all upstream source versions. The exact contract is `docs/reference/drive-dna-lifecycle-v1.yaml`.

M4.6 does not persist baselines, recompute historical trip scores/profiles, change scoring-v1 or ranking eligibility, add a Flutter bridge/UI, produce user-facing comparisons or explanation text, use ML, require an account/network, or change recording/sensor behavior. The existing schema-v1 `driver_baselines` shape can represent a later persisted snapshot, so no migration is justified here. The one/ten/thirty-observation and 90-day values are governed synthetic defaults, not population-calibrated thresholds; semantic changes require a new lifecycle version rather than rewriting history.

## 12. M4.7 implemented Drive DNA explanation data

Explanation version 1 maps all five M4.5 profile dimensions and the M4.6 lifecycle audit into deterministic presentation-ready reason paths. A dimension path retains its evidence state/value, candidate and eligible counts, exact contributing trip IDs, dispersion evidence, consistency inputs, and every unavailable reason. The lifecycle path retains its state, candidate/current/selected counts, selected IDs and time window, every active recalibration trigger, and excluded trip IDs grouped by their governed exclusion reason. Every candidate trip remains source-referenced even when excluded.

The explanation audit retains the complete M4.5/M4.6 and upstream scoring, integrity, raw, derived, confidence, taxonomy, and merge version sets. It does not compare a current trip to the baseline, invent percentile/precision claims, localize copy, render UI, persist a baseline, or alter cohort selection and aggregation. The exact contract is `docs/reference/explanation-v1.yaml`; M5 may render these stable keys and typed values without treating commentary as evidence.
