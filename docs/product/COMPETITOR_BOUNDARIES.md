# COMPETITOR_BOUNDARIES.md — Originality & Non-Cloning Rules

## When to read

Read when proposing a feature inspired by another app, designing a new screen after competitor research, choosing names/branding, or reviewing possible IP/plagiarism risk.

## 1. Market inspiration is allowed

It is acceptable to observe that products such as TripRank demonstrate demand for:

- trip tracking;
- driving analytics;
- gamification;
- shareable results;
- rankings.

Those broad product categories are not implementation instructions.

## 2. Do not copy

Never intentionally reproduce:

- source code;
- proprietary assets/iconography;
- exact screen composition or distinctive interaction sequences;
- branded terminology;
- proprietary onboarding copy;
- scoring formulas;
- visual motifs strongly associated with a competitor;
- proprietary data acquired through prohibited means.

Do not decompile an app to obtain implementation details for reproduction.

## 3. Build from first principles

For each major feature, preserve design rationale in product specs/ADRs:

- user problem;
- constraints;
- our chosen behavior;
- tradeoffs;
- tests/metrics.

This creates a clear independent-development history.

## 4. Traelyx's distinctive identity

Traelyx should lean into features/choices that form its own identity:

- accountless/local-first operation;
- Drive DNA;
- explainable scoring;
- telemetry confidence;
- event/integrity auditability;
- Guardian granular permissions;
- road-commentary replay;
- provider-agnostic BYO AI;
- open export/self-inspection;
- open-source governance and reproducible ML.

## 5. Naming

Before public launch, search proposed project/app/feature names for confusion with existing software/trademarks. Avoid names intentionally chosen to sound like TripRank.

"Drive DNA" is currently a descriptive internal feature name and should be reviewed for naming conflicts before final branding.

## 6. Agent rule

If an agent is given a screenshot/code fragment from a competitor and asked to "make ours identical," it should instead extract high-level requirements and produce an original solution unless the maintainer has the legal right to reuse the supplied asset/code.
