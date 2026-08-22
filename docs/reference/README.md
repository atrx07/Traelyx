# Traelyx Machine-Readable Reference Contracts

These files are intended to be consumed by tests, generators, validators, and agents. Prose specs explain semantics; these files make contracts concrete.

`KNOWN_TOOLING_ISSUES.md` is an optional operational exception to the machine-readable contracts in this directory. Search it only after a relevant host, toolchain, environment, build, or test failure, or when a task explicitly concerns local build/test tooling; it is not normal startup context.

`TRIPDEBUG_FORMAT.md` defines the versioned local-private drive archive used for deterministic fixture inspection and replay input.

Important:

- `scoring-v1.yaml` is the implemented deterministic M4.4 synthetic baseline. It contains no null weights, remains `production_ready: false` pending controlled field calibration, and any semantic or weight change requires a new scoring version rather than rewriting version-1 history.
- Provider/model catalogs are dynamic; registry expresses capabilities/policy rather than permanent model names.
- JSON schemas describe logical debug/test representations even if production telemetry is encoded compactly.
- Update machine-readable files and tests in the same change when a contract changes.
