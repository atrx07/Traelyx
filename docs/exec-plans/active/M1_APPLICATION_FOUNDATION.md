# Execution Plan — M1 Application Foundation

**Status:** Active
**Owner:** Codex/maintainer
**Milestone:** M1 — Application Foundation
**Started:** 2026-08-09
**Last updated:** 2026-08-09

## Context budget / references

Read only:

- root and `app/` `AGENTS.md` files;
- the M1 section of `docs/exec-plans/ROADMAP.md` and the M1 playbook;
- relevant sections of `docs/product/UX_SPEC.md`;
- storage/data references only for persistence substeps;
- directly affected Flutter application code and tests.

Do not read recorder, telemetry, scoring, ML, cloud, Guardian, or release
specifications unless a current M1 substep discovers a material dependency.

## Goal

Create a clean, local-first application shell with stable theme, navigation,
settings, database migration, and diagnostics foundations.

## User-visible result

The accountless application has an original, accessible visual foundation and
testable navigation/state/storage boundaries without claiming recorder
functionality that does not exist.

## In scope

- Semantic dark-first theme tokens, typography, spacing, and motion primitives.
- Testable Drive/Trips/DNA/Social/You navigation shell.
- Non-secret local settings and a secure-storage abstraction for future secrets.
- Application schema version 1 and migration fixture harness.
- Redacted diagnostics shell.

## Out of scope

- Native trip recording or sensor acquisition.
- Telemetry processing, events, scoring, Drive DNA implementation, or replay.
- Accounts, cloud sync, Guardian, commentary providers, and ML.
- Map provider or tile integration.

## Preconditions

- M0 is complete and synchronized with `origin/main`.
- The user authorizes each numbered M1 roadmap substep separately.

## Affected components

- Flutter application theme, routing, state, settings, and diagnostics code.
- Drift schema and migration tests.
- Application/widget tests and project tracking documents.

## Data/privacy/security implications

- M1 remains accountless and local-first.
- Non-secret preferences and secret material must have separate abstractions.
- Diagnostics must redact credentials and sensitive local data.

## Compatibility/migration implications

- M1.1–M1.3 do not change persisted schemas.
- M1.4–M1.5 establish the versioned application schema and upgrade fixtures
  before public user data exists.

## Implementation steps

- [x] M1.1 — Add semantic design tokens/theme, typography, spacing, and
  reduced-motion-aware motion primitives with focused tests.
- [x] M1.2 — Add the deep-link-safe primary navigation skeleton.
- [x] M1.3 — Add local settings and explicit secure/non-secure boundaries.
- [ ] M1.4 — Implement Drift application schema version 1.
- [ ] M1.5 — Add database migration fixtures and upgrade tests.
- [ ] M1.6 — Add a redacted diagnostics shell.

Each numbered substep requires an independent validation, completion commit,
push, report, and user approval before the next substep begins.

## Tests / validation

- [x] M1.1 Dart formatting and static analysis.
- [x] M1.1 focused theme and widget tests.
- [x] M1.1 full Flutter test suite.
- [x] M1.1 repository contract/secret validation.
- [x] M1.1 Android debug build.
- [x] M1.1 remote CI on `main`.
- [x] M1.2 Dart formatting and static analysis.
- [x] M1.2 compact/wide navigation and direct deep-link widget tests.
- [x] M1.2 full Flutter test suite, repository validation, and debug build.
- [x] M1.2 remote CI on `main`.
- [x] M1.3 Dart formatting and static analysis.
- [x] M1.3 non-secret repository, corruption, stream, key-boundary, and secure
  provider tests.
- [x] M1.3 full Flutter test suite, generated-source check, repository
  validation, and debug build.
- [x] M1.3 Android 14 Tecno update-install and cold-launch smoke test.
- [x] M1.3 remote CI on `main`.
- [x] M1.4 Dart formatting and static analysis.
- [x] M1.4 fresh schema-v1 structure, relational integrity, constraint,
  cascade, idempotency, and raw-data-boundary tests.
- [x] M1.4 full Flutter test suite, generated-source check, repository
  validation, native Kotlin tests, and debug build.
- [x] M1.4 Android 14 Tecno update-install and cold-launch smoke test.
- [ ] M1.4 remote CI on `main`.
- [ ] Migration fixture tests when M1.4–M1.5 are authorized.

## Acceptance criteria

- The app continues to start without an account or network.
- Theme colors express semantic meaning and meet tested contrast thresholds.
- Numeric display typography is glanceable and uses tabular figures.
- Spacing, radii, and motion primitives are centralized.
- User-visible animations can resolve to zero duration when reduced motion is
  requested.
