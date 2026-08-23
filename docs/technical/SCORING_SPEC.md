# SCORING_SPEC.md — Explainable Versioned Scoring

## When to read

Read for any change to overall score, Drive DNA dimensions, penalties/bonuses, baseline normalization, confidence handling, historical comparison, or ranking eligibility.

## 1. Core rule

**ML must not directly output the final driving score.**

ML may supply evidence probabilities/embeddings. Explicit, testable scoring logic converts validated evidence into user-visible dimensions.

## 2. Goals

Scoring should be:

- reproducible;
- explainable;
- robust to sensor noise;
- vehicle-aware where justified;
- confidence-aware;
- personalized over time without making early trips meaningless;
- difficult to game;
- not designed to reward reckless speed.

## 3. Version

Every scored trip stores `scoring_version`.

Historical scores remain tied to the algorithm version used at the time. Never silently recompute all history on app update.

## 4. Dimension contract

Every dimension definition must specify:

- range (e.g., 0–100 display scale);
- eligibility/minimum evidence;
- inputs;
- normalization/baseline;
- penalty terms;
- bonus/positive terms;
- confidence weighting;
- caps/floors;
- vehicle-class rules;
- explanation output;
- version.

## 5. Example braking structure — conceptual only

```text
Braking Control = base
  - excessive jerk contribution
  - abrupt-transition contribution
  - repeated-event contribution
  + progressive-control contribution
  + stable-recovery contribution
```

Exact formulas/weights must be derived from data/testing and move into versioned machine-readable config such as `scoring-v1.yaml`.

Do not copy a competitor's formula.

## 6. Confidence handling

Low-confidence evidence should have reduced/no impact. A low-quality trip may still get partial analytics but should not present falsely precise scores.

Possible outcomes:

- full score;
- provisional score;
- dimension unavailable;
- trip unranked due to insufficient confidence.

## 7. Personal baseline

Personal comparison can reward improvement/consistency without pretending a universal threshold is perfect.

Possible baselines:

- last N valid trips;
- exponential/robust rolling summary;
- same vehicle class/profile;
- similar duration/context only if validated.

Avoid adapting so quickly that repeated poor behavior redefines itself as "good."

## 8. Overall synthesis

An overall score may exist for convenience, but it must not erase dimension detail.

Requirements:

- explainable weighted/composed function;
- missing-dimension handling defined;
- confidence displayed;
- no single high-risk metric can be hidden by unrelated strengths if product interpretation would be misleading.

## 9. Rankings

Ranking entries require:

- minimum telemetry confidence;
- minimum integrity state;
- compatible scoring version or normalization rules;
- vehicle/category eligibility if applicable;
- server-side validation of submitted summary fields where feasible.

Do not rank maximum speed.

## 10. Explanations

Persist compact score audit data such as:

```text
dimension
base value
contribution id
contribution amount
supporting event ids
confidence factor
baseline reference/version
```

UI should be able to answer "why 78?" without rerunning unavailable cloud services.

## 11. Calibration workflow

Initial thresholds/weights are provisional until evaluated with real fixtures. Maintain a notebook/test suite that shows how candidate changes affect a fixed corpus before promotion.

## 12. M4.4 implemented scoring-v1 contract

Scoring version 1 consumes complete M3 confidence/eligibility frames, accepted M4.2 events, and the matching M4.3 integrity audit. It is a deterministic local reducer; it does not use replay-reduced display values, ML output, network state, maximum speed, or a personal baseline. The exact implemented configuration is `docs/reference/scoring-v1.yaml`, and every result retains that config snapshot plus all upstream algorithm versions.

The fixed dimensions are `smoothness`, `braking_control`, `acceleration_control`, `cornering_control`, and `consistency`. Smoothness requires at least three seconds of moving jerk evidence. Each direct control dimension requires at least 500 ms of a physical opportunity: ±0.5 m/s² longitudinal acceleration for acceleration/braking, or at least 0.5 m/s² lateral acceleration / 0.05 rad/s yaw for cornering. At least 80% of the opportunity must have usable evidence; 80% fully eligible evidence is required for a full rather than provisional dimension. Absence of an opportunity is `unavailable`, never an assumed perfect score. Consistency remains explicitly unavailable until the separately authorized M4.5 baseline.

