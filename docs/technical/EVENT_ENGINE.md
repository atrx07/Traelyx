# EVENT_ENGINE.md — Driving Event Evidence

## When to read

Read when adding/changing event definitions, thresholds, ML event classes, event confidence, replay markers, or score evidence.

## 1. Separation of concepts

The system separates:

1. **measurement** — sensor-derived quantities;
2. **event evidence** — "a strong braking pattern probably occurred";
3. **context** — repeated/preceding/following behavior;
4. **judgment/scoring** — explicit consequence;
5. **commentary** — optional presentation.

Do not collapse these layers.

## 2. Event record

Conceptual fields:

```text
event_id
trip_id
event_type
start_elapsed_ns
peak_elapsed_ns
end_elapsed_ns
severity
confidence
quality_flags
primary_measurements
rule_evidence
ml_evidence?
context_tags
algorithm_version
```

## 3. Initial event taxonomy

### Longitudinal
- STRONG_ACCELERATION
- ABRUPT_ACCELERATION_TRANSITION
- STRONG_BRAKING
- ABRUPT_BRAKING_TRANSITION

### Lateral / corner
- HIGH_LATERAL_LOAD_LEFT
- HIGH_LATERAL_LOAD_RIGHT
- ABRUPT_CORNER_ENTRY
- ABRUPT_CORNER_EXIT

### Road/device
- ROAD_IMPACT_OR_BUMP
- PHONE_MOVED
- SENSOR_QUALITY_DEGRADED
- GNSS_JUMP_OR_LOSS

### Safety/integrity candidates
- CRASH_LIKE_IMPACT_EVIDENCE
- TELEMETRY_INCONSISTENCY

Names may evolve; machine IDs should become stable once released.

## 4. Event semantics example — strong braking

Strong braking means the data supports a significant negative longitudinal acceleration episode.

Inputs may include:

- longitudinal acceleration;
- jerk;
- speed change;
- event duration;
- GNSS/IMU agreement;
- confidence.

It does **not** itself imply:

- reckless driving;
- collision;
- driver error;
- legal speeding;
- poor overall braking control.

Context/scoring decides consequence.

## 5. Severity

Severity is physical/behavioral magnitude relative to a defined calibrated scale, not moral judgment.

Use named bands or normalized continuous value plus explicit calibration. Avoid arbitrary thresholds without fixture/data review.

## 6. Confidence

Confidence represents support for event classification, considering both model/rules and telemetry quality.

High model probability with poor sensor quality does not automatically equal high event confidence.

## 7. Event merging

One maneuver may produce many overlapping windows. Merge/debounce into one coherent event using documented rules.

Avoid replay showing 14 "hard brake" markers for one 2-second brake.

## 8. Positive events

The engine may also identify positive/neutral patterns such as long smooth streaks. Do not define only failures; the product should explain what went well.

## 9. ML integration

EventNet may output per-window class probabilities. Deterministic signals corroborate/adjust eligibility. Preserve both evidence sources for audit.

## 10. Versioning

Event definitions/merging/confidence logic must be versioned. Persist version with events if historical replay/audit depends on it.
