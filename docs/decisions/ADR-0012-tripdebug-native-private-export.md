# ADR-0012 — Native precise-private `.tripdebug` export

**Status:** Accepted

## Context

M2 must prove that a finalized physical drive remains deterministically inspectable outside the running app. Raw chunks are owned by native Kotlin and contain sensitive precise routes. Moving those bytes through Flutter, exposing private paths, or relying on debug-only ADB access would weaken the established recorder boundary and would not provide a real user export.

## Decision

Native Kotlin creates versioned `.tripdebug` archives from a freshly verified, finalized chunk catalog. Version 1 is a deterministic ZIP containing a minimal privacy-classified manifest and the original chunk files. Android's document picker provides the explicit destination; no network is involved. Native code self-inspects the finished archive before success, while the Flutter bridge receives only aggregate validation evidence. An independent standard-library host inspector verifies the same format without printing raw telemetry.

Precise-private exports are ignored by Git outside the governed fixture subtree. Repository inclusion requires a separate, documented anonymization decision; archive creation itself never counts as anonymization.

## Consequences

Positive:

- export exercises the same native chunk decoder and integrity rules used by finalization;
- raw bytes do not cross the Flutter bridge and private app paths remain hidden;
- the archive is deterministic, dependency-free, versioned, and independently inspectable;
- users retain explicit control over where precise route data is copied.

Negative:

- archive preparation temporarily duplicates the trip in app cache;
- version 1 preserves precise location and is unsuitable for sharing or direct Git inclusion;
- the document-picker handoff requires the activity to remain alive until selection completes.

## Revisit if

An anonymized public-fixture transformation is implemented, archives exceed the bounded in-process verification budget, iOS needs an interoperable exporter, or raw storage authority changes.
