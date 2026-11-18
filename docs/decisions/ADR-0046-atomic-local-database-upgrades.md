# ADR-0046 — Atomic local database upgrades

**Status:** Accepted; focused rehearsal passes, full validation/source CI pending
**Date:** 2026-11-18

## Context

M8.4 reproduced two file-backed failure windows in schemas1–3 to4. Additive DDL
was not enclosed in one transaction. Drift2.34.3's native executor publishes
user_version after the migration callback returns. Failure during DDL left
partial new tables; failure before later version publication left new tables
with the old version. Existing rows remained, but normal reopening could refuse
the mixed schema. No actual user incident or data deletion was established.

## Decision — local upgrade policy v1

Wrap the existing recognized upgrade in one database transaction. Perform its
unchanged additive DDL and set PRAGMA user_version to the validated target inside
that transaction. Drift's later identical publication is harmless. A failed DDL
rolls back schema/version together. If the transaction committed before a later
open failure, retry sees a complete current-version image. Do not promise that
every late error implies rollback.

Schema version remains4. Bootstrap recognition and unsupported-version refusal
remain intact. Do not use schema_version (SQLite's internal schema cookie) for
this purpose. Existing scores/model versions, raw references, settings, consent,
queues and corrections are never rewritten or recomputed. Existing already-mixed
files are not silently repaired; they require separately reviewed recovery.

See SQLite's [user_version](https://www.sqlite.org/pragma.html#pragma_user_version)
and [transaction semantics](https://www.sqlite.org/transactional.html). Local
pinned Drift native-executor source confirms its version-publication ordering;
the regression intercepts real migration execution at both observed boundaries.

## Validation / consequences

The versioned rehearsal uses frozen schemas, actual file-backed DELETE/WAL modes,
1,000-trip histories, exact historical row comparisons, schema/FK/integrity checks,
reopens and synthetic sidecar-byte digests. It injects failures before a later DDL
and after the migration callback, then verifies an atomic image and successful
retry. This is not an actual process kill, physical power loss, OEM/storage-fault
certification or signed APK upgrade test. No dependency, raw/scoring schema,
permission, network operation or ordinary phone installation changes.
