# Interrupted local upgrade leaves schema and version out of sync

**Status:** Confirmed synthetic reproduction; preventive repair and 23-case
rehearsal pass locally. Full validation/source CI and fix commit pending.

## Evidence / cause

M8.4's file-backed v1 fixture reproduced both failures on the old source:

- Failure after creating trip_account_links but before account_metadata_cache
  left the first new table behind with user_version1.
- Failure after the callback completed but before Drift's version publication
  left all new tables present with user_version1.

All original rows remained in the observed fixtures. The recognized-v1 guard
then rejects the mixed shape on normal reopen. This is an availability/retry
defect, not proof of a past real-user incident, row loss or corrupt raw telemetry.
The cause is additive DDL without an encompassing transaction plus a later,
separate version publication in the pinned native executor.

## Repair / regression

[ADR-0046](../decisions/ADR-0046-atomic-local-database-upgrades.md) defines upgrade
policy1: commit all existing DDL and the target user_version in one transaction.
Schema4, algorithms, historical results and unsupported-shape refusal remain.
The old two probes fail as expected; repaired execution passes schema1/2/3→4 and
4→4 in DELETE/WAL, populated histories/reopens, both interruption boundaries with
retry, bootstrap and unchanged future/unknown-schema refusal. Aggregate evidence
and source validation live in the [rehearsal](../reference/DATABASE_UPGRADE_REHEARSAL_V1.md).

## Recovery / limits

This prevents the reproduced future windows; it does not auto-repair a database
already left in a mixed state. Retain the original database and any journal files
for separately reviewed private recovery. Never delete tables, reset the version,
recompute old scores or restore arbitrary backups to make it open. No actual user
database was read or changed. Physical power/process-kill/storage faults and
signed Android install/upgrade remain unverified; M8.8/M8.9 are separately gated.
