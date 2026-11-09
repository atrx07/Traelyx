# Guardian server-rejected refresh check

## Scope and status

M6.8 live scope approved on 2026-11-09; admission closed before any revocation
or test refresh. Pixel is restored to the ordinary app with unchanged files.
This follows the passed [normal rollover observation](GUARDIAN_PASSIVE_REFRESH_CHECK.md).
The alternate debug entrypoint is `tool/guardian_terminal_refresh_probe.dart`;
ordinary app code never imports it. Sixteen new operator/SDK checks,
all 469 Flutter tests, clean static analysis, repository validation and the
configured gated debug build pass. The ignored prepared APK is
`.dart_tool/m6_8_terminal_refresh_probe.apk`, SHA-256
`f654e810e9e2fc889febc5cd7da81dad6dab0bd8bea772a24dcd50d4cbbb4235`.
Source `5597d7e` passes full
[CI 42666565560](https://github.com/atrx07/Traelyx/actions/runs/42666565560):
all three jobs, native suites, debug/release builds, cloud grants/RLS and Edge
checks are green. That source's live admission did not become ready. Fixed
admission diagnostics now pass three additional regressions (all 472 Flutter
tests), clean analysis and the configured diagnostic build. Exact-source CI
must pass before continuation. M6.8 remains incomplete. The ignored diagnostic
APK is `.dart_tool/m6_8_terminal_refresh_diagnostic.apk`, SHA-256
`8ff5c300905e87a6e1dc6c006d33fa4ceafa93360d71ae8cd68222c65de41fbf`.

The existing recipient-consent recovery build is prepared locally at
`.dart_tool/m6_8_terminal_refresh_recipient.apk`, SHA-256
`8314db3c9bfb162942103ec12aa6cfc4ea93e56394bad6e2581498a3efcc2eef`.
It is not installed. The saved ordinary pilot-off restoration APK remains
`.dart_tool/m6_8_refresh_fix.apk`, SHA-256
`9535d31d793441482acd60f41e4b9b8a8cb040ec2eb25bd5ff677b435656be08`.

This checks **deliberate own-session server revocation followed by a rejected
refresh**, not spontaneous expiry. The current hosted policy has no terminal
session timebox/inactivity timeout. No paid policy control, global logout,
service-role credential, admin account operation or new dependency is needed.

## Transport and admission

The pinned GoTrue SDK's `auth.admin.signOut(existingAccessToken,
scope: SignOutScope.local)` transport sends the same `/auth/v1/logout?scope=local`
request used by its ordinary local sign-out wrapper. Despite the transport's
class name, this request uses only the current session's existing user JWT and
public client configuration. It does not call an `/admin/users` endpoint. Calling
only that transport leaves local SDK Auth in place. Then one ordinary gateway
refresh must receive a recognized terminal server error and the real SDK must
remove its session. See [Supabase sign-out scopes](https://supabase.com/docs/guides/auth/signout).
An unexpired access JWT can remain valid after server revocation; this probe
does not claim immediate JWT invalidation or change project policy.

- Require debug mode, the explicit `TRAELYX_GUARDIAN_TERMINAL_REFRESH_PROBE`
  define, the intended Traelyx project and all three Guardian pilots false,
  before initializing Auth. Both hosted Guardian functions must stay disabled.
- Require an existing signed-in idle Pixel receiver, disabled driver and empty
  recipient/driver journals. Check journals after status recovery so a newly
  retained cleanup ticket cannot escape admission. Require at least two minutes
  of access-token headroom and the same in-memory Session object across native
  reads, before revocation and before refresh. Same-owner token replacement also
  closes the probe. Do not export or persist session references or credentials.
- One synchronous stage transition spends the action before any await. At most
  one server revocation and one refresh invocation occur. Timeout, lifecycle
  cancellation, delayed native results, changed authority, errors or uncertainty
  never retry. Every asynchronous phase has a 30-second timeout; the sequence
  is bounded to five phases (up to 150 seconds). Timeout cannot cancel a request
  already sent: retain the production observer and inspect actual state before
  recovery, rather than inferring that no side effect happened.
- Revocation must leave the same local session and receipt intact. A local
  sign-out event at this point cannot count as server-rejection proof.
- A pass needs a recognized terminal error code/status from the ordinary SDK
  refresh, absent local SDK session/identity, and completed production owner
  binding cleanup. A successful refresh, unknown error, retained/replacement
  owner or failed cleanup cannot pass. UI shows fixed labels only.

The probe uses the ordinary owner binding, driver stopper and device revoker.
Terminal loss must clear native authority and retain its exact recipient revoke
ticket for later same-owner reconciliation. The signed-out probe cannot read
bound-owner tickets or authenticated server rows: independent private file checks
and the subsequent reviewed ordinary-app recovery must establish those results.
The UI success label alone does not prove secure storage/provider reliability.

## Reviewed live sequence (approved; no action started)

1. After source CI, obtain specific production review covering one Pixel
   own-session revocation, one refresh, original-owner email-link recovery and
   fresh personal recipient consent. Keep Tecno, pairing, trips and all backend
   flags unchanged. This preparation does not authorize that live mutation.
2. Recheck both devices/accounts, idle recorders/drivers, existing receiver
   validity, hosted aggregate baseline and false enable flags. Save fresh private
   file fingerprints and the ordinary configured APK. Preserve the accidental
   Tecno trip and its private QA exclusion described in the rollover report.
3. Update-install the gated probe on Pixel without clearing data. Confirm ready
   state and run its action once. Keep foreground. On uncertainty or timeout,
   restore the ordinary app for review; do not press again or silently recover.
4. Independently confirm local receipt/provider removal, retained encrypted
   cleanup journal, unchanged recorder files and unchanged hosted receiver row.
   Do not print tokens, account/receipt IDs, emails or raw device logs.
5. Restore the ordinary app. The maintainer signs into Pixel's original account
   via a new link inside Pixel. Verify exact server-row reconciliation without
   automatic registration and preserved pairing. Only fresh personal review can
   recreate the private receiver registration. Restore the ordinary pilot-off
   build after any recipient-only consent build.
6. Verify both original sign-ins, receiver validity, recorder preservation,
   empty cleanup journals, no driver/recorder, restored aggregate baseline,
   disabled flags and no temporary worker file. Record the actual outcome and
   persist closure. A failed phase stays unverified.

## Admission checkpoint — 2026-11-09

The maintainer approved the complete one-action/recovery scope. Fresh hosted
counts were `0/0/0/2/2/1/1`, both enable digests matched false, both original
accounts were signed in and both networks validated, with no recorder/driver.
New private baselines included Pixel's zero recorder files and all 11,865 current
Tecno files, including the preserved accidental recording. Both devices' receiver
files were present. The original 11,857-file historical proof remains retained.

The probe update preserved Pixel's exact receipt/provider files, but displayed
`Probe closed; no action available`. After ordinary startup/sign-in preservation
was verified, one admission-only restart remained closed. Its action button was
never available or invoked. Pixel was restored to the ordinary build with exact
receiver/provider/recorder preservation; no deliberate server-session revocation
or test refresh occurred. The admission cause is not yet established.

The probe now maps only configuration, initialization, session/headroom and
individual native-read failures to fixed labels. It exports no exception text,
identity, credential or receipt data and relaxes no admission guard. Three new
guard/category/UI regressions join the prior 16 tests. Keep the approved action
budget unspent until the reason is understood and validated source is ready;
never bypass a closed guard to manufacture a result.

## Limits

Generated-state tests and the real SDK against loopback fixtures validate the
operator, request scope and modeled owner/journal contract. They are not hosted
or native secure-storage proof. This check does not activate a driver, record a
trip, register silently, send a push, upload trip data, change clocks/network or
Auth policy, create a server secret or prove physical/OEM/vehicle reliability.
Mounted/vehicle validation remains maintainer-deferred.
