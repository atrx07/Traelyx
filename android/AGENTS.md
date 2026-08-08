# android/AGENTS.md — Traelyx Native Android Tracking Scope

Applies to files under `android/`.

This subtree contains reliability- and battery-sensitive acquisition code.

## Read selectively

Primary references: `docs/technical/ANDROID_TRACKING.md`, relevant sections of `TELEMETRY_SPEC.md`, `SENSOR_PIPELINE.md`, and `PERFORMANCE_BUDGETS.md`.

## Rules

- Foreground/background recording reliability is more important than convenience abstractions.
- Use authoritative monotonic/high-resolution timestamps appropriate to sensor alignment; preserve source timestamps.
- Never silently discard sensor/location failures.
- Buffer safely across Flutter engine/UI absence.
- Do not change sample rates, batching, foreground-service type, wake behavior, or permission flows without documenting battery/lifecycle implications.
- Do not touch release signing secrets or keystores.
- Do not store cloud/user API keys in native plaintext configuration.
- Ensure Android version-specific behavior is tested/documented.
- Any migration to/from a third-party tracking SDK requires an ADR and regression comparison.

## Required validation for recorder changes

Where applicable:

- unit tests;
- service lifecycle tests;
- screen-lock test;
- app-background test;
- process/UI restart recovery test;
- GPS loss/recovery test;
- network-offline test;
- battery optimization behavior documented;
- physical-device validation for any claim of production reliability.
