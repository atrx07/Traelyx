# ADR-0037 — Gated EventNet evidence foundation

**Status:** Accepted for the M7.5 foundation
**Date:** 2026-11-14

## Context

M7.4's int8 candidate fails its frozen probability-drift gate and provides no
consistent size/speed advantage. The dataset also lacks production feature and
normal/severe truth needed for promotion. The maintainer explicitly authorized
continuing M7 development and returning to model acceptance later.

## Decision

Implement the provider/audit/fallback foundation while carrying M7.4 acceptance
forward. Production analysis always uses existing deterministic rules. Version 1
has no production-approved model status, enabled inference mode, runtime asset,
feature extractor or model-provider configuration. Newly requested local analyses
record that model acceptance is deferred, using the existing local JSON audit.
Legacy audits remain valid; historical results are not recomputed.

A separate bounded generated-fixture harness tests the provider interface and
audit contract. It rejects experimental/rejected model manifests before feature
or provider construction, requires supported rule evidence, binds feature schema,
count, input digest and time bounds, verifies provider identity and finite
probabilities, preserves interruption/cancellation, and limits attempts. Its
outputs remain nonproduction evidence and cannot modify rule windows, event
confidence, merge decisions, scores, integrity or Guardian state.

## Consequences

Independent M7 development progresses without promoting the rejected model or
weakening acceptance gates. No model dependency, migration, network access,
recorder change or device operation is needed. Full M7.5 hybrid integration
remains open. Enabling real models requires a new reviewed boundary with accepted
model/feature/label contracts, suitable unseen evaluation data, runtime/battery
validation, explicit corroboration rules and rollback. The active M7 plan and
NEXTSTEPS retain that follow-up; M7.6 is not authorized by this decision.
