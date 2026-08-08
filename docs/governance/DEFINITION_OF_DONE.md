# DEFINITION_OF_DONE.md

## When to read

Read when completing/reviewing a task or writing acceptance criteria. For a tiny documentation-only edit, apply only relevant items.

A change is done only when all applicable items are satisfied.

## Functional

- Requested behavior is implemented, not merely scaffolded.
- Edge/failure states described in the relevant spec are handled.
- No unrelated scope was silently added.
- Existing supported behavior remains intact unless intentionally changed.

## Tests

- Appropriate unit tests added/updated.
- Relevant integration/fixture tests pass.
- Regression test added for fixed bugs likely to recur.
- Real-device validation performed when the claim depends on physical sensor/background behavior; otherwise explicitly marked unverified.

## Data / migration

- Schema changes have migrations.
- Upgrade from supported previous database version tested.
- Data-loss behavior is explicit and user-controlled.
- Version identifiers updated when semantics changed.

## Privacy / security

- New network fields reviewed for necessity.
- Secrets are not logged/committed.
- RLS/authorization updated/tested when cloud data changes.
- Location/API-key/Guardian changes match privacy specs.

## ML / scoring

If applicable:

- model/scoring version updated;
- promotion gates met;
- metrics recorded;
- fixture corpus compared;
- audit manifest generated;
- no black-box change silently rewrites historical meaning.

## Performance

If applicable:

- no unexplained APK-size regression;
- recorder/sample changes benchmarked;
- replay animation remains within performance budget;
- storage growth impact measured.

## Documentation

- authoritative spec updated if behavior contract changed;
- machine-readable reference updated if contract changed;
- active exec plan progress updated;
- STATUS/NEXTSTEPS updated when project state changed;
- ADR added for durable architecture decision.

## Report

Final agent summary must state:

- what changed;
- tests run/results;
- anything not tested;
- migration/privacy/performance impact where applicable.
