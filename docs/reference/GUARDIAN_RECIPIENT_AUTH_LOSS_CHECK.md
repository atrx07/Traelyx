# M6.8 controlled recipient Auth-loss check

## Scope and gate

Read for the next desk-safe recipient lifecycle check, after the completed
[explicit sign-out/recovery check](GUARDIAN_RECIPIENT_LIFECYCLE_CHECK.md).
The separately approved live check passed on 2026-10-21: controlled local Auth
loss, normal same-account reconciliation, fresh personal receiver consent and
restoration of the ordinary pilot-off build. This single-check scope is closed.
M6.8 remains incomplete. Mounted/vehicle tests remain deferred.

The alternate debug entrypoint deliberately calls the raw SDK's local sign-out
instead of the app's explicit server-first Sign out. The production Auth observer
and native owner-loss cleanup should capture an ID-only revoke ticket, remove
local receipt/provider state and leave the server device row for later normal
same-account reconciliation. This is controlled fault injection, not proof of
natural token expiry, third-account switching or failed-network recovery.

## Implementation and validation

- `tool/guardian_recipient_auth_loss_probe.dart` is separate from ordinary
  `lib/main.dart`. Debug mode, an explicit default-off define and the exact
  reviewed project URL gate Auth initialization. Release/closed/other-project
  configurations expose no action and initialize neither Auth nor native ports.
- Native snapshot/journal reads require owner binding in a new process. The
  probe uses the production bound account gateway without a server device
  revoker. Existing tickets make binding fail closed and remain retryable in the
  ordinary app. Initial binding may clean stale local authority; inspect the
  fresh device baseline before installing. No Guardian RPC is wired in the probe.
- Preparation and the single action require stable Auth, an empty owner-scoped
  journal, a registered receipt and disabled driver state. Recheck after each
  await. The action also requires the same receipt generation. The operator
  separately verifies no active recorder, the Pixel guardian role and network.
- One action per process, with its spent flag set before any await. Exceptions
  after the SDK call begins are uncertain, never a success or an automatic retry.
  Keep the Auth observer alive for late completion; restore the ordinary app
  rather than relaunching this probe to retry. Output contains only fixed stages.
- Ten new tests cover closed configurations, cold-start binding, missing
  prerequisites, owner/receipt/driver changes, one-shot behavior, SDK/native
  failure, late Auth loss after timeout, private-output exclusion and modeled
  journal capture followed by ordinary same-owner reconciliation. The native
  fake models the journal contract; it does not prove Android provider reliability.

