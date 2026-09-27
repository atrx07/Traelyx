# Guardian alert rules and delivery contract v1

## Status

M6.8 is in progress. The native evaluator and lifecycle are implemented as an
isolated prerequisite. They are **not connected to RecorderService or enabled
in the application**. Hosted delivery, consent UI and physical validation remain
required. These are experimental synthetic baselines, not field-validated crash
detection, emergency protection, or calibrated confidence probabilities.

## Local evaluation

`GuardianSafetyEvaluator` consumes the original version-1 IMU and GNSS samples
without modifying them. A separate single-consumer worker uses an offer-only
1,024-input queue and at most 1,024 reordered samples with a two-second horizon.
Overflow, late input, callback failure or 1.5 seconds without input after startup
disables that worker. It does not block or fail the independent raw recorder.
There are no new sensor subscriptions, rates, wake locks, network calls or SDKs.
Stopping discards unqualified evidence; it does not flush a late alert.

The driver must first confirm a rigid mount and device-forward direction.
Missing confirmation is disabled. A stationary three-second window requires
GNSS speed at most 1 m/s, gyro magnitude at most 0.05 rad/s, accelerometer norm
within 0.75 m/s² of 9.80665, and maximum axis standard deviation 0.15 m/s².
Its mean estimates gravity and stationary bias. Device forward is projected
perpendicular to gravity; horizontal projection below 0.5 is rejected.

Eligibility requires Android IMU accuracy at least 2, no raw quality flags,
non-null trip elapsed times, strictly increasing per-channel source timestamps,
and IMU spacing/pair age at most 50 ms. GNSS must be non-mock, flag-free, have
horizontal accuracy at most 15 m and reported speed accuracy at most 1.5 m/s,
with fix age/spacing at most 1.5 seconds. Speed above 90 m/s or a fix-to-fix
change above 15 m/s² invalidates evidence rather than supporting an alert.

Gyro magnitude above 0.5 rad/s or cumulative non-yaw rotation above 10 degrees
invalidates calibration. This intentionally limits availability on slopes,
rough roads and moving mounts; it cannot identify every phone movement.
Free fall (acceleration norm below 4 m/s²) and predominantly vertical shocks
(absolute vertical delta above half the longitudinal delta magnitude plus
2 m/s²) clear pending evidence. Missing evidence is never labelled safe/normal.

### Severe-drive candidate

- Longitudinal acceleration at most −6 m/s² for at least one second.
- Three preceding usable GNSS fixes spanning at least 1.5 seconds, all at
  least 8 m/s and within a 3 m/s range; use their minimum as baseline.
- Two following fixes each at least 5 m/s below that baseline, before the
  candidate's four-second deadline.
- A five-minute cooldown; no repeated claim for the same sustained brake.

This denotes a corroborated strong braking pattern, not proof of reckless
driving, intent, injury, or a collision.

### Possible-crash candidate

- A longitudinal impact at most −25 m/s² lasting 40–400 ms, with integrated
  negative impulse at least 2 m/s, followed by release below the threshold.
- The same three-fix moving baseline as above.
- Speed falls by at least 6 m/s to at most 1.5 m/s within three seconds of
  impact, then remains stopped through usable fixes for at least five seconds.
- The evidence must complete within 12 seconds; pending impact takes priority
  over severe-braking notification. A 30-minute crash cooldown also starts the
  five-minute severe cooldown.

All thresholds belong to **Guardian safety rules version 1**. They are governed
heuristics, not population-calibrated limits. They miss events and can produce
false positives. They are independent of M4 scoring, event taxonomies, ML and
LLM commentary. Any classification-changing tuning needs a new rule version.

## Local alert lifecycle

`GuardianPendingAlert` defines a 30-second cancellation window, stable random
event UUID, account/consent generation binding, and ten-minute expiry. Both
monotonic and wall clocks bound expiry. Reboot, clock rollback, account change
or consent replacement prevents old dispatch. An attempt reservation must be
persisted before network IO. Six attempts use 5/10/20/40/80/120-second backoff;
late callbacks cannot resurrect cancellation or revocation.
Cancellation is available only before the first network-attempt reservation.
After handoff, the UI must not claim it can retract an in-flight request;
account/consent revocation still invalidates subsequent server access.

The network envelope allowlist is schema version, event UUID, kind, rule version,
occurrence time and `experimental_not_confirmed` uncertainty. No trip ID,
coordinates, speed, raw evidence, mount direction, name or free-form text.
Backend acceptance is its own state; it never means recipient receipt or view.
Persistence and dispatch integration must enforce these transitions and remain
disabled until separate consent, authorization and delivery tests pass.

## Required remaining integration gates

- Native durable encrypted activation/outbox, cancellation notification and
  account-change teardown; no duplicated Supabase refresh-token ownership.
- Current server permission and connection-generation checks at ingest,
  dispatch, receipt and detail reads, with quotas and bounded retention.
- Replaceable push provider, opt-in device registration, generic lock-screen
  copy and authenticated details; distinct send/receipt/view semantics.
- False-positive fixtures, lifecycle/retry/revocation tests, and background,
  screen-lock, offline/recovery and performance checks on a physical phone.
- Synthetic end-to-end delivery without dangerous driving or real-contact
  alerts. Synthetic success does not validate field sensitivity/specificity.
