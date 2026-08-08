# tests/AGENTS.md — Traelyx Test & Fixture Scope

## Rules

- Fixtures represent evidence and must not be silently edited to make new behavior pass.
- When expected behavior legitimately changes, document why and update the relevant algorithm/spec version.
- Real-drive fixtures should be anonymized before repository inclusion.
- Remove or transform precise location when it is not required for the test.
- Never include API keys, auth tokens, personally identifying metadata, home/work labels, or signing secrets.
- Add regression fixtures for bugs that could recur.
- Maintain tests for corrupted/truncated telemetry and migration/upgrade behavior.
- Golden UI/replay tests should respect deterministic clocks/random seeds.
