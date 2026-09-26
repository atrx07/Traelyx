# SOCIAL_RANKING_SPEC.md — Friends, Rankings & Gamification

## When to read

Read when implementing leaderboards, achievements, public profiles, friend relationships, sharing, or rank eligibility.

## 1. Objective

Make driving analytics socially engaging without turning public roads into a racing game.

## 2. Safe ranking categories

Candidates:

- Smoothness;
- Braking Control;
- Cornering Control where calibrated and not based on maximum lateral load;
- Consistency;
- Improvement over personal baseline;
- clean/smooth streaks;
- valid-drive streaks;
- class-aware composite score.

## 3. Prohibited/strongly discouraged competitive categories

- top speed;
- shortest time between public locations;
- highest acceleration magnitude;
- highest lateral G;
- most severe events;
- any category whose optimal strategy is increased public-road risk.

## 4. Eligibility

A ranking entry must include/check:

- supported scoring version;
- valid vehicle class/profile;
- minimum telemetry confidence;
- acceptable integrity status;
- minimum sample/trip evidence;
- server-side ownership/validation.

## 5. Privacy

Leaderboard rows contain sanitized metrics/profile identity only. No precise route, home/work inference, or raw trip detail is required.

## 6. Friends

Friend/follow semantics should be deliberately chosen; do not accidentally make every profile globally discoverable. Include block/report controls before public social growth.

## 7. Achievements

Achievements should reward engagement/quality, e.g.:

- first valid trip;
- 10 smooth trips;
- month-over-month consistency improvement;
- telemetry nerd milestones;
- successful data export / open-source contributor easter eggs.

Avoid achievements for dangerous maxima.

## M6.6 implemented comparison contract (validation pending)

Experimental friends-only cohorts are separated into car, motorcycle and other.
The user explicitly selects the recorded trip's class from saved vehicle classes;
unknown classes are excluded. A member's retained history uses one class until
withdrawn. Only complete scoring-v1 dimensions, verified integrity, clean
finalization and supported calibration/orientation evidence are admitted.
Minimum moving evidence is 60 seconds; opportunity coverage and contribution
rules retain scoring-v1 semantics. The server derives scores from a separately
consented minimized dossier, never trusts the owner-writable compact summary.

Ten accepted submissions unlock comparison: latest-five mean smoothness,
100 minus their mean absolute deviation for consistency, and latest-five minus
preceding-five mean for improvement. This uses server acceptance order and is
not a chronological or population-normalized skill claim. It does not change
trip scoring or Drive DNA. No extra-driving incentive or achievement is added.
Names/class/aggregates are shared with accepted unblocked friends only; underlying
evidence remains private. User-controlled withdrawal removes ranking evidence.
Server validation cannot establish physical truth or driver identity. See ADR-0023.