Local preparation passes (2026-10-21): ten new probe tests, all 405 Flutter tests,
analysis, repository validation and configured alternate debug build. The ignored
APK `.dart_tool/m6_8_recipient_auth_loss_probe.apk` has SHA-256
`4814959d13ec5e5d180e5b9152f25385a9952caef36446496947e3b3a83cbb15`.
The preserved ordinary and recipient-only APK hashes remain in the preceding
lifecycle report. Source `2f200f1` passes all three jobs in
[CI 39584283376](https://github.com/atrx07/Traelyx/actions/runs/39584283376),
including native tests, SQL/Edge checks and debug/release-validation builds.
The preparation gate is closed; the specific live approval was subsequently granted.
No schema, dependency, permission or ordinary app entrypoint changes are needed.
Neither device was updated and no live sign-out, server revocation or
registration ran during preparation.

## Reviewed production scope

The approved scope was to update-install only this probe on Pixel without clearing
data, perform one raw SDK local sign-out, inspect credential-free local state
and hosted aggregate counts, then restore the ordinary pilot-off app. Supabase
Auth may invalidate this account's current session; the probe does not invoke
Guardian server device revocation. Native cleanup deletes the local Firebase
routing state and retains only the owner-scoped revoke ticket for reconciliation.

The maintainer then signs into the **same Pixel account** by a new email link
inside the emulator. Ordinary startup should revoke the old server device row
and confirm its journal ticket before reporting a successful owner-bound local
check. Fresh personal receiver consent is required to create a replacement
Firebase token/private Supabase registration, using the recipient-only pilot if
needed; restore the ordinary build afterward.

Both Guardian functions stay false throughout. No driver session, fixture,
worker credential, event, delivery, push, trip upload, recording, permission,
pairing, profile or Google backend-key change. Preserve the Tecno and its trips.

## Bounded sequence after approval

1. Freshly verify both devices authorized/online/idle, existing roles/pairing,
   both driver vaults absent and no pending recipient cleanup. Capture new private
   recorder/receipt/provider manifests; do not reuse the previous check's baseline.
   Require sessions/events/deliveries/devices/unexpired/pairs/ready pairs =
   **0/0/0/2/2/1/1**, both flags false and no local test worker file.
2. Install the prepared probe only on Pixel with `install -r`. Verify retained
   Auth and unchanged valid receipt/provider bytes before its one action. A closed
   result means stop and restore the ordinary app; never bypass a prerequisite.
3. Perform the action once. Require confirmed signed-out/local cleanup stage,
   receipt/provider absence and retained journal file without opening its contents.
   Hosted device counts must remain **2/2** and pairing remain **1**. A journal
   file alone does not prove its ticket contents; later exact server revocation
   and successful foreground binding supply the reconciliation evidence.
4. Restore the ordinary pilot-off APK **before sign-in**. Let the maintainer
   complete the same-account email link. Require hosted device counts **1/1**,
   pairing **1**, no local registration, and a successful explicit Check this
   phone result. Do not manually delete a row or ticket to force these counts.
5. Obtain fresh personal receiver review, verify replacement registration and
   original aggregate baseline, then restore ordinary pilot-off APK preserving
   replacement receipt/provider bytes. Verify Tecno manifests unchanged and no
   driver/recording/event/send. Both accounts remain signed in.
6. On any uncertainty, stop the fault injection, retain retryable state and
   inspect safely under the reviewed recovery scope. Do not repeat sign-out,
   clear app data, uninstall, change enable flags or discard journal evidence.
   Report a partial result; emulator evidence cannot establish physical reliability.

## Reviewed live result — passed (2026-10-21)

After a usage-limit interruption, both ADB devices were rechecked authorized,
online and idle. New private baselines retain all 11,857 Tecno recorder files
and zero Pixel recorder files; both driver vaults are absent. Read-only hosted
counts remain 0/0/0/2/2/1/1 and both enable digests represent false. Pixel's
ordinary app confirms Signed in, the existing paired guardian role and its local
receiver registration before installation.

The reviewed probe APK was installed with `install -r`. It reported Ready and
the receipt/provider bytes remained identical. Its one action reported
“Sign-in cleared; local owner cleanup confirmed.” Pixel receipt/provider files
are absent, recorder evidence is unchanged, and the encrypted revoke journal
remains present with changed ciphertext. Hosted counts remain 0/0/0/2/2/1/1:
the old server row was not prematurely revoked. File presence/ciphertext change
alone does not establish ticket contents or successful future reconciliation.

Ordinary pilot-off source `37906dc` was restored before sign-in. Pixel's Account
screen showed the sign-in form, local receipt/provider remained absent and the
journal was retained. The maintainer then completed the same-account email link.
Normal startup reduced hosted counts to **0/0/0/1/1/1/0**, retaining the pair.
The explicit Check this phone completed successfully and reported no local
registration, with receipt/provider still absent. Those combined observations
support normal same-owner reconciliation without automatic registration; journal
plaintext and private identifiers were not read or exported.

The maintainer personally confirmed fresh recipient review in the recipient-only
pilot. New receipt/provider state appeared and hosted counts returned to
**0/0/0/2/2/1/1**. The ordinary source `37906dc` APK was restored; the replacement
receipt/provider bytes match the pre-restoration fingerprints exactly. Both
accounts remain signed in, and the ordinary app's explicit Check this phone
confirms Pixel registration. Tecno's 11,857 recorder files and receipt/provider
hashes match the new pre-test baseline. Pixel has zero recorder files and both
driver vaults remain absent. Final dashboard digests still represent false for
both processing flags; no worker file exists and no alert, driver session,
recording, trip upload, schema, permission or backend-key change ran.

This closes the controlled local Auth-loss/same-account reconciliation gate only.
Natural refresh/expiry failure, failed-network recovery, third-account switching
and physical/OEM reliability remain unverified live. Vehicle gates remain
deferred; do not infer M6.8 completion or authorize a rerun from this result.
