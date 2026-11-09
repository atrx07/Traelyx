# Auth refresh diagnostics escaped the identity boundary

- Status: source repair implemented; local SDK/UI regressions, all 432 Flutter
  tests, analysis and configured ordinary build pass. Exact-source CI and
  data-preserving inactive device checks pending.
- Discovery: local SDK refresh/expiry validation during M6.8, not a reported
  physical crash. Fix commit/CI will be linked after source validation.

## Confirmed cause and evidence

The pinned SDK emits a retryable refresh error through both the operation Future
and its Auth event stream. `SupabaseAccountGateway.identityChanges` used only
map/distinct, so it forwarded the diagnostic error into the app's identity-only
boundary even though SDK `currentUser` remained signed in. Guardian's ownership
listener has no error callback, and identity consumers could receive an error
instead of a stable identity snapshot. No physical crash was reproduced here.

A generated-session loopback test returned HTTP 503 from the real SDK's token
endpoint. Before repair it failed: the identity stream contained an
`AuthRetryableFetchException` while the owner remained present. The same test
passes after repair; the explicit refresh Future still fails as expected.

The Account refresh action also labeled every failure as connection trouble,
including terminal SDK refresh rejection which genuinely removes the session.
It could attribute a stale refresh result to an account which signed in while
the network request was pending.

## Repair

- Re-sample SDK identity when it emits a diagnostic stream error, without exposing
  the provider body. Distinct snapshots retain the same owner during a temporary
  failure. Genuine signed-out data events still emit null and invoke existing
  Guardian cleanup/journaling. Operation Futures retain their errors.
- Classify the post-operation owner in an application service. Account reports
  refresh success, a neutral retry failure, ended sign-in with preserved trips,
  or unavailable configuration. A result for a replacement owner is ignored.
- Preserve the SDK's normal auto-refresh, token storage and revocation behavior.
  No new retry loop, timer, dependency, endpoint, migration or permission.

This is a code repair to the adapter and refresh feedback, not a cache reset or
one-time session repair. It does not make revoked sessions valid or suppress
genuine Auth loss.

## Regression coverage and limits

Eleven new checks cover the real SDK with generated sessions and loopback-only
responses: expired access JWT refresh with retained recipient authority, HTTP
503 retention and successful retry, terminal refresh loss with modeled journal
capture and same-owner reconciliation without automatic registration, and late
200/400/503 responses preserving a replacement account. Widget/application
checks cover ended-session wording, neutral retry, stale-result feedback and
unavailable/signed-out no-op behavior. All 432 Flutter tests, analysis and the
configured ordinary debug build pass. All Guardian pilots were explicitly false.
Its ignored artifact is `.dart_tool/m6_8_refresh_fix.apk`, SHA-256
`9535d31d793441482acd60f41e4b9b8a8cb040ec2eb25bd5ff677b435656be08`.

The native owner/journal in these tests is an in-memory contract model. JWT
timestamps belong only to generated sessions; no system/device clock changed.
This does not establish hosted natural-expiry behavior, real secure-storage or
provider failure, active driver teardown or physical/OEM/vehicle reliability.
No live sign-out, forced expiry, revocation, registration, alert or trip upload
ran during the reproduction. Keep those remaining M6.8 gates separate.
