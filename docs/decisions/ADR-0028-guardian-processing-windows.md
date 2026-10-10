# ADR-0028 — Require expiring Guardian processing windows during validation

- Date: 2026-10-10
- Status: Accepted for M6.8 validation; deployment/hosted proof pending

## Decision

Manual boolean enablement cannot enforce a bounded production test when the
operator or approval service stops. Require both the exact `true` enable value
and `GUARDIAN_PROCESSING_WINDOW_V1` in each production entrypoint. This config
is compact JSON with exactly `schema_version=1`, `starts_at_epoch_ms` and
`expires_at_epoch_ms`. Timestamps are positive safe integers; duration is positive
and at most 360,000 ms. Noncompact/duplicate-key, missing, oversized, malformed
or overlong config denies processing. There is no permissive fallback.

Capture the reviewed window at handler construction and evaluate server time on
every request, including warm instances. Admit only start <= now < expiry. Invalid
clock readings, clock rollback or expiry close that instance permanently.
Recheck through the shared fetch adapter immediately before every SQL, OAuth and
FCM operation. Preserve worker authentication before its disabled response and all
existing capability, account, connection, generation, quota and RLS checks.

The lease is backend configuration, not a client capability or permission grant.
It creates no scheduler, provider, credential, DB schema or client payload field.
Routine continuous monitoring requires separate design/authorization; this
validation deployment must not silently bypass finite-window enforcement.

## Limits and validation

This stops new work after expiry; already-started HTTPS operations may complete
under their existing bounded transport deadlines. It does not rewrite dashboard
settings or perform credential/fixture cleanup. Explicit false restoration,
worker retirement and reviewed synthetic cleanup remain required.

Six deterministic tests cover malformed/ambiguous windows, strict boundaries,
warm expiry, invalid/backwards clocks, HTTP denial without body/SQL access,
preserved worker credential denial and outbound operations after admission expiry.
Local Node/Deno suites, lint and type checks pass. Two isolated bundle tests verify
the actual entrypoints require a lease and expire on warm requests with flags
still true and no network calls. Hosted active/expired behavior
and actual duplicate delivery remain separate gates before further live sends.
