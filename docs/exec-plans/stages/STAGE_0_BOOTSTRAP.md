# Stage 0 Playbook — Governance & Bootstrap

## Goal

Create a repository that Codex can modify safely, cheaply, and repeatably before feature work begins.

## Minimum references

Root `AGENTS.md`, `PROJECT.md`, `ARCHITECTURE.md`, `TECH_STACK.md`, `TESTING_POLICY.md`.

## Work units

1. Use the official `Traelyx` product name and `traelyx` repository/Flutter project identifier; choose a unique Android application ID that does not copy competitor naming.
2. Initialize Flutter Android project and Git.
3. Place governance files at repository root and preserve nested agent scopes.
4. Establish Flutter/Dart/JDK/Android/Python toolchain constraints without needlessly pinning obsolete versions from this pack.
5. Establish directory responsibilities and imports/layer rules.
6. Add Drift/local DB shell.
7. Add native Kotlin bridge/service shell without pretending recorder reliability exists yet.
8. Add formatting/static analysis/unit tests.
9. Add GitHub Actions for checks and secret scanning.
10. Add build-size reporting and JSON/YAML validation.
11. Merge `GITIGNORE_SECURITY_SNIPPET.txt` into actual `.gitignore`.
12. Create first active exec plan for Stage 1 or 2.

## Acceptance

- clean clone can install dependencies and run checks with documented commands;
- app builds/launches in debug;
- no secret/signing material is committed;
- CI is green;
- documentation routing works;
- no core feature has been prematurely implemented through a random package.

## Do not do yet

- production ML;
- elaborate UI polish;
- cloud schema beyond a minimal placeholder unless needed;
- release signing key generation by the agent;
- navigation/OBD scope creep.
