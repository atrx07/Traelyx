# ADR-0039: ContextNet must demonstrate value before opening test predictions

Status: Accepted for the M7.7 experiment, 2026-11-15

## Context

ContextNet is optional. Existing commentary selects deterministic event repetition
and cooldown; it is not a five-state context classifier. There is no governed
real-world context-labelled dataset or accepted production feature extractor.
Synthetic recognition alone cannot justify a model dependency or context claims.

## Decision

Use a separate original analytical 30/60/120-second generated corpus and a tiny
CPU GRU, with fictional groups assigned before generation. Compare against explicit
experimental temporal rules on identical features/support. Freeze the complete
protocol, seed, training configuration and rules before the experiment. Preserve
all previous model/data/code versions; generated context data has a separate CC0
dedication. No app or narrator integration is included.

The validation value gate requires material selective F1 improvement without
class-recall, coverage, open-set or quality-handling regression. Unavailable
evidence abstains before model invocation. Failure retains rules and leaves test
predictions uncomputed, while still checking test structure. A negative result
completes the experiment. Never weaken a strong comparator or tune on results to
make a model appear useful. Report uncalibrated probability diagnostics honestly.

## Consequences

Safe JSON checkpoints and aggregate reports retain hashes, exact inputs, provenance
and test-opening status. Within-platform repeatability is required. Shared
synthetic templates do not establish real-driver generalization, accepted context
labels or runtime/battery performance. All production inference remains disabled.
Any future adoption requires separately scoped unseen evidence, overlap/open-set
semantics, calibrated outputs and physical/runtime acceptance. Existing event,
score, integrity and Guardian logic remains authoritative.

See [the frozen protocol](../reference/CONTEXTNET_EXPERIMENT_V1.md) and
`ml/experiments/contextnet-v1.json`.
