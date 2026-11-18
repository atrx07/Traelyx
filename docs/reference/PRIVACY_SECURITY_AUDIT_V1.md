# M8.3 privacy/security audit v1

**Date:** 2026-11-18
**Status:** Active — source/local/package checks pass; source CI pending
**Source base:** `f138d2e`

This is a bounded source, packaged-policy and synthetic authorization audit of
permissions, RLS, logs, exports, provider payloads and Guardian access. It is not
a penetration-test certificate, hosted deployment audit or physical OEM proof.
The [execution plan](../exec-plans/active/M8_PRIVACY_SECURITY_AUDIT.md) records
validation and source provenance. No live credentials, private trips, real
provider sends, hosted mutations or ordinary phone installs are used.
See the [aggregate report](m8-privacy-security-v1-result.json) for APK hash and
executed check totals: 596 Flutter tests, 601 native tests, nine Python privacy
tests, analysis, app lint and both ordinary builds pass. Packaged policy passes
with the unchanged 10 permissions/three exports and all backup domains excluded.
PostgreSQL catalog/behavioral and Edge execution remain subject to source CI.

## Findings / disposition

1. **Private database eligible for OS backup — source repaired.** Missing
   allowBackup plus credential-only rules left private trip times, vehicle labels,
   account-linked metadata and correction/sync data eligible. This is not evidence
   of actual transmission. Raw telemetry/Guardian vaults already used no_backup.
   Policy v1 disables implicit backup and excludes all nine storage domains for
   legacy/cloud/device transfer. Keep user-directed export separate. See
   [ADR-0045](../decisions/ADR-0045-explicit-local-data-backup-policy.md) and
   [the issue](../issues/2026-11-18_android-backup-eligibility.md).
2. **Noncanonical auth callback authority — source hardened.** The recognizer
   accepted user information and explicit ports on the configured host/path.
   Three synthetic URI variants reproduce the boundary issue; both are now
   rejected. Normal code/error query handling and SDK PKCE verification remain.
   This did not establish an account takeover or PKCE bypass.
3. **Cleartext policy — explicit defense.** The target-SDK default already denied
   cleartext for applicable platform stacks. Explicit usesCleartextTraffic=false
   makes the intended policy auditable; no observed plaintext request is claimed.
4. **Private security reporting — pre-release follow-up.** SECURITY.md still has
   a maintainer-specific reporting placeholder. The release checklist now requires
   confirming a private reporting channel before publication; no contact/address
   or external repository setting was invented or changed.

## Evidence matrix

| Surface | Inspected boundary | Executed / required evidence |
| --- | --- | --- |
| Android permissions/components | Main manifest, Firebase consent defaults and ordinary merged release; QA hosts isolated | APK-aware audit pins 10 permissions and 3 exports; rejects unexpected grants/exports, QA/debug builds, automatic Firebase init and lost signature protection |
| Local credentials/backups | SecureAuthStorage/PKCE and CommentarySecureStore use distinct Keystore-backed namespaces; Guardian AES-GCM vaults under no_backup; database schema/default path | Existing secure-store tests plus new old-policy/missing-domain/wrong-resource negative cases; actual bound packaged XML must pass |
| Logging/diagnostics | initializeAccount debug=false; normalized provider/auth errors; DiagnosticsSnapshotCollector and DiagnosticsReport aggregate fields | Full Flutter/native regression suites. First-party production log call emits Guardian receive-stage enum only; no raw body/ID/route logging found in inspected sources |
| Exports/deletion | MainActivity ACTION_CREATE_DOCUMENT, exact UUID native guards, precise-private warning, RedactedTripSummaryPayload, CorrectionContributionPayload | Data export UI/repository, native redaction/unknown-field/categorical-contribution and recorder-state tests; user-selected provider may independently sync saved files |
| Optional network payloads | CompactTripSummary exact 8-field schema; ReviewedCommentaryInput categorical/approved-wording dossier; fixed HTTPS Groq endpoint, no redirects, bounded responses/cancellation | Summary owner/consent tests, provider transport/dossier/one-use review/fallback tests; offline canvas makes no tile requests; no real send performed |
| Public/private RLS | All 17 current production tables, owner policies, invoker/definer grants, sanitized public-profile/ranking projections | Existing actual PostgreSQL cross-owner/anonymous/consent/revocation fixtures plus new catalog assertions and eight rollback-only negative probes; CI execution required |
| Guardian | Server participant/revision/permission/expiry predicates; location/speed/history unsupported; separate activation/device consent, no-backup vaults, data-only push, guarded inbox and revocation | Flutter/native owner-change/revoke/receipt tests, SQL pairing/delivery/worker/receiver/revision fixtures and Edge processing-window/auth/payload tests; hosted/physical acceptance remains held |

