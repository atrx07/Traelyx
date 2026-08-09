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

- [ ] M1.1 — Add semantic design tokens/theme, typography, spacing, and
  reduced-motion-aware motion primitives with focused tests. Implementation
  and local validation are complete; remote CI is pending.
- [ ] M1.2 — Add the deep-link-safe primary navigation skeleton.
- [ ] M1.3 — Add local settings and explicit secure/non-secure boundaries.
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
- [ ] M1.1 remote CI on `main`.
- [ ] Navigation/deep-link tests when M1.2 is authorized.
- [ ] Persistence/migration fixture tests when M1.3–M1.5 are authorized.

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

## Progress log

- 2026-08-09: M1 activated after explicit continuation approval.
- 2026-08-09: M1.1 implementation and local gates passed; remote CI is pending.

## M1.1 checkpoint summary

M1.1 centralizes the dark-first semantic color system, typography, spacing,
radii, and reduced-motion-aware timing primitives. The bootstrap shell consumes
the semantic tokens, and focused tests cover theme mapping, contrast, numeric
typography, control sizing, and reduced motion. Local gates pass; remote CI must
pass before completion. No persistence, network, privacy, migration, recorder,
or provider behavior changed.
