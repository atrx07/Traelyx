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
- [`../ml/README.md`](../ml/README.md) — M7.1 local dataset registry/import,
  reproduction commands and training-eligibility limitations.
- `technical/AUTH_SPEC.md` — accountless + optional auth system.
- `technical/DATA_MODEL.md` — local/cloud entities and ownership.
- `technical/SYNC_SPEC.md` — local/cloud sync boundaries.
- `technical/PROVIDER_ARCHITECTURE.md` — dynamic commentary provider/model abstraction.
- `reference/CLOUD_COMMENTARY_V1.md` — optional Groq setup, secure keys, minimized
  request review and provider-selected reviewed wording (M7.10).
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

## Product issues and incidents

- [issues/README.md](issues/README.md) — symptom-based index of significant product failures, root causes, fixes, recovery evidence, and remaining limits. Consult only relevant records when debugging; not normal startup context.

## Android QA tooling

For Android emulator/ADB operation and interrupted Pixel QA sessions, see
[the M6.8 emulator workflow](reference/ANDROID_EMULATOR_WORKFLOW.md). Read it only
when that tooling or device setup is relevant.

## Machine-readable references

`reference/` contains YAML/JSON contracts suitable for validation, tests, generators, and tooling. Treat them as contracts and keep them synchronized with prose specs.

`reference/KNOWN_TOOLING_ISSUES.md` is the exception: it is an optional, failure-triggered operational reference for recurring local toolchain issues. Do not load it as normal startup context.

For M7.11 local narrator artifact/provider work only, read
[local commentary v1](reference/LOCAL_COMMENTARY_V1.md), the empty bundled catalog
and its separate manifest schema. Runtime/model activation is still gated.

For the authorized M7.4/M7.5 acceptance follow-up, read
[recording intake v1](reference/EVENTNET_RECORDING_INTAKE_V1.md) and
[the active plan](exec-plans/active/M7_EVENTNET_ACCEPTANCE_FOLLOWUP.md) before
accessing old private phone evidence. Intake does not grant model promotion.
Public-data follow-up uses [public-source qualification v1](reference/EVENTNET_PUBLIC_QUALIFICATION_V1.md).
The optional [manual stationary phone check](reference/M7_MANUAL_PHONE_QUALITY_CHECK.md)
does not require ADB or authorize a drive.
For the next corpus/feature decision, read the bounded
[Q-Motion metadata audit](reference/QMOTION_METADATA_QUALIFICATION_V1.md) and
[native input proposal](reference/EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md).
The target remains proposed. The [feature feasibility slice](reference/EVENTNET_FEATURE_FEASIBILITY_V1.md)
adds an unwired native development extractor and one public stream probe;
it grants no source or model production admission.
The subsequent [v2 input-quality proposal](reference/EVENTNET_INPUT_QUALITY_V2.md)
preserves interpolation/current/history/native-LIMITED metadata while retaining
the strict v1 entry point. Both remain unwired development APIs.
For the external research report's Ferreira lead, use the
[primary-source review](reference/FERREIRA_SOURCE_REVIEW_V1.md): author permission
and units are documented, but missing videos/original frames and unresolved driver
assignment prevent treating it as the current acceptance corpus.
The bounded [remaining-source triage](reference/EVENTNET_REMAINING_SOURCE_TRIAGE_V1.md)
records 15 other leads, corrected Kaggle permissions and the missing evidence
needed before a new experiment. No candidate is admitted.
For the next evidence step, use the
[collection/review protocol and empty packet](reference/EVENTNET_EVIDENCE_COLLECTION_V1.md).
It prepares parked preflight, independent annotation and an evaluation freeze;
it does not initiate collection, assign real groups or admit a model.
The isolated [parked synchronization pilot](reference/EVENTNET_SYNC_PILOT_V1.md)
implements software draw journals, local export and exact host clock checks.
Physical presentation/reference and recorder binding remain unverified.
Its [Tecno software follow-up](reference/sync-pilot-tecno-v1-result.json) records
API34 device checks and the v1.0.1 export-selection repair. ADB screen inspection
does not establish optical alignment or change the old recordings' exclusion.