Available dimensions start at 100 and subtract only governed M4.2 audit contributions. Abrupt longitudinal/corner transitions and repeated strong/high-load events after the first have explicit base penalties. One sustained strong maneuver is an opportunity, not an automatic judgment. Road impacts and phone movement are not driver-control penalties. Version 1 contains no positive bonus because no governed positive-event evidence exists yet; adding one changes scoring semantics and requires a new scoring version.

Each penalty uses fixed-point milli-points: base points × event activation-ratio multiplier (1.0–2.0, rounded to permille) × event-confidence weight (1.0 supported, 0.5 limited). The final dimension is clamped to 0–100 and displayed with half-up integer rounding. Limited evidence has less numerical impact but always makes the result provisional, preventing a reduced uncertain penalty from being presented as fully trustworthy. Every contribution retains its stable rule ID, event ID, base value, severity multiplier, confidence weight, raw amount, and applied amount.

Overall synthesis renormalizes the configured weights across available direct dimensions and requires at least two dimensions. A full result requires smoothness plus all three direct control dimensions, fully eligible evidence, and verified integrity; partial dimension sets are provisional. The overall value cannot exceed the lowest available dimension by more than 15 points, so unrelated strengths cannot hide one poor control dimension. Limited integrity is provisional, questionable integrity requires review, and unranked integrity suppresses the overall value while retaining any partial dimension audit. Only a full score with verified integrity is locally ranking-eligible; connected ranking still requires later server-side validation.

These thresholds and weights are governed synthetic baselines, not population-calibrated probabilities and not a production-readiness claim. Changing eligibility, weights, contribution meanings, confidence handling, rounding, missing-dimension synthesis, guardrails, or rank mapping requires a new scoring version. M4.4 adds no schema/persistence, historical recomputation, network, permission, recorder, Flutter bridge, UI, Drive DNA aggregation, personal baseline, ML, moderation, server enforcement, or crash behavior.

## 13. M4.5 Drive DNA boundary

Drive DNA version 1 consumes compact scoring-version-1 observations without mutating the original `TripScoreAudit`. Scoring-v1 continues to report its per-trip consistency slot as unavailable and continues to exclude consistency from overall synthesis. The separately versioned Drive DNA profile derives consistency across at least three available direct profile dimensions in a comparable cohort. This preserves scoring-v1 historical meaning while allowing M4.5 to add a multidimensional cross-trip profile. Exact aggregation and evidence rules live in `DRIVE_DNA_SPEC.md` and `docs/reference/drive-dna-v1.yaml`.

## 14. M4.6 personal-baseline lifecycle boundary

Drive DNA lifecycle version 1 selects the caller's current personal/vehicle/context cohort and then invokes the unchanged Drive DNA version-1 reducer. An established baseline requires ten current eligible observations plus a complete profile; vehicle, class, mount, sensor, and long-inactivity changes remain explicit recalibration evidence. The lifecycle never alters a trip score, contribution, overall value, integrity state, or ranking eligibility. Its exact configuration is `docs/reference/drive-dna-lifecycle-v1.yaml`; comparison remains later product work.

## 15. M4.7 implemented score explanation contract

Explanation version 1 is a deterministic local projection of the existing scoring audit, not a new scoring algorithm. Every fixed score dimension receives a reason path containing its state/value, moving and opportunity duration, usable and fully eligible duration/coverage, every exact contribution, and every governed provisional or unavailable reason. A scored dimension with no contribution explicitly reports that no version-1 penalty fired; it does not treat missing evidence as positive evidence.

Each contribution path retains the stable contribution/rule IDs, dimension, base penalty, severity multiplier, categorical-confidence weight, raw and applied milli-points, and complete supporting event IDs. The overall path retains each available dimension value and configured weight, the guardrail outcome, provisional/unavailable reasons, integrity state, ranking status, and complete upstream scoring provenance. These paths answer why a result exists without rerunning a cloud service and without recomputing or changing its value.

The output uses stable localization keys plus typed, unit-bearing arguments and exact source references. User-facing prose, baseline comparison wording, Flutter rendering, persistence, and commentary remain later presentation work; commentary can never become score evidence. The exact contract is `docs/reference/explanation-v1.yaml`. Any change to reason-path meaning requires a new explanation version or message-catalog version as appropriate, while historical scoring version 1 remains unchanged.
