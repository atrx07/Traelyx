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
