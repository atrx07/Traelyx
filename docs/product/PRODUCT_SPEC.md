# Traelyx — Product Specification

## When to read

Read the relevant sections when implementing or changing a user-facing feature, deciding feature interactions, or reviewing whether technical behavior still matches the product intent.

Do not read this whole document for narrow infrastructure work whose user behavior is unaffected.

## 1. Core user promise

Traelyx turns a phone into a transparent driving telemetry recorder and analyst. It should answer four questions after a drive:

1. **What happened?** — route, speed, acceleration, braking, cornering, events.
2. **How confidently do we know?** — calibration/sensor/GNSS/integrity quality.
3. **How did this compare with the driver's own behavior?** — Drive DNA and historical baselines.
4. **Why did the app judge it that way?** — explainable event and score evidence.

A fifth optional layer makes the experience social/fun:

5. **How can this be shared, ranked, replayed, or narrated safely?**

## 2. First-launch experience

The app must not force account creation before delivering local value.

Preferred first launch:

```text
Welcome

Record and analyze drives locally.
No account required.

[ Start locally ]
[ Sign in for online features ]
```

Initial permission education should explain why location/background/notification permissions are requested. Do not request every permission at launch if it is not yet needed.

Vehicle setup should be progressive. The user can record before creating a detailed vehicle profile; after receiving value, the app may explain that vehicle metadata improves class-aware analysis.

## 3. Drive screen / recording

The recording screen is an instrument, not an analytics dashboard.

Requirements:

- prominent start/end state;
- clear recorder health;
- current speed when sufficiently reliable;
- trip time/distance;
- optional minimal map;
- calibration/sensor confidence indicator;
- minimal interaction while moving;
- no tiny controls or distracting menu exploration during motion;
- background/locked-screen operation;
- resilient state restoration after UI/process disruptions where platform permits.

The app may support automatic trip detection later, but manual recording must remain dependable and understandable.

## 4. Trip summary

After a trip, show:

- distance;
- duration;
- moving/stopped time where reliable;
- average/max observed speed as telemetry (not a competition reward);
- route/map;
- Drive DNA dimensions;
- overall synthesized score if enabled;
- telemetry confidence;
- integrity state;
- notable event count and categories;
- strongest positive/negative evidence;
- historical comparison;
- replay action;
- explanation actions for metrics.

An example presentation:

```text
NIGHT RUN
42.7 km · 51m

Drive DNA
Smoothness        91
Braking Control   84
Acceleration      79
Cornering         94
Consistency       88
Overall           87

Telemetry confidence  96%
Trip integrity        Verified

4 notable events
Braking +6% vs last 10 drives

[ Replay Drive ]
```

Numbers are illustrative, not formula definitions.

## 5. Drive DNA

Drive DNA is the main long-term identity layer. It is not a medical/safety diagnosis and must not claim to establish universal driver skill.

Characteristics are defined in `DRIVE_DNA_SPEC.md` and become more personalized as valid history accumulates.

The visual representation should become recognizable as a "driving signature" without copying competitor graphics. A radar chart may exist in deeper analytics, but the primary identity should use an original ring/fingerprint/signature treatment.

## 6. Explainability

Every consequential score/status should provide an explanation surface.

Examples:

- Braking Control 78 → contributing events, jerk/progression, confidence, baseline comparison.
- Telemetry Confidence 91% → GNSS accuracy, sensor dropouts, calibration, device movement.
- Integrity Verified → checks/evidence passed, without exposing exploitable anti-cheat internals to public ranking clients.

Explanations should separate:

- measurement;
- detected event;
- confidence;
- scoring consequence;
- commentary.

Commentary is never evidence.

## 7. Trip replay

Replay is a synchronized time-based experience, not a static map.

All of the following share one playback clock:

- route marker;
- camera following/overview behavior;
- speed graph;
- longitudinal/lateral acceleration graphs;
- event markers;
- event details;
- commentary bubbles;
- score/evidence highlights.

Controls should include at least pause/play and multiple speeds such as 0.5×, 1×, 2×, 5×, 10× subject to usability testing.

Future: a highlight replay can compress a long trip into notable segments. It is not required for first MVP unless scope permits.

## 8. Road commentary

Commentary appears as animated bubbles anchored to actual road/event points. It can be analytical, chill, supportive, roast, or unhinged.

Example tone (not fixed copy):

- "this corner was personal huh?"
- "brakes filed a complaint"
- "you kinda met god here, bro"
- "okayyy that was clean"

Humor must not convert a severe event into praise or encourage repeating it.

See `COMMENTARY_SPEC.md`.

## 9. Social and rankings

Online social features require an account.

Potential ranking dimensions:

- smoothness;
- consistency;
- braking control;
- improvement streak;
- clean-drive streak;
- category/class-aware metrics with adequate confidence.

Avoid:

- fastest trip on public road;
- highest max speed;
- most extreme corner G as a leaderboard objective;
- other mechanics that reward risk escalation.

Rankings consume sanitized derived entries and do not require public precise routes.

## 10. Vehicle profiles

A user may have multiple vehicle profiles.

Possible fields:

- user-defined name;
- vehicle type (motorcycle/car/other supported class);
- manufacturer/model/year when user chooses;
- optional notes;
- calibration/baseline metadata.

Do not require VIN, registration number, insurance number, or other unnecessary identifiers.

Vehicle-aware baselines should prevent obviously inappropriate comparison between radically different vehicle classes.

## 11. Guardian / Partner Connect

Guardian Connect lets a driver connect one or more trusted accounts, subject to scope and abuse prevention.

Core principles:

- explicit invite + acceptance;
- granular permissions;
- easy revocation;
- event-triggered alerts rather than default continuous tracking;
- serious safety content stays clear even if humorous tone is enabled elsewhere;
- no secret/hidden partner tracking.

See `GUARDIAN_SPEC.md`.

## 12. Accountless → account migration

A local user can later create/sign into an account. The app should offer to associate/sync eligible local history without requiring deletion/re-entry.

The user should be informed which classes of data will sync. Raw telemetry need not automatically upload.

## 13. Developer diagnostics

Because the project targets technically curious users and needs field debugging, include a diagnostics area eventually containing information such as:

- GNSS accuracy/status;
- sensor rates;
- dropped samples;
- recorder service state;
- database/storage usage;
- telemetry buffer health;
- sync status;
- model/scoring versions;
- backend latency when online.

Diagnostics must redact secrets.

## 14. Data export/delete

Users must be able to:

- delete individual trips;
- clear caches;
- control raw telemetry retention;
- export supported trip formats/debug bundles;
- delete cloud/account data when online accounts are implemented.

Debug exports intended for issue reporting should offer anonymization options.

## 15. Failure UX

Examples:

- Poor GPS: "Location accuracy is low; speed/corner evidence may be reduced."
- Phone moved: mark orientation uncertainty and recalibration state.
- ML unavailable: fall back to deterministic analysis.
- Cloud narrator unavailable: fall back to procedural commentary.
- Cloud account unavailable: preserve local recording/history.
- Integrity uncertain: allow private history but exclude from competitive ranking until appropriate.
