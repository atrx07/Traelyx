# TESTING_POLICY.md — Test Strategy

## When to read

Read when adding tests, changing critical behavior, setting CI gates, or debugging regressions.

## 1. Test pyramid adapted to telemetry

### Pure unit tests

Use heavily for:

- unit conversions;
- filters;
- interpolation/alignment;
- coordinate transforms;
- distance math;
- event merging;
- scoring contributions;
- provider sanitization;
- serialization.

### Fixture replay tests

Extremely important. Feed recorded/synthetic `.tripdebug` data through the pipeline and assert events/scores/quality outcomes.

### Integration tests

Use for:

- Drift migrations;
- Flutter↔Kotlin bridge;
- Supabase/RLS against test environment where feasible;
- provider adapters with mocked HTTP;
- replay synchronization.

### UI/widget/golden tests

Use for:

- key result screens;
- Drive DNA visual states;
- replay/event bubble states;
- permission/account/Guardian states;
- reduced motion.

### Real-device tests

Required before claiming recorder production reliability.

## 2. Fixture classes

Maintain examples for:

- stationary;
- smooth straight drive;
- acceleration;
- braking;
- left/right corners;
- pothole/impact;
- phone moved;
- GPS dropout;
- corrupted/truncated chunk;
- mock/inconsistent telemetry;
- Android service recovery.

## 3. Golden expected outcomes

A fixture can have an `.expected.json` describing event windows/tolerances, not necessarily exact every-sample equality.

Do not overfit tests to incidental floating-point noise. Use physically meaningful tolerances.

## 4. Regression corpus

Any production/field false event that is reproducible and privacy-safe should become a regression fixture.

Example: a pothole repeatedly classified as a crash-like event → anonymized fixture + expected non-crash outcome.

## 5. CI gates

Initial CI should run:

- format check;
- static analysis;
- unit tests;
- deterministic fixture tests;
- build debug/release-validation target without private signing material;
- JSON/YAML/schema validation;
- secret scan.

Heavy ML training is not required on every PR. Run small inference/evaluation sanity tests and separate scheduled/manual training workflows.

## 6. Randomness

Tests involving commentary/random selection/model sampling must use fixed seeds or deterministic mocks.

## 7. Safety testing

Do not ask maintainers/contributors to create dangerous public-road situations. Use controlled environments, normal naturally occurring data, simulation, or existing datasets.
