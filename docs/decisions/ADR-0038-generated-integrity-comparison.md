# ADR-0038 — Generated IntegrityNet comparison before field acceptance

**Status:** Accepted for experiment only
**Date:** 2026-11-15

## Context

M7.6 requires an anomaly experiment compared with deterministic integrity rules.
The public maneuver dataset has no integrity ground truth. Real model acceptance
is explicitly carried forward, and prior model/data versions must remain intact.

## Decision

Register a separate generated-only experiment manifest, preserving M7.1 imports
and frozen EventNet code/artifacts. Native test code generates fictional profile
groups before aggregate features, applies known numeric/quality/platform/raw
corruption changes and runs unchanged IntegrityPipeline v1. Labels come from
generation provenance rather than model or rule output. Export only scalar
summaries and versioned baseline findings; no raw routes, samples or identifiers.

Fit one small CPU autoencoder using training-clean cases, train-only normalization
and a validation-clean reconstruction threshold. Never fit on evaluation
injections/test. Keep all semantic slices and decoder abstention visible. Use
fixed synthetic FPR/recall criteria and threshold sensitivity diagnostics; a
negative result is retained rather than retuned. Reported source/fixture/model
hashes and safe JSON artifacts permit within-platform replay.

## Consequences

The full native→CPU experiment can run offline/CI without private data, a new
dependency or phone operation. Shared generators/profile holdout do not establish
field generalization. Even added value on generated cases leaves production
eligibility false, real legitimate-drive FPR unavailable, and integrity/ranking/
scoring/Guardian behavior unchanged. Real feature/data/runtime/battery acceptance
remains a separate gate; stop after M7.6 before M7.7 authorization.
