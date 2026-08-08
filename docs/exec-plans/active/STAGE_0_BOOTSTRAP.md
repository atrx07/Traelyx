# Execution Plan — Stage 0 Bootstrap

**Status:** Active
**Owner:** Codex/maintainer
**Stage:** 0 — Governance and bootstrap
**Started:** 2026-08-08
**Last updated:** 2026-08-08

## Context budget / references

Read only:

- root, `app/`, and `android/` `AGENTS.md` files;
- `ARCHITECTURE.md` and the Stage 0 playbook;
- relevant foundation sections of `docs/product/UX_SPEC.md`;
- testing, dependency, and definition-of-done governance documents;
- generated Flutter/Android code and directly affected tests.

Do not read telemetry, ML, cloud, Guardian, scoring, or release-signing details unless a bootstrap dependency requires them.

## Goal

Create a repeatable, testable Flutter Android repository foundation for Traelyx using the canonical application identity.

## User-visible result

Developers can clone the repository, install dependencies, analyze and test the code, and build a minimal local-first Android application shell. The shell exposes only honest bootstrap state; it does not claim that trip recording is implemented.

## In scope

- Flutter Android scaffolding for `traelyx` and `io.github.atrx07.traelyx`.
- Initial application structure and restrained dark-first shell.
- Drift/SQLite database foundation with an initial migration test.
- Versioned Flutter-to-Kotlin bridge contract and foreground-service skeleton.
- Formatting, static analysis, unit/widget tests, Android debug build, and CI.
- JSON/YAML validation, secret scanning, ignore rules, and build-size reporting foundation.
- Bootstrap documentation and next-stage handoff.

## Out of scope

- Production trip recording or claims of background reliability.
- Sensor processing, events, scoring, Drive DNA, replay, accounts, cloud sync, Guardian, commentary providers, and production ML.
- Release keys or private signing material.
- Elaborate product UI beyond the bootstrap shell.

## Preconditions

- Flutter 3.44.9 / Dart 3.12.2 available.
- Android SDK 36.1 and JDK 21 available with licenses accepted.
- Canonical identity commit is synchronized with `origin/main`.

## Affected components

- Flutter project configuration and application code.
- Generated Android host project and Kotlin native shell.
- Local database foundation.
- Repository automation, validation, tests, and developer documentation.

## Data/privacy/security implications

- The bootstrap shell performs no telemetry collection or network upload.
- No precise location, raw sensor data, credentials, or signing material is introduced.
- Secret scanning and ignore rules reduce accidental credential exposure.

## Compatibility/migration implications

- This creates database schema version 1; migration tests establish the baseline for future upgrades.
- Android namespace/application ID is fixed at `io.github.atrx07.traelyx` before public releases exist.

## Implementation steps

- [x] 1. Scaffold the Flutter Android project with the canonical identity and preserve repository governance files.
- [ ] 2. Establish source boundaries, design tokens, and an honest local-first bootstrap screen.
- [ ] 3. Add the Drift/SQLite schema version 1 foundation and migration test harness.
- [ ] 4. Add a versioned Kotlin bridge and non-recording foreground-service skeleton.
- [ ] 5. Add formatting, analysis, tests, CI, schema validation, secret scanning, and build-size reporting.
- [ ] 6. Document repeatable commands and update project state and priority queue.

Each step should be independently verifiable when practical.

## Tests / validation

- [ ] format/static analysis
- [ ] unit and widget tests
- [ ] database migration test
- [ ] Android debug build
- [ ] JSON/YAML validation
- [ ] secret scan configuration review
- [ ] real-device launch smoke test

Recorder lifecycle, battery, screen-lock, GPS recovery, and sensor validation are not applicable until recording is implemented.

## Acceptance criteria

- `flutter pub get`, formatting, analysis, tests, and an Android debug build succeed with documented commands.
- Generated Android configuration uses the canonical namespace/application ID.
- Local schema version 1 initializes under test.
- Flutter can query the bridge version/capability state without starting telemetry acquisition.
- CI expresses the same core checks without requiring secrets or paid services.
- The app remains accountless, local-first, and makes no unsupported recorder claims.

## Risks

- Generated Flutter files may overlap repository governance or ignore files and must be merged carefully.
- Android foreground-service APIs are version-sensitive; this stage provides structure only, not reliability claims.
- New dependencies must remain zero-cost, maintained, and replaceable where applicable.

## Decisions made during execution

- None yet. Durable decisions will be promoted to ADRs if required.

## Progress log

- 2026-08-08: Toolchain preflight passed with no Flutter Doctor issues; physical Android 14 device detected.
- 2026-08-08: Plan activated before scaffolding.
- 2026-08-08: Identity checkpoint committed and synchronized with `origin/main` before scaffold persistence.
- 2026-08-08: Locally validated M0 implementation is being separated into bounded roadmap commits.
- 2026-08-08: Roadmap step 0.2 scaffold validated with canonical Gradle identity and an Android debug build.
- 2026-08-08: Roadmap step 0.3 toolchain baseline validated with Flutter Doctor and the generated Android build configuration.

## Completion summary

Pending.
