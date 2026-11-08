# M6.8 recipient account-replacement check

## Scope and current gate

Preparation only, 2026-11-08. The isolated probe is not installed and no live
account replacement is approved or run. The preceding interruption recovery is
closed in [the recovery report](GUARDIAN_RESUME_20261108.md). Both ordinary builds
and existing registrations are restored. Mounted/vehicle tests remain deferred.

The next proposed check uses Pixel's existing guardian account, then the existing
Tecno account on Pixel, then returns to Pixel's original account. It needs no
third account or new profile/pairing. This would establish different-owner
replacement for those two accounts; it would not establish unpaired third-account
behavior, natural Auth expiry or physical/OEM reliability.

## Isolated probe contract

`tool/guardian_recipient_account_switch_probe.dart` is an alternate entrypoint,
never imported by the ordinary app. It requires a debug build, the dedicated
`TRAELYX_GUARDIAN_ACCOUNT_SWITCH_PROBE=true` define and the reviewed project URL.
Closed configurations do not initialize Auth. No new dependency, schema, app
permission, production entrypoint, Guardian server RPC, registration, driver
activation or push sender is added.

- Preparation binds the production native owner port and requires stable signed-in
  ownership, an existing receiver, no pending owner-scoped revoke ticket and a
  disabled driver. Binding itself can clean stale native state; capture fresh
  baselines before installing and restore ordinary on any closed/uncertain result.
- After personal input, one action rechecks owner, driver, pending cleanup and
  receipt generation before requesting a normal SDK email link. It never calls
  Sign out. The action is spent before any await; failure/restart is not approval
  to request another link. A same-owner refresh cannot count as replacement.
- A different-owner callback must finish production native binding, report no
  local recipient and keep the driver disabled, with the new owner stable after
  every await. Null Auth, another owner change, provider failure, timeout or
  incomplete native cleanup is uncertain. The ordinary owner observer stays
  alive to clean late Auth transitions; there is no automatic sign-out/retry.
- The probe deliberately supplies no Guardian server revoker. Native binding
  journals the prior receiver IDs before erasing its authority/provider state;
  the old server row is reconciled only after the original owner returns in the
  ordinary app. The replacement owner cannot access the old owner's ticket.
- The UI clears the entered email after its single action and prints fixed
  stages only, without identities, tokens, receipts, links or raw exceptions.
  The maintainer alone enters email and opens the link inside Pixel.

## Local validation

Sixteen new regressions cover closed configuration, missing prerequisites,
one-shot requests, retained state before callback, changed owner/receipt/driver,
same-owner refresh, early callback, provider/native failure, null Auth, another
replacement during verification, late timeout and private UI output. The native
fake models journal/owner isolation; it is not Android provider or live RLS proof.
All **421 Flutter tests**, analysis and the configured alternate debug build pass.
The ignored `.dart_tool/m6_8_account_switch_probe.apk` has SHA-256
`c29be7f66ab4669177bb2df0f0d90a707f01155f80600f1554510bd91c1ab375`.
Repository/format validation passes. Exact-source full CI must pass before
requesting the live scope; neither device has been updated with this probe.

## Proposed live scope — requires separate review

1. Freshly verify both ordinary builds, signed-in accounts, registrations,
   validated connectivity and no recorder/driver vault. Capture new private
   manifests; require hosted sessions/events/deliveries/devices/unexpired/pairs/
   ready pairs **0/0/0/2/2/1/1**, both flags false and no local worker file.
2. Data-preserving update of Pixel only to the configured probe. Verify ready
   stage and unchanged receipt/provider. The maintainer requests one link for
   the existing Tecno account and opens it inside Pixel. Before handing off the
   request, persist that it may have started; never replay it from a restart or
   ambiguous checkpoint. No Tecno Auth action.
3. Require completed replacement stage, absent local receipt/provider, retained
   encrypted journal and unchanged recorder files. Hosted counts must remain
   **0/0/0/2/2/1/1**: the old row must not be deleted using another owner. File
   presence alone does not prove journal contents; later exact reconciliation
   and deterministic contract tests provide separate evidence.
4. Restore ordinary Pixel without clearing data. Confirm the replacement account
   is signed in and unregistered locally. One explicit local Sign out must leave
   Tecno's separate device row intact and counts unchanged. The maintainer signs
   into Pixel's original account by a new email link inside Pixel.
5. Ordinary same-owner reconciliation must remove only Pixel's old receiver:
   **0/0/0/1/1/1/0**, no automatic registration and pairing preserved. Fresh
   personal receiver review through the recipient-only pilot restores baseline;
   restore ordinary and compare the new receipt/provider bytes exactly.
6. Both accounts signed in, Tecno's recorder/receiver bytes unchanged, Pixel zero
   recorder files, no driver authority/recording, both flags false and no worker,
   event, delivery, alert or upload. Save actual results and limitations; M6.8
   remains incomplete. Any ambiguous outcome ends the attempt; recover through
   ordinary signed-in owner checks, never manual row deletion or fixture forcing.

The scoped review must cover the real owner change, two personal email-link
flows, replacement account's explicit local Sign out and fresh original-owner
receiver consent. No enable window, synthetic fixture, network toggle, scheduler,
new Google key or token is needed. Do not execute from the completed sign-out,
Auth-loss, offline or interruption-recovery approvals.
