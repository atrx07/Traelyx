# ADR-0004 — ML Produces Evidence; Explicit Logic Produces Scores

**Status:** Accepted

## Context

A black-box model could output a convenient final score, but that conflicts with explainability, historical reproducibility, confidence handling, and reliable debugging.

## Decision

ML outputs event/context/anomaly/style evidence. Versioned explicit scoring rules produce final Drive DNA dimensions and overall synthesis.

## Consequences

Positive:
- auditable;
- model can be replaced independently;
- explanations are meaningful;
- historic scoring reproducible.

Negative:
- more engineering/calibration work;
- scoring formulas require careful governance.

## Revisit if

Never for core explainability principle; implementation details can evolve.
