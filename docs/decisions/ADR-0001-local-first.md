# ADR-0001 — Local-First Product Architecture

**Status:** Accepted

## Context

The app records sensitive location and high-frequency telemetry. Core usefulness should not depend on account creation, network availability, or ongoing cloud cost.

## Decision

The phone is the primary authority for recording, raw telemetry, core analysis, scoring, history, and replay. Cloud features are optional enhancements.

## Consequences

Positive:
- works offline;
- improves privacy;
- reduces backend cost;
- avoids onboarding hostage flow;
- resilient to provider outages.

Negative:
- more complex local persistence/migrations;
- device storage must be managed;
- multi-device sync is not automatic for raw data.

## Revisit if

A future product requirement genuinely needs server-authoritative full telemetry and has a sustainable privacy/cost model.
