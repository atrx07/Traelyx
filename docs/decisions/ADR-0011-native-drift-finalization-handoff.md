# ADR-0011 — Crash-safe native-to-Drift finalization handoff

**Status:** Accepted

## Context

Kotlin owns recorder lifecycle and app-private raw chunks, while Drift owns local trip history. Clearing active recovery metadata before Drift indexing can orphan a stopped trip; indexing before native flush can publish a partial active catalog. A process can die between any native, bridge, or database step.

## Decision

After acquisition flushes, native Kotlin atomically persists a versioned pending-finalization record before clearing active recovery metadata. The versioned bridge returns lifecycle metadata plus a freshly verified chunk catalog using stable relative app-private storage references, never absolute paths or raw telemetry.

Flutter reconciles one trip and its complete verified chunk index into Drift schema v1 in a single idempotent transaction. It acknowledges and removes the native pending record only after that transaction commits. A crash before commit replays the native handoff; a crash after commit replays the idempotent transaction. Raw chunks remain native and app-private.

Schema v1 requires a vehicle foreign key. Until vehicle onboarding exists, recorder finalization inserts one stable accountless local placeholder vehicle only when absent. Reconciliation preserves any later user vehicle reassignment.

## Consequences

Positive:

- Stop and interrupted Stop remain recoverable across process death;
- Drift never indexes an active or partially flushed native stream;
- transaction failure cannot acknowledge or delete the native handoff;
- corrupt, orphaned, recovered, and recorder-error evidence remains explicit;
- no schema migration, dependency, network, or raw-data bridge is required.

Negative:

- native and Dart maintain separate versioned finalization contracts;
- a stopped trip can remain pending until Flutter reopens successfully;
- one placeholder vehicle row exists before user-facing vehicle assignment.

## Revisit if

Trip/vehicle onboarding changes the schema-v1 ownership contract, raw chunks move into a different storage authority, or a future platform provides an equivalent transactional cross-runtime persistence primitive.
