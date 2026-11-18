# ADR-0045 — Explicit local-data backup policy

**Status:** Accepted; packaged validation passes, source CI pending
**Date:** 2026-11-18

## Context / decision

M8.3 found credential-only backup exclusions alongside a missing allowBackup
declaration. The local database contains private trip times, vehicle labels,
account-linked metadata and correction/sync records. Making those eligible for
implicit OS backup is inconsistent with the reviewed optional cloud boundaries.
Raw telemetry and Guardian vaults already use no-backup storage; no actual past
upload or restore was established by this audit.

Policy v1 sets allowBackup=false and excludes every credential/device-protected
backup domain in both legacy and Android 12+ cloud/device-transfer rules. Keep
explicit credential-file exclusions as additional documentation and protection.
Do not rely on the manifest flag alone for OEM device transfer. See
[Android backup semantics](https://developer.android.com/identity/data/autobackup).
Also declare cleartext transport disabled explicitly; production endpoints already
use HTTPS. The packaged audit checks the actual resource bindings, decoded XML,
permissions, exports and consent defaults, including resource-shrunk APKs.

## Consequences / limits

Local data is device-bound unless explicitly exported. OS backup/phone migration
must not be advertised as a restore mechanism. User-selected export destinations
may sync independently; exports are not a promised in-app restore implementation.
No local file is deleted or moved; no database/raw schema or credential format
changes. This source change cannot recall/delete older OS backup copies. OEM
backup/restore execution and newer cross-platform transfer behavior are not
physically validated; no cross-platform transfer integration is configured.

Future optional backup needs separate consent, data/restore design and policy
review. No new dependency, permission, network send or hosted operation accompanies
this decision. Publication and carried M6.8/M7 acceptance remain held.
