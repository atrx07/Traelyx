# ADR-0016 — Bounded native route display boundary

**Status:** Accepted

## Context

Flutter trip results need useful offline route rendering in M5.4, while authoritative precise GNSS evidence lives in checksummed Android-private telemetry chunks. Duplicating the binary decoder and GNSS validity rules in Dart would create two authorities. Adding coordinates to the recorder-health bridge would broaden a deliberately coordinate-free operational contract. Selecting an online map SDK or tile provider now would also add network, policy, privacy, and possible cost dependencies that core route viewing does not need.

## Decision

Keep recorder bridge v1 coordinate-free and add a separate versioned map-data bridge for one user-selected local trip. Android verifies the complete chunk sequence with a streaming GNSS-only decode that validates but does not retain high-rate IMU records, then reuses the governed M3.2 GNSS sanity filter off the UI thread. It returns only accepted display geometry with explicit segment starts, processing/count metadata, and a deterministic 4,096-point hard cap. Missing, corrupt, incomplete, mixed-contract, contradictory, or unrepresentable evidence fails closed without partial geometry.

The Flutter boundary accepts an exact allowlisted response shape and keeps coordinates in transient route state only. Identifiers, storage paths/checksums, source providers, wall times, and raw accuracy/quality evidence do not cross. Coordinates are excluded from semantics, logs, diagnostics, cache metadata, analytics, and network payloads.

M5.4 renders this geometry using a dependency-free offline canvas behind project-level map/cache contracts. It has no basemap tiles, network requirement, or tile cache; cache status is visibly unavailable at zero bytes and clear is a safe no-op.

## Consequences

Positive:

- native decoding and GNSS governance remain single-source and reproducible;
- route results work accountlessly and fully offline with no mandatory service cost;
- precise location exposure is bounded to an isolated, selected-trip display contract;
- future map/tile providers can replace the canvas without entering feature models.

Negative:

- the map-data bridge and strict Dart parser require cross-runtime contract tests;
- chunks are decoded again when opening a route, although work is off the UI thread and output is bounded;
- the route-only canvas intentionally lacks road/place context;
- future iOS support needs an equivalent verified local route reader.

## Revisit if

Measured long-trip latency or memory requires a versioned streaming/indexed geometry format, governed visual QA shows a better evidence-preserving reduction, or a compliant tile provider is activated. Any revision must preserve offline core route rendering, visible cache control, fail-closed evidence handling, and location privacy boundaries.
