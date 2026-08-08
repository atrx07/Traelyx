# UPSTREAM_CHANGE_POLICY.md — Handling Fast-Changing Providers & Toolchains

## When to read

Read when upgrading Flutter/Android/Supabase, implementing a hosted model provider, pinning an external model ID, adopting a map/tile service, or interpreting a third-party API deprecation.

## Principle

External providers and toolchains change without regard for this project's plans. Treat documentation from this governance pack as architecture intent, not a promise that a 2026 model/package/API name still exists later.

## Rules

1. Verify current official documentation immediately before implementing a provider-specific integration.
2. Prefer capability detection/model discovery over hardcoded catalogs.
3. Pin package/tool versions in the real repository only after compatibility tests.
4. Record major upgrades as ADRs when behavior or architecture changes.
5. Keep provider adapters isolated so removal/replacement is local.
6. Maintain a procedural/local fallback for commentary.
7. Do not automatically migrate to a newly recommended hosted model solely because a provider says it is the replacement; benchmark it for this project's actual commentary quality.
8. Before changing Android background behavior, check current Android platform requirements.
9. Before relying on a free tier, verify current limits and whether billing/credit card is required.
10. Do not embed stale external pricing/rate-limit numbers into product logic.

## Commentary model policy

Model selection values conversational warmth, concise humor, context awareness, safety, and latency for the commentary task. General reasoning benchmark strength is secondary.

Maintain a benchmark corpus so "provider recommendation" does not become "project recommendation" automatically.
