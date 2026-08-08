# ADR-0003 — Supabase for Optional Connected Layer

**Status:** Accepted for MVP, replaceable

## Context

Online features need auth, relational data, RLS, social relationships, and ranking metadata while preserving zero mandatory MVP cost.

## Decision

Use Supabase free tier for initial connected features. Keep raw telemetry local and isolate cloud integration behind repository/domain boundaries so migration/self-hosting remains possible.

## Consequences

Positive:
- auth/Postgres/RLS/realtime in one stack;
- low initial ops burden;
- self-hostable ecosystem.

Negative:
- free-tier limits;
- provider dependency;
- schema/policy work still required.

## Revisit if

Free-tier constraints, reliability, pricing, or project scale materially change.
