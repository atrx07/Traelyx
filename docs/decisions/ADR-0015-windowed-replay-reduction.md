# ADR-0015 — Windowed, evidence-preserving replay reduction

**Status:** Accepted

## Context

M3.7 must turn the 100 Hz M3 analysis/confidence timeline into a practical display input without coupling UI sampling to acquisition or analysis rates. Selecting one point per display interval would be cheap but could erase brief acceleration peaks, gaps, confidence failures, and eligibility transitions. Reusing the full analysis stream would preserve evidence but duplicate excessive data and encourage the replay UI to become an accidental scoring authority.

## Decision

Replay telemetry version 1 uses an independent 100 ms default cadence and a lazy trailing-window reducer over synchronized M3.5/M3.6 frames. The cadence must be at least and exactly divisible by the source analysis interval. The first source frame is emitted exactly; later frames close `(previous replay time, replay time]` windows, with one exact partial terminal frame when required.

Every channel retains the final source value and its M3.5 provenance or missing reason. Each window also retains scalar and per-axis vector extrema as their exact source samples, available/missing counts and reasons, observed qualities and movement states, and conservative confidence/eligibility summaries. The most restrictive eligibility and most severe categorical confidence seen in the window remain visible even if the representative frame recovers.

The reducer holds only the active window and constant-size accumulators. Replay output remains native, local, ephemeral, and display-only. It does not rewrite or persist source evidence, cross the Flutter bridge in M3.7, interpolate route positions, or become an input to events, scoring, integrity, or ML.

## Consequences

Positive:

- display density is decoupled from acquisition and analysis sampling;
- exact first/terminal timestamps, extrema, gaps, and state transitions survive reduction;
- long trips can be reduced repeatably without eagerly materializing another full timeline;
- downstream UI receives conservative quality summaries without a fabricated probability.

Negative:

- each replay frame is richer than naive point decimation;
- M5 consumers must distinguish the representative value from the window envelope;
- the default 10 Hz cadence and severity ordering may need a versioned tuning change after device/UI performance measurement.

## Revisit if

Measured M5 replay performance requires another display cadence, a persisted low-rate archive becomes necessary for retention, or governed visual studies show a different extrema/transition contract is clearer. Any change must remain versioned and must not make reduced replay data authoritative for scoring or historical recomputation.
