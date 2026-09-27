# ADR-0025: Separate experimental live Guardian rules from trip analysis

- Date: 2026-09-27
- Status: accepted for the M6.8 prerequisite; delivery integration pending

## Context

M6.7 supports consensual pairing but no live safety evaluation or push delivery.
Completed-trip analysis cannot provide a native background alert lifecycle, and
existing maneuver/bump events do not establish a crash. The maintainer authorized
including live evaluation and background push within M6.8.

## Decision

Introduce an independent, versioned, deterministic native evaluator behind a
bounded worker. It consumes original raw samples and emits only corroborated,
explicitly uncertain detections. A confirmed mount, stationary calibration and
usable independent motion/GNSS evidence are mandatory. Quality loss suppresses
claims. Raw recorder ownership, rates and existing scoring versions are unchanged.

The isolated implementation stays disconnected until explicit activation,
durable cancellation/outbox, account binding, server consent and push validation
are complete. The exact synthetic baseline and lifecycle are recorded in
`docs/technical/GUARDIAN_ALERTS_V1.md`. No production crash-accuracy claim follows
from unit tests. Do not bypass unreliable sensor status for the development phone.

## Consequences

Monitoring is conservative and may be unavailable on slopes, unreliable sensors
or moved mounts. A queue failure disables Guardian without interrupting recording.
No account, cloud provider or new runtime dependency is introduced by this isolated
prerequisite. Remote delivery will require a separate provider/access review.

Alternatives rejected: relabelling road impacts as crashes; evaluating only in
Flutter; changing historical scores; hiding missing evidence behind a normal state.
