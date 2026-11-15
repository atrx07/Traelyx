# ADR-0040 — Isolate and version experimental style embeddings

**Status:** Accepted for experiment only
**Date:** 2026-11-15

## Context

Drive DNA already has explicit deterministic dimensions and a vehicle/context
lifecycle. An optional self-supervised representation might support similarity
or deviation diagnostics, but no suitable field style truth or production feature
adapter is accepted. Latent coordinates change when weights/normalization change.

## Decision

M7.8 uses original generated physical summaries, a tiny denoising autoencoder and
a transparent normalized-summary Euclidean comparator. Shared fictional templates
test engineering, not real-driver generalization. Program labels are generation
diagnostics and never encoder targets. Normalization, weights and stable-pair
distance cutoffs fit training only. Freeze the protocol before results and retain
negative outcomes; no validated gain means test predictions stay uncomputed.

Every experimental distance comparison must match representation/model/feature
version, exact checkpoint or normalizer identity, dataset and vehicle/context/
sensor/mount scope. Fail closed for incompatible records; never reinterpret old
vectors in a new coordinate space. Missing/unsupported/insufficient evidence
abstains before inference. Distances do not express confidence or impairment.

## Consequences

Existing Drive DNA dimensions, cohort selection, scores, persistence and UI remain
unchanged, with no model/runtime/dependency or raw-vector user exposure. A smaller
vector alone does not establish usefulness. Real feature extraction, field labels,
uncertainty, runtime/battery and physical evidence remain separate promotion gates.
Any future production comparison/migration needs a separately scoped contract.

See [the frozen protocol](../reference/DRIVEDNA_EMBEDDING_V1.md).
