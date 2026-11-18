# Private database eligible for implicit Android backup

**Status:** Confirmed configuration gap; source repair and negative regressions
and local/CI packaged validation pass. Repair `c29bde9`; full source CI 44244638894
passes for `711cb27` (audit scope correction/additional negative coverage).

## Evidence / cause

M8.3 inspected the ordinary M8.2 release-validation APK and its actual referenced
backup XML. The manifest omitted allowBackup, while legacy/cloud/device-transfer
rules excluded four credential preferences only. Android's documented defaults
make other eligible app files available to the configured OS backup transport.
The local database stores private trip times, vehicle labels, account links,
metadata caches, correction notes and sync records. This is backup eligibility,
not evidence that any user's data was transmitted. Precise raw telemetry and
Guardian vaults were already under no_backup and are not a newly discovered raw
route upload. No actual device backups or private database contents were inspected.

## Repair / validation

[ADR-0045](../decisions/ADR-0045-explicit-local-data-backup-policy.md) disables
implicit backup and excludes all nine supported storage domains from legacy,
cloud and device transfer. Cleartext transport policy is explicit. The APK-aware
audit resolves resource IDs/renamed ZIP entries and checks the XML actually bound
by the manifest, alongside permissions, component protection and Firebase consent
defaults. Synthetic mutations cover old credential-only rules, missing domains,
wrong resource bindings, added permissions/exports and lost signature protection.
The old packaged artifact fails the new policy as expected. The new ordinary
release-validation APK passes actual bound-resource checks with unchanged
permission/component inventories. All 596 Flutter/601 native/nine Python policy
tests and app lint/builds pass. Repair source is
[`c29bde9`](https://github.com/atrx07/Traelyx/commit/c29bde9062791d9b07e4e39667f983c0dcfcd6a2).
All four [source CI jobs 44244638894](https://github.com/atrx07/Traelyx/actions/runs/44244638894)
pass for `711cb27`, including the independently built ordinary release policy.

## Compatibility / remaining risk

No local data deletion, schema migration or credential change. User-directed
exports remain available; automatic OS backup/migration is not an app restore
contract. The patch does not remove prior OS backup copies and is not installed
on the ordinary phone app by this audit. Physical OEM backup/restore and newer
cross-platform transfer remain unverified. See the
[privacy audit](../reference/PRIVACY_SECURITY_AUDIT_V1.md) for broader boundaries.
