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

- `STATUS.md` = current facts.
- `NEXTSTEPS.md` = short priority queue.
- active exec plan = detailed current work.
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
