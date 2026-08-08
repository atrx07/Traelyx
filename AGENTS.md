# AGENTS.md — Traelyx Repository Agent Constitution

This repository defines **Traelyx**, an open-source, local-first driving telemetry and driver intelligence platform. This file is intentionally concise: it is a **navigation and behavior map**, not the full project specification. Deeper sources of truth live under `docs/`.

## 1. Project priorities

When tradeoffs exist, prefer this order:

1. correctness and data integrity;
2. user safety and privacy;
3. auditability and reproducibility;
4. reliability, especially background recording;
5. maintainability and replaceability of third-party dependencies;
6. performance and battery efficiency;
7. accessibility and UX clarity;
8. visual polish;
9. feature velocity.

## 2. Non-negotiable rules

- Core trip recording, scoring, history, replay, and analytics must work without an account and without mandatory cloud access.
- The MVP must require **₹0 mandatory infrastructure cost**. Avoid dependencies that require paid plans, paid APIs, or billing information for core operation.
- Do not copy TripRank or another competitor's source, assets, UI, proprietary text, scoring model, branding, or distinctive implementation. Build original functionality from first principles.
- Do not create competition mechanics that reward reckless public-road behavior. Speed may be telemetry; maximum-speed racing leaderboards are out of scope.
- Never let an LLM make safety-critical decisions or determine whether a crash occurred.
- ML produces probabilistic evidence. Final user-facing scores and safety state transitions must remain auditable and governed by explicit, versioned logic.
- Never claim more precision than sensor quality supports. Confidence and data-quality limitations must propagate through the system.
- Never silently upload precise routes, raw high-frequency telemetry, API keys, or sensitive location history.
- Never commit secrets, release signing keys, keystores, passwords, `.env` secrets, or user API keys.
- Third-party services must sit behind replaceable provider interfaces when practical.
- Do not silently expand MVP scope. Check `docs/product/MVP_SCOPE.md`.
- Do not weaken, delete, skip, or rewrite tests merely to make a change pass.
- Do not alter historical scoring/model results without preserving the version needed to reproduce them.

## 3. Progressive context loading — REQUIRED

**Do not read the entire documentation tree by default.** Context is scarce. Load only the minimum context needed to complete the current step safely and correctly.

Required approach:

1. Read this file.
2. Identify the subsystem(s) touched by the task.
3. Use `docs/index.md` and the routing table below.
4. Read only the relevant section(s) of a large file. Prefer headings, search, line ranges, or targeted excerpts.
5. Read nested `AGENTS.md` only when inspecting/modifying that subtree.
6. Follow cross-references only when materially necessary.
7. Reuse context already loaded in the current run instead of reopening the same documents.
8. Expand context only if the current information is insufficient, contradictory, or the change crosses subsystem boundaries.
9. Do not read unrelated ML, auth, release, UI, map, or Guardian documents "for completeness."
10. Historical/completed execution plans are not default context.

**Documentation discovery is not permission to consume documentation wholesale.**

### Task routing

| Task area | Primary references |
|---|---|
| Flutter UI / interaction | `app/AGENTS.md` → `docs/product/UX_SPEC.md` → relevant feature spec |
| Trip recorder / background service | `android/AGENTS.md` → `docs/technical/ANDROID_TRACKING.md` → `TELEMETRY_SPEC.md` |
| Telemetry / sensor math | `docs/technical/TELEMETRY_SPEC.md` → `SENSOR_PIPELINE.md` |
| Events / scoring / Drive DNA | `EVENT_ENGINE.md` → `SCORING_SPEC.md` → `DRIVE_DNA_SPEC.md` |
| ML training/inference | `ml/AGENTS.md` → `ML_SYSTEM.md` → `ML_GOVERNANCE.md` |
| Integrity / anti-cheat | `INTEGRITY_ENGINE.md` + event/telemetry specs |
| Auth/accounts | `AUTH_SPEC.md` → `PRIVACY_MODEL.md` |
| Cloud sync/database | `DATA_MODEL.md` → `SYNC_SPEC.md` → auth/privacy as needed |
| Guardian Connect | `GUARDIAN_SPEC.md` → `permissions-matrix.yaml` |
| Commentary / AI providers | `COMMENTARY_SPEC.md` → `PROVIDER_ARCHITECTURE.md` |
| Maps | `MAP_ARCHITECTURE.md` + relevant UX section |
| Storage | `STORAGE_SPEC.md` + telemetry schema if raw data changes |
| Release/build/signing | `RELEASE_SIGNING.md` → `SECURITY.md` |
| CI/tests | `TESTING_POLICY.md` + subsystem-specific test instructions |

