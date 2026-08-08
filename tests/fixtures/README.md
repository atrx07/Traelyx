# Test Fixtures

Fixtures are durable evidence for telemetry/scoring/model regressions.

## Suggested layout

```text
telemetry/
  smooth_straight.tripdebug
  smooth_straight.expected.json
  braking_001.tripdebug
  braking_001.expected.json
corrupt-trips/
  truncated_chunk...
ml/
  tiny_feature_windows...
api/
  provider_success.json
  provider_rate_limit.json
```

## Privacy

Before committing real drives, remove personal metadata and precise location unless a route-specific test genuinely requires it. Never include home/work labels or secrets.

## Expected files

Expected outcomes should use tolerances/time windows and event IDs rather than brittle exact floating-point dumps.
