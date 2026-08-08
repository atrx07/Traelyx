# ADR-0010 — Progressive Agent Context Loading

**Status:** Accepted

## Context

A large documentation corpus improves consistency but wastes context/credits if an agent rereads everything for every task.

## Decision

Root `AGENTS.md` acts as a short map. Domain docs begin with "When to read" guidance. Agents must load only relevant sections/files and expand context only when necessary. Nested `AGENTS.md` apply scoped rules.

## Consequences

Positive:
- lower context cost;
- clearer task focus;
- documentation can remain detailed without becoming mandatory payload.

Negative:
- docs require good indexes/headings;
- an agent may occasionally need a second retrieval pass.
