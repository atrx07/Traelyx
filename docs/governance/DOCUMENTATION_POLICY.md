# DOCUMENTATION_POLICY.md — Keeping Agent Context Useful

## When to read

Read when adding/restructuring docs, updating agent navigation, or noticing stale/duplicated specifications.

## 1. AGENTS.md stays small

Root `AGENTS.md` is a map/constitution. Do not move full algorithms or long feature specs into it.

Nested `AGENTS.md` files contain scoped rules only.

## 2. Progressive disclosure

Every substantial spec should begin with:

- When to read;
- optionally when not to read;
- links to narrower dependencies.

Agents should search headings/ranges rather than loading full files.

## 3. One source of truth

Do not duplicate the same formula/contract in five prose files. Link to the authoritative spec or machine-readable reference.

## 4. Generated docs

Generated DB/API/schema views should be marked generated and regenerated from source, not hand-edited.

## 5. Status/history

- `README.md` roadmap = public human-readable mirror, never the detailed authority.
- `STATUS.md` = current facts.
- `NEXTSTEPS.md` = short priority queue.
- active exec plan = detailed current work.
- `docs/exec-plans/ROADMAP.md` = authoritative long-range stages and step IDs.
- completed plans = history, not default context.

## 6. ADRs

Use ADR for durable "why" decisions. Do not write an ADR for every small implementation detail.

## 7. Freshness

When a behavior changes, update docs in the same change. If a spec is intentionally future-state, label it.

## 8. Context cost

Documentation should be optimized for lookup:

- descriptive headings;
- tables for contracts;
- examples near rules;
- machine-readable schemas;
- indexes.

Do not produce huge narrative documents solely for completeness.

## 9. Git and progress persistence

The default workflow is direct development on `main`: inspect, implement a bounded unit, run its gates, update progress documents, inspect the diff, commit atomically, push `origin/main`, and verify local `HEAD` equals `origin/main` before beginning unrelated work.

Use a branch, pull request, or separate worktree only when the user or active plan requires it, repository protection prevents direct development, or an explicitly risky experiment needs isolation. Document the reason before creating it.

Never force-push or rewrite published `main` history without explicit authorization. If `origin/main` advances unexpectedly, fetch and reconcile both histories safely. Do not overwrite remote work.

Completed, validated work must not accumulate only in the working tree. A commit should contain one coherent unit that can be understood and reverted independently. Inspect its exact staged diff and preserve unrelated user changes. Do not push work as complete while a required gate is known to fail; an exceptional preservation commit must be clearly labeled incomplete/WIP.

## 10. Roadmap synchronization

After a roadmap substep passes its required gates, update its active execution plan, `STATUS.md`/`NEXTSTEPS.md` where applicable, and the corresponding README roadmap row in the same completion commit. Push the commit and verify synchronization. Do not mark the next substep active until the user authorizes it.

README roadmap presentation uses current-milestone expansion: each completed or future milestone appears as one summary row, while only the currently authorized active milestone exposes all of its canonical substeps. When a milestone completes, collapse its child rows from README while retaining detailed history in the authoritative roadmap and execution-plan records. A known next milestone remains a single pending summary row until user authorization activates it.

Use only this status vocabulary:

- ✅ Complete
- 🔵 Active
- 🟡 In progress
- ⛔ Blocked
- ⚪ Pending
- ⏸ Deferred

`Complete` means the substep's acceptance criteria and validation gates passed. ETAs are planning ranges, not promises; prefer ranges such as `~2–4 hours` or `~1–2 weeks`. Completed work shows `Done`, and historical estimates are not rewritten to appear more accurate.

A milestone becomes complete only when every required substep and milestone-level gate passes. Then update project state, close/archive its execution plan, and persist that closure in an atomic pushed commit. Activation of the next milestone waits for user authorization.

## 11. User approval gate between roadmap substeps

Traelyx development is user-paced. After every numbered roadmap substep:

1. Run its acceptance criteria and required validation gates.
2. Update the authoritative execution plan, `STATUS.md`, `NEXTSTEPS.md`, and README roadmap as applicable.
3. Create and push the atomic completion commit to `origin/main`.
4. Verify local `HEAD` equals `origin/main`.
5. Report the completed substep, commit hash, validation and CI results, next planned substep, and any warnings or blockers.
6. Stop and wait for explicit user authorization before implementing the next numbered substep.

Validation success, a successful commit or push, and milestone activation are not authorization. While waiting, do not edit, pre-build, pre-validate, or create speculative work for the next substep, and do not consume significant context preparing it. Lightweight reporting about the next substep is allowed. The gate also applies between substeps in one milestone and at milestone transitions unless the user explicitly authorizes continuous execution for that milestone.

If the gate is introduced while a roadmap substep is already in progress, finish only that substep. Preserve and report any pre-created future-substep work without mixing it into the current completion commit.
