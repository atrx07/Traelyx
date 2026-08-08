# Traelyx Governance & Reference Pack

## Purpose

**Traelyx is an open-source, local-first driving telemetry and driver intelligence platform focused on explainable analytics, Drive DNA, telemetry confidence, trip replay, integrity auditing, safety features, and user-controlled social connectivity.**

This pack is Traelyx's authoritative governance and reference system. It is designed to live in the repository and serve maintainers, contributors, and coding agents such as Codex as durable project memory.

Traelyx is **not** a clone of TripRank or any other existing application. Existing products establish that there is interest in gamified driving analytics, but Traelyx must use its own architecture, scoring logic, visual language, feature design, branding, copy, and implementation.

This pack captures the product and technical decisions made during Traelyx's planning session, including:

- local-first trip recording and analytics;
- serious GPS + IMU telemetry;
- Drive DNA, explainable scoring, telemetry confidence, and integrity auditing;
- synchronized animated trip replay with optional road commentary;
- Partner Connect / Guardian Mode with granular permissions;
- accountless use plus optional Supabase-backed online features;
- Flutter + Dart for app/UI, Kotlin native Android tracking, Drift/SQLite locally, Supabase remotely;
- on-device, auditable ML used as evidence rather than unquestioned authority;
- procedural commentary, optional downloadable local AI, and optional user-supplied cloud API keys;
- replaceable providers and dynamic model selection;
- zero mandatory infrastructure cost for the MVP;
- GitHub Releases as the distribution channel;
- release APK signing controlled by the maintainer, never committed to the repository;
- Codex governance with progressive context loading to avoid wasteful full-document ingestion.

## How to use this pack

1. Place the pack contents in the Traelyx repository root.
2. Use `Traelyx` for the visible product name, `traelyx` for the repository/Flutter project name, and `io.github.atrx07.traelyx` for both the Android namespace and application ID.
3. Do **not** delete governance files because implementation has started; evolve them alongside the code.
4. Read `AGENTS.md` first. It is intentionally a map, not an encyclopedia.
5. Read `PROJECT.md` and `ARCHITECTURE.md` when beginning substantial work.
6. Use `docs/index.md` to find authoritative domain specifications.
7. Use `docs/exec-plans/templates/EXEC_PLAN_TEMPLATE.md` for non-trivial work.
8. Update `STATUS.md` and `NEXTSTEPS.md` as milestones move.
9. Record durable architecture choices as ADRs under `docs/decisions/`.
10. Keep machine-readable definitions under `docs/reference/` aligned with code and tests.

## Document authority

When documents conflict, apply this order unless a more specific file explicitly states otherwise:

1. Direct user / maintainer instruction for the current task.
2. Root and nested `AGENTS.md` files within their scope.
3. Accepted Architecture Decision Records (ADRs).
4. Authoritative product/technical/governance specifications.
5. Machine-readable reference definitions.
6. Active execution plan.
7. `STATUS.md` / `NEXTSTEPS.md`.
8. Historical/completed execution plans and notes.

If a conflict is discovered, do not silently choose whichever is convenient. Resolve or document the conflict.

## Project-phase expectation

The proposed feature-rich MVP is expected to require roughly:

- **6 weeks:** impressive internal prototype, if development is intensive and agent-assisted;
- **~10 weeks:** usable alpha;
- **~12–14 weeks:** serious feature-packed MVP / public beta under focused development;
- **~14–20 calendar weeks:** realistic part-time college schedule;
- **~45–55 executable implementation steps** across 9 major stages.

The largest uncertainty is not writing Flutter code. It is real-world telemetry validation, Android background reliability, data collection, and ML evaluation across drivers/devices/vehicles.

## First milestone that matters

The first meaningful engineering victory is not a polished dashboard. It is:

> A debug/signed Android build can record a real 30–60 minute drive with the screen locked, preserve synchronized GPS + IMU telemetry, survive lifecycle/background conditions, and replay/export the trip intact afterward.

Everything intelligent depends on trustworthy acquisition.
