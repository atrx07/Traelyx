# ADR-0034 — Offline dataset imports with explicit quarantine

**Status:** Accepted
**Date:** 2026-11-11

## Context

M7.1 needs reproducible dataset provenance before any EventNet experiment.
Public availability and an open license do not establish usable units, driver
groups, event boundaries or timestamp quality. The first reviewed source lacks
row-level driver/trip/time fields, and declared acceleration units need checking.
Private maintainer trips cannot silently become training or committed fixtures.

## Decision

Use standard-library Python offline imports behind a versioned registry.
Pin source bytes/SHA-256 and preserve source numeric text and source labels.
Publish deterministic samples plus an audit manifest only after bounded parsing
and validation succeed; keep downloaded/derived data in ignored local storage.
Copy license, attribution, full registry metadata and hashes into the manifest.

M7.1's public source is quarantined and blocked for training. Do not fabricate
driver groups, timestamps or unit conversions. A separate original synthetic
corpus tests the import/grouping plumbing, with synthetic-only status and no
model-performance claim. Preserve the existing native M3 corpus independently.
Production-trained-data eligibility requires a reviewed future contract with
usable evidence; it cannot be enabled by changing a boolean in this registry.

## Consequences

Normal validation/CI is network-free and adds no third-party dependency or APK
cost. Imports are bounded and versioned; source corrections produce new versions
rather than rewriting historical evidence. This completes import infrastructure
without making the first public dataset eligible for EventNet training. Suitable
held-out real data remains a prerequisite for meaningful later evaluation.
