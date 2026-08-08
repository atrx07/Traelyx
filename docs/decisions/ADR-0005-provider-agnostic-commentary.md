# ADR-0005 — Provider-Agnostic Commentary with Local Fallback

**Status:** Accepted

## Context

Hosted model catalogs change frequently. Bundling large LLMs conflicts with APK/storage goals, while users may want richer generative commentary.

## Decision

Provide a built-in procedural narrator as guaranteed fallback. Add optional downloadable local AI and BYO-key cloud providers behind a common interface. Discover models dynamically when possible; do not hardcode one permanent model.

## Consequences

Positive:
- resilient to model deprecations;
- zero project API bill;
- privacy/offline option;
- user control.

Negative:
- provider adapter/testing complexity;
- users manage their own cloud credentials.
