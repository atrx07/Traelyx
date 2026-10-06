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
| 2026-10-06 | [Android Guardian receipt regex fails at initialization](2026-10-06_android-guardian-receipt-regex.md): synthetic phone receipt probe stops before HTTPS | Repaired in `94eadff`; source CI, physical parser and hosted receipt/retry pass |
| 2026-09-27 | [Long-trip finalization exhausts Android heap](2026-09-27_long-trip-finalization-oom.md): End drive appears frozen, then repeated startup crashes | Root cause repaired in `691bb57`; original trip recovered; longer-duration limits remain unverified |
| 2026-09-30 | [Auth decorator hid optional cloud providers](2026-09-30_auth-decorator-cloud-providers.md): hosted features selected unavailable gateways after sign-in | Provider selection repaired in `103d3d7`; CI passed, account-switch QA remains |
