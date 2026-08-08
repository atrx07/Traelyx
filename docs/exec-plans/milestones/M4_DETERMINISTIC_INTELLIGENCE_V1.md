# M4 Playbook — Deterministic Intelligence v1

## Goal

Deliver useful events, Drive DNA, integrity, and scoring before neural models are allowed to help.

## Minimum references

`EVENT_ENGINE.md`, `SCORING_SPEC.md`, `DRIVE_DNA_SPEC.md`, `INTEGRITY_ENGINE.md`, machine-readable event/scoring drafts.

## Work units

1. Implement candidate event detectors with evidence/confidence.
2. Merge/debounce windows into maneuver events.
3. Separate magnitude/severity from judgment.
4. Implement integrity checks and rank eligibility.
5. Build scoring audit-contribution data structure.
6. Calibrate first scoring rules against fixture corpus; fill machine-readable values only with evidence.
7. Implement Drive DNA dimension eligibility and initial baseline states.
8. Add personal/vehicle baseline comparison.
9. Add positive/smooth streak evidence.
10. Build explanation API for UI.
11. Persist scoring/event/integrity versions.

## Acceptance

- user can ask why any score/event exists;
- low-confidence events do not heavily punish scores;
- no ML is necessary for a useful trip result;
- historical result records contain versions;
- extreme speed is not a rewarded leaderboard metric.
