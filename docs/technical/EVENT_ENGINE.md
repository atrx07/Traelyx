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

## 11. M4.1 implemented taxonomy-window contract

Event-taxonomy version 1 consumes the exact synchronized M3.5 derived frames and M3.6 confidence/eligibility frames at the analysis cadence. It emits lazy, repeatable, bounded-memory evidence windows for the ten M4.1 machine IDs defined in `docs/reference/event-taxonomy.yaml`: strong acceleration/braking, abrupt acceleration/braking transitions, high lateral load left/right, abrupt corner entry/exit, road impact or bump, and phone moved. These IDs are stable within version 1.

Maneuver and impact candidates require confirmed movement plus usable required metric eligibility. `excluded` metric evidence emits no claim; `limited` evidence emits an explicitly limited candidate with the exact limiting components and reasons. Strong longitudinal/lateral candidates use signed vehicle-frame acceleration. Abrupt transitions use signed vehicle-frame jerk plus a same-direction minimum acceleration/load. Road impact requires both vertical acceleration and vertical jerk. Phone movement is emitted only from M3's explicit `DEVICE_MOVEMENT_INVALIDATED` state with `ORIENTATION_INVALIDATED`; it is not inferred from an arbitrary acceleration spike.

Every numeric candidate retains physical value/unit, M3 channel provenance, its config snapshot, threshold-relative severity evidence, rule evidence, metric eligibility, component confidence/reasons, source versions, and analysis-window time bounds. Phone movement carries explicit unavailable numeric severity because M3 does not expose a calibrated movement angle at each confidence frame; no magnitude is fabricated.

The version-1 activation values are synthetic-fixture-reviewed deterministic baselines, not population-calibrated probabilities or moral/legal boundaries. Any field-tuning change that alters historical classification requires a new version. M4.1 does not merge adjacent windows, assign final event IDs, persist events, score behavior, infer a crash, or produce integrity verdicts; those remain separate authorized substeps.
