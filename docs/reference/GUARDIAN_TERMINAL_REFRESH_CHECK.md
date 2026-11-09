# Guardian server-rejected refresh check

## Scope and status

M6.8 live scope approved on 2026-11-09; admission closed before any revocation
or test refresh. Pixel is restored to the ordinary app with unchanged files.
The diagnostic identified a session-change guard. A generated-session SDK
regression reproduced a probe bug: ordinary recovery replaces the Session
wrapper with unchanged grants. The probe now binds an opaque in-memory marker
to owner/access/refresh credentials and invalidates it on explicit Auth events;
it does not equate Dart object addresses with server-session identity. Targeted
checks, all 474 Flutter tests, analysis and the configured repair build pass.
Full repaired-source CI remains before device use. The ignored repair APK is
`.dart_tool/m6_8_terminal_refresh_grant_fix.apk`, SHA-256
`d0a921039ee6c70b757233b13e61deaeb089c6c113258777dbb8b081638ca3c4`.
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
tests), clean analysis and the configured diagnostic build. Diagnostic source
`78af5ba` also passes all three jobs in full
[CI 42671262274](https://github.com/atrx07/Traelyx/actions/runs/42671262274),
including native suites and debug/release builds. Inspect current admission
before any action; the original cause remains unknown. M6.8 remains incomplete.
The ignored diagnostic APK is `.dart_tool/m6_8_terminal_refresh_diagnostic.apk`, SHA-256
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
  of access-token headroom, a refresh token and the same opaque grant marker
  across native reads, before revocation and before refresh. Owner/access/refresh
  credential changes or explicit Auth lifecycle events invalidate that marker,
  including same-owner refresh and sign-out/recovery with reused credentials.
  Only a wrapper copy with unchanged grants and no intervening lifecycle event
  is equivalent. Comparisons stay in memory; never export or persist credentials.
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
budget unspent until current admission is understood and passes;
never bypass a closed guard to manufacture a result.

The diagnostic then reported `Session changed during preflight`. The pinned
supabase_flutter 2.17.2 starts `recoverSession()` after initialization without
awaiting it; GoTrue 2.27.2 recreates and saves an unexpired Session wrapper even
when owner and credentials are unchanged. A real-SDK/generated-session regression
failed on the old reference-identity marker after exactly that public recovery
call. The repair accepts only unchanged grant bytes across wrapper replacement;
changed owner/access/refresh tokens and genuine public SDK refresh/sign-out
events still invalidate the opaque marker. Missing refresh tokens close admission.
Two additional SDK tests join the existing 19 checks, and the three existing
terminal-response tests now also cover wrapper recovery. This confirms a probe
false-positive cause; no private live grant bytes were exported or compared in
operator output. It does not prove the exact timing of the earlier live change.
No ordinary app, SDK storage/refresh policy or backend behavior is changed.

## Limits

Generated-state tests and the real SDK against loopback fixtures validate the
operator, request scope and modeled owner/journal contract. They are not hosted
or native secure-storage proof. This check does not activate a driver, record a
trip, register silently, send a push, upload trip data, change clocks/network or
Auth policy, create a server secret or prove physical/OEM/vehicle reliability.
Mounted/vehicle validation remains maintainer-deferred.
