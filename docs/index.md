# Traelyx Documentation Index

Use this page to route to the smallest relevant source of truth. Do not read every linked file by default.

## Product

- `product/PRODUCT_SPEC.md` — full product behavior and feature relationships.
- `product/MVP_SCOPE.md` — what v0.1 may and may not include.
- `product/UX_SPEC.md` — screens, navigation, visual/animation principles.
- `product/DRIVE_DNA_SPEC.md` — multidimensional driver profile semantics.
- `product/GUARDIAN_SPEC.md` — Partner Connect / Guardian safety feature.
- `product/COMMENTARY_SPEC.md` — road commentary behavior and tone engines.
- `product/PRIVACY_MODEL.md` — user-facing privacy and data-sharing model.
- `product/COMPETITOR_BOUNDARIES.md` — originality / non-cloning boundaries.

## Technical

- `technical/TELEMETRY_SPEC.md` — canonical data semantics, units, timestamps, quality.
- `technical/SENSOR_PIPELINE.md` — filtering, alignment, orientation, confidence.
- `technical/EVENT_ENGINE.md` — event evidence semantics.
- `technical/SCORING_SPEC.md` — explainable versioned scoring rules.
- `technical/INTEGRITY_ENGINE.md` — anti-cheat/anomaly/corruption auditing.
- `technical/ML_SYSTEM.md` — ML roles, model families, deployment.
- `technical/AUTH_SPEC.md` — accountless + optional auth system.
- `technical/DATA_MODEL.md` — local/cloud entities and ownership.
- `technical/SYNC_SPEC.md` — local/cloud sync boundaries.
- `technical/PROVIDER_ARCHITECTURE.md` — dynamic commentary provider/model abstraction.
- `technical/MAP_ARCHITECTURE.md` — map rendering/tile abstraction and privacy.
- `technical/ANDROID_TRACKING.md` — native service requirements.
- `technical/STORAGE_SPEC.md` — raw telemetry retention/chunking/storage management.
- `technical/RELEASE_SIGNING.md` — debug/release APK, key custody, GitHub release flow.

## Governance

- `governance/DEFINITION_OF_DONE.md`
- `governance/TESTING_POLICY.md`
- `governance/DEPENDENCY_POLICY.md`
- `governance/PRIVACY_POLICY_ENGINEERING.md`
- `governance/ML_GOVERNANCE.md`
- `governance/PERFORMANCE_BUDGETS.md`
- `governance/DATASET_GOVERNANCE.md`
- `governance/OPEN_SOURCE_POLICY.md`
- `governance/DOCUMENTATION_POLICY.md`

## Decisions

`decisions/` contains accepted ADRs. Read only ADRs relevant to the decision being revisited.

## Execution plans

- `exec-plans/templates/EXEC_PLAN_TEMPLATE.md` — use for non-trivial work.
- `exec-plans/active/` — current detailed work.
- `exec-plans/completed/` — historical; not normal task context.
- `exec-plans/ROADMAP.md` — nine-milestone implementation plan.

## Machine-readable references

`reference/` contains YAML/JSON contracts suitable for validation, tests, generators, and tooling. Treat them as contracts and keep them synchronized with prose specs.

`reference/KNOWN_TOOLING_ISSUES.md` is the exception: it is an optional, failure-triggered operational reference for recurring local toolchain issues. Do not load it as normal startup context.
