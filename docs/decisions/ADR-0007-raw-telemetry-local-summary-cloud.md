# ADR-0007 — Raw Telemetry Local, Compact Summaries Cloud

**Status:** Accepted

## Context

High-frequency GPS/IMU streams can grow rapidly and are privacy-sensitive. Supabase free storage should not be consumed by raw data for every drive.

## Decision

Keep full raw telemetry local by default. Sync only compact derived summaries/events required for connected features. Future backup of raw data is separate explicit functionality.

## Consequences

Positive:
- controls cloud cost;
- reduces privacy exposure;
- keeps cloud schema manageable.

Negative:
- full replay is device-local unless exported/backed up;
- cross-device raw history requires later design.
