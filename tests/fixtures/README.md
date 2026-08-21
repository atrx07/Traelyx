# Test Fixtures

Fixtures are durable evidence for telemetry/scoring/model regressions.

The governed M3 telemetry corpus is generated in native test code at
`android/app/src/test/kotlin/io/github/atrx07/traelyx/telemetry/TelemetryRegressionFixtureCorpus.kt`.
It uses an explicit corpus version, fixed timestamps, synthetic device/vehicle motion, and a
non-real coordinate origin. This keeps complete decoder-to-replay coverage deterministic without
committing a precise-route archive. The accepted private Tecno `.tripdebug` fixture is not corpus
input and must remain outside Git and logs.

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

Prefer generated synthetic fixtures for deterministic telemetry regressions. Before committing any
real drive, remove personal metadata and precise location unless a route-specific test genuinely
requires it and repository privacy review explicitly permits it. Never include home/work labels or
secrets.

## Expected files

Expected outcomes should use tolerances/time windows and event IDs rather than brittle exact floating-point dumps.