## Ordinary Android inventory / rationale

The packaged policy gate allows exactly these existing permissions:

- COARSE/FINE_LOCATION: explicitly started trip GNSS acquisition.
- FOREGROUND_SERVICE / FOREGROUND_SERVICE_LOCATION: visible native recording.
- WAKE_LOCK: bounded recorder CPU policy and the existing FCM dependency surface.
- POST_NOTIFICATIONS: recorder/optional reviewed Guardian notices.
- INTERNET / ACCESS_NETWORK_STATE: optional configured auth/sync/commentary/Guardian
  and dependency connectivity; not a permission to upload raw telemetry.
- com.google.android.c2dm.permission.RECEIVE: consent-gated optional FCM receiver.
- App DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION: signature-protected AndroidX
  dynamic receiver isolation; not a dangerous runtime grant.

The only exported ordinary components are MainActivity (launcher and guarded
auth/Guardian notice links), FirebaseInstanceIdReceiver protected by
com.google.android.c2dm.permission.SEND, and ProfileInstallReceiver protected by
android.permission.DUMP. Recorder, app messaging service and cancellation receiver
are not exported. No storage, background-location, contacts, microphone, camera,
SMS, phone-state or advertising-ID permission is admitted. New permission or
component inventory requires deliberate review rather than automatic acceptance.

## Reproduction

```powershell
python -W error::ResourceWarning -m unittest tests.tool.test_android_privacy
flutter analyze
flutter test
# Build ordinary release validation, then supply actual SDK tool paths.
python tool/audit_android_privacy.py --apk build/app/outputs/flutter-apk/app-release.apk --apkanalyzer $apkAnalyzer --aapt2 $aapt2 --output .dart_tool/privacy-android-result.json
```

The Python verifier decodes the actual manifest and backup XML, resolves their
compiled IDs and resource-shrunk ZIP paths, checks binding equality and records
APK size/hash. It prints aggregate finding codes only. No APK extraction, network
or user-data access is involved. CI retains its report as an artifact. PostgreSQL
CI applies all migrations and runs supabase/tests/privacy_security_audit.sql after
the behavioral suites: RLS, table/column anonymous grants, empty definer search
paths, PUBLIC execution, server-only RPCs and private Guardian table grants are
checked. Temporary injected regressions are rolled back; no production migration.

## Compatibility / residual limits

No schema migration, new dependency, permission addition, credential rotation,
sampling/power change or cloud/provider activation. Android implicit backup and
device-transfer eligibility change intentionally; local files remain untouched.
Older OS backup copies are not recalled. The installed ordinary app is unchanged.
No real backup/restore, OEM migration, newer cross-platform transfer, hosted natural
expiry, live Guardian or production provider behavior is certified. The database
relies on platform-private storage; this work does not add database encryption
or protect a compromised/rooted device. Exported files and copied invite codes
are outside later app revocation control. Secret scanning covers known patterns
and reviewed stores, not exhaustive history/dependency/advisory certification.

M6.8/M7 acceptance, recorder CPU/battery profiling and main distribution holds
remain. A saved consent preference is not proof of operational alert delivery.
No work on M8.4 is authorized by this audit.