## 4. Before modifying code

For non-trivial changes:

1. Determine scope and affected subsystem.
2. Read only relevant authoritative docs.
3. Inspect current implementation and tests before proposing a rewrite.
4. Check `STATUS.md` for known failures and `NEXTSTEPS.md` for active priorities when task scope is broad.
5. For work spanning multiple meaningful steps, create/update an execution plan using `docs/exec-plans/templates/EXEC_PLAN_TEMPLATE.md`.
6. Identify privacy, safety, migration, battery, and backward-compatibility implications.
7. Do not introduce a new dependency until `DEPENDENCY_POLICY.md` is satisfied.

## 5. During implementation

- Keep business logic out of UI widgets.
- Prefer deterministic, testable pure functions for telemetry transformations and scoring.
- Preserve raw evidence needed for debugging while obeying storage/privacy policy.
- Add version identifiers to changing algorithms, schemas, and models.
- Treat units, coordinate frames, timestamps, and sensor quality as explicit data, never implicit assumptions.
- If implementation reveals a durable architecture decision, add an ADR rather than burying the reason in code comments.
- If a spec is wrong, update the spec deliberately; do not quietly code around it.

## 6. After modifying code

Run the checks appropriate to the touched subsystem, at minimum where available:

- formatting;
- static analysis / linting;
- unit tests;
- subsystem integration tests;
- relevant fixture/regression replay;
- affected build target;
- migration/upgrade test when persistence changes;
- privacy/security checks when data flow changes;
- performance/battery checks when recorder/sensor sampling changes.

Then:

- update the active execution plan;
- update `STATUS.md` when project state materially changed;
- update `NEXTSTEPS.md` if priorities/blockers changed;
- update the README roadmap when a tracked step changes state;
- update specs/reference schemas when behavior/contracts changed;
- record an ADR if a durable architectural choice was made.

## 7. Git / Progress Persistence

- Default development is directly on `main`, committed and pushed to `origin/main`. Use a branch/PR only when the user, active plan, repository protection, or an explicitly isolated risky experiment requires it; document the exception first.
- Never force-push or rewrite published `main` history without explicit authorization.
- Preserve unrelated user changes and inspect the exact diff before every completion commit.
- After a bounded logical unit passes its required gates, create one understandable atomic commit, push it, and verify local `HEAD` matches `origin/main` before unrelated work begins.
- Do not let completed validated work accumulate uncommitted across roadmap steps. Never mark a step, milestone, or stage complete before its required validation passes.
- Include corresponding execution-plan, `STATUS.md`, `NEXTSTEPS.md`, and README roadmap updates in the completion commit.
- After completing and reporting any numbered roadmap step, stop and wait for explicit user authorization before beginning the next step. Successful validation, push, or milestone activation is not authorization.
- While awaiting approval, do not implement, edit for, pre-build, or substantially prepare the next step. Stage and milestone transitions require the same approval unless the user explicitly authorizes continuous execution.

Detailed status ownership, roadmap vocabulary, ETA rules, and synchronization procedure live in `docs/governance/DOCUMENTATION_POLICY.md`; authoritative scope and step IDs live in `docs/exec-plans/ROADMAP.md` and active execution plans.

## 8. Definition of complete

A task is not complete because code compiles. Follow `docs/governance/DEFINITION_OF_DONE.md`.

## 9. Agent communication

When reporting work:

- state what changed;
- state tests/checks run and their outcomes;
- call out untested real-device assumptions explicitly;
- identify migrations or compatibility impacts;
- mention any new dependency/provider or privacy implication;
- do not describe speculative work as implemented.
