# Traelyx — Current Project State

> Keep this file short. It is meant to be inexpensive agent context. Update facts, not prose history.

## Current phase

**Phase 0 — Governance / repository bootstrap**

## Working

- Product direction defined.
- Initial governance/reference pack created.

## Partial

- Technology selections are architectural decisions, not yet validated in a real app repository.

## Not implemented

- Flutter application shell.
- Android foreground recorder.
- Local database.
- Telemetry pipeline.
- Event engine.
- Drive DNA/scoring.
- Replay.
- Auth/cloud/social.
- Guardian Connect.
- ML models.
- Commentary provider integrations.
- Release pipeline.

## Known risks

- Android background/foreground-service behavior across OS versions/OEMs.
- Device mounting/orientation and motorcycle vibration effects on IMU quality.
- Map tile/provider policy and offline/cache strategy.
- Availability/diversity of labeled telemetry for ML.
- Free-tier cloud limits if adoption becomes large.
- APK/app-data growth if raw telemetry retention is unmanaged.

## Next milestone

**M0 — Skeleton:** repository, Flutter shell, native Android integration skeleton, local DB skeleton, automated formatting/analysis/tests, and initial CI.
