# Product issues and incidents

## When to read

Search this index when investigating a product failure or reviewing a related
subsystem. Read only matching records. These records preserve debugging and
recovery knowledge; current behavior contracts remain in the feature specs,
current project state in `STATUS.md`, and scheduled work in execution plans.

Use `YYYY-MM-DD_descriptive-name.md` for significant incidents. Include status,
affected path, observed symptoms, confirmed cause, evidence, recovery actions,
fix commit, regression checks, privacy/migration impact, and unresolved limits.
Distinguish a durable code repair from a workaround or one-time recovery.
Reopen/update a record if the same failure recurs. Keep raw logs, routes, user
identifiers and private fixtures outside Git; include only sanitized evidence.

Local host/build/tool failures belong in
[`KNOWN_TOOLING_ISSUES.md`](../reference/KNOWN_TOOLING_ISSUES.md).

| Date | Issue / symptoms | Status |
|---|---|---|
| 2026-11-18 | [Interrupted database upgrade](2026-11-18_interrupted-database-upgrade.md): additive tables and old version could remain after failure, blocking reopen | Preventive atomic-upgrade repair and 23-case rehearsal pass; full validation/source CI pending |
| 2026-11-18 | [Android backup eligibility](2026-11-18_android-backup-eligibility.md): credential-only exclusions left private database eligible for OS backup | Repaired in `c29bde9`; local/CI packaged policy and full CI 44244638894 pass; actual past upload/OEM behavior unverified |
| 2026-11-18 | [Unplugged screen-off recorder gaps](2026-11-18_screen-off-recorder-suspend.md): active service had ~263-second motion gaps without GPS fixes | Repaired in `dfc316a`; bounded lifecycle/continuity and full CI 44239049290 pass; field/efficiency limits retained |
| 2026-11-17 | [Isolated sync-pilot export selection](2026-11-17_sync-pilot-export-selection.md): cancelling the picker changed the selected retained run | Repaired in `68d91d6`; API34 manual/instrumentation and full source CI 44085930694 pass; main trip export unaffected |
| 2026-11-09 | [Auth refresh identity-stream errors](2026-11-09_auth-refresh-identity-stream.md): retryable SDK diagnostics escaped into ownership listeners; terminal refresh loss got connection advice | Repaired in `dc82ed1`; 432 Flutter tests, full CI 42601051068 and inactive Tecno/Pixel preservation checks pass; hosted natural expiry remains unverified |
| 2026-10-17 | [Guardian cleanup identity loss](2026-10-17_guardian-cleanup-identity-loss.md): destructive outbox failure could erase the only exact server-cleanup ID | Repaired in `6e4b50d`; local, physical synthetic and full CI checks pass; physical fault injection unverified |
| 2026-10-10 | [Guardian processing window overrun](2026-10-10_guardian-processing-window-overrun.md): usage-limit interruption left test flags enabled beyond the reviewed deadline | Production closed, zero attempts verified, fixture removed; automatic expiry source tested, deployment pending |
| 2026-10-06 | [Android Guardian receipt regex fails at initialization](2026-10-06_android-guardian-receipt-regex.md): synthetic phone receipt probe stops before HTTPS | Repaired in `94eadff`; source CI, physical parser and hosted receipt/retry pass |
| 2026-09-27 | [Long-trip finalization exhausts Android heap](2026-09-27_long-trip-finalization-oom.md): End drive appears frozen, then repeated startup crashes | Root cause repaired in `691bb57`; original trip recovered; longer-duration limits remain unverified |
| 2026-09-30 | [Auth decorator hid optional cloud providers](2026-09-30_auth-decorator-cloud-providers.md): hosted features selected unavailable gateways after sign-in | Provider selection repaired in `103d3d7`; CI passed, account-switch QA remains |