- Each later M1 contract is implemented and tested only in its authorized
  numbered substep.

## Risks

- The centralized palette remains intentionally evolvable until broader visual
  prototyping; semantic token names insulate consumers from palette changes.
- Navigation and database design can create premature coupling if implemented
  outside their numbered approval boundaries.

## Decisions made during execution

- M1.1 uses a Flutter `ThemeExtension` for Traelyx-specific semantic status
  colors while mapping shared meanings into Material `ColorScheme`.
- M1.1 adds no font or design-system dependency; system typography keeps the
  application offline-capable and avoids asset/license overhead.
- M1.2 uses `StatefulShellRoute.indexedStack` so each primary destination can
  retain an independent nested stack as later substeps add detail routes.
- M1.2 exposes stable local route paths without adding Android verified-app-link
  intent filters before a public scheme/host contract exists.
- M1.3 reuses the bootstrap `app_settings` table without changing schema
  version 1; typed definitions and repositories own encoding and defaults.
- M1.3 keeps secrets behind a separate replaceable interface. Its production
  default fails closed until a platform-backed provider is deliberately added,
  avoiding a premature dependency or insecure fallback.
- M1.4 stores structured domain metadata and telemetry chunk indexes in Drift;
  raw high-rate samples and precise route geometry remain outside SQLite rows.
- M1.4 uses explicit timestamp units, schema/algorithm versions, confidence and
  audit fields, foreign keys, uniqueness, and range/order checks. Deletes of a
  trip cascade only to its dependent chunks, events, and scores.
- M1.4 defines the complete fresh-install schema version 1. The earlier
  settings-only development bootstrap used the same SQLite user version; M1.5
  owns the explicit fixture/compatibility harness before domain data ships.

## Progress log

- 2026-08-09: M1 activated after explicit continuation approval.
- 2026-08-09: M1.1 checkpoint `a79e33c` passed GitHub Actions run
  `31296218766`; execution stopped at the M1.2 approval gate.
- 2026-08-09: M1.2 checkpoint `566adcd` passed GitHub Actions run
  `31297225380`; execution stopped at the M1.3 approval gate.
- 2026-08-09: M1.3 checkpoint `e555c13` passed GitHub Actions run
  `31298732771`; local gates passed and the debug APK update-installed and
  cold-launched on the Android 14 Tecno LH8n with existing data preserved.
  Execution stopped at the M1.4 approval gate.
- 2026-08-09: M1.4 implementation and local gates passed; the debug APK
  update-installed and cold-launched on the Android 14 Tecno LH8n with the
  expected UI and no PID-scoped fatal or Flutter errors. The database remains
  lazy in the placeholder UI and its fresh creation is covered by focused
  tests. Remote CI is pending.

## M1.1 completion summary

M1.1 centralizes the dark-first semantic color system, typography, spacing,
radii, and reduced-motion-aware timing primitives. The bootstrap shell consumes
the semantic tokens, and focused tests cover theme mapping, contrast, numeric
typography, control sizing, and reduced motion. Local validation and GitHub
Actions pass. No persistence, network, privacy, migration, recorder, or provider
behavior changed.

## M1.2 completion summary

M1.2 adds responsive compact and wide navigation for Drive, Trips, DNA, Social,
and You; direct route entry for every destination; safe unknown-route handling;
and honest feature placeholders. Focused tests cover the root redirect, tab
selection, every direct path, compact/wide layouts, and unknown paths. Local
validation and GitHub Actions pass. No persistence, network, privacy, migration,
recorder, or provider behavior changed.

## M1.3 completion summary

M1.3 adds typed, reactive non-secret settings persistence over the existing
schema-v1 Drift table plus Riverpod injection boundaries. Malformed persisted
values fail visibly, sensitive-looking keys are rejected from the non-secret
API, and the replaceable secure-value interface fails closed until a reviewed
provider exists. Focused tests and the full suite pass. The existing app updates
and cold-launches on the connected Android 14 Tecno device without startup or
database errors. Local validation and GitHub Actions pass. No schema, migration,
network, recorder, or provider dependency changed.

## M1.4 checkpoint summary

M1.4 defines the complete fresh schema-v1 contract for vehicles, trips,
telemetry chunk indexes, trip events, versioned scores, driver baselines, sync
queue operations, and existing non-secret settings. The schema enforces key
relationships, time/range constraints, deletion behavior, score uniqueness,
and sync idempotency while excluding raw samples and precise route geometry.
Focused tests and the full local suite pass, and the current APK update-installs
and cold-launches on the Android 14 Tecno device. Remote CI and completion
tracking remain before the substep can be marked complete.
