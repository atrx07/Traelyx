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
