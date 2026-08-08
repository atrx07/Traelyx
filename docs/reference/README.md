# Traelyx Machine-Readable Reference Contracts

These files are intended to be consumed by tests, generators, validators, and agents. Prose specs explain semantics; these files make contracts concrete.

Important:

- `scoring-v1.yaml` is a **draft shape with intentionally null calibration values**. Do not treat it as a production formula.
- Provider/model catalogs are dynamic; registry expresses capabilities/policy rather than permanent model names.
- JSON schemas describe logical debug/test representations even if production telemetry is encoded compactly.
- Update machine-readable files and tests in the same change when a contract changes.
