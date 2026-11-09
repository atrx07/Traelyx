# M6.8 recipient account-replacement check

## Scope and current gate

The separately approved live check passed on 2026-11-09: third-account SDK
replacement, local recipient cleanup, unpaired ordinary-app isolation, local
Sign out, original-owner reconciliation and fresh personal receiver consent.
Both original accounts and ordinary builds are restored. This scope is closed;
do not replay it from its completed approval. Mounted/vehicle tests remain deferred.
The preceding recovery is closed in [the recovery report](GUARDIAN_RESUME_20261108.md).

The maintainer confirmed a third email is available. The reviewed check used
Pixel's existing guardian account, then that unpaired third account on Pixel,
then returned to Pixel's original account. The email-link flow can create a normal
Supabase Auth account. No profile/vehicle/pairing edits or third-account receiver
registration were performed. This targets different-owner/unpaired-account isolation;
it does not establish natural Auth expiry or physical/OEM reliability.

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
Repository/format validation passes. Source `4fb65f6` passes all three jobs in
[CI 42495776651](https://github.com/atrx07/Traelyx/actions/runs/42495776651),
including Flutter/native suites, SQL/Edge checks, generated/schema verification
and debug/release-validation builds. Specific live review was subsequently
granted; no probe install or live switch ran during preparation. After the later
interruption, both devices remained authorized/online/idle, Tecno's 11,857
recorder hashes and both receipt/provider fingerprints were unchanged, driver
vaults absent and the configured probe APK matched its saved hash.

## Reviewed live sequence

1. Freshly verify both ordinary builds, signed-in accounts, registrations,
   validated connectivity and no recorder/driver vault. Capture new private
   manifests; require hosted sessions/events/deliveries/devices/unexpired/pairs/
   ready pairs **0/0/0/2/2/1/1**, both flags false and no local worker file.
2. Data-preserving update of Pixel only to the configured probe. Verify ready
   stage and unchanged receipt/provider. The maintainer requests one link for
   the third account and opens it inside Pixel. Before handing off the
   request, persist that it may have started; never replay it from a restart or
   ambiguous checkpoint. No Tecno Auth action.
3. Require completed replacement stage, absent local receipt/provider, retained
   encrypted journal and unchanged recorder files. Hosted counts must remain
   **0/0/0/2/2/1/1**: the old row must not be deleted using another owner. File
   presence alone does not prove journal contents; later exact reconciliation
   and deterministic contract tests provide separate evidence.
4. Restore ordinary Pixel without clearing data. Confirm the replacement account
   is signed in and unregistered locally. Explicit pairing/inbox reload must show
   no connections/alerts for the unpaired account, without old cached names or
   details. One explicit local Sign out must leave Tecno's separate device row
   intact and counts unchanged. The maintainer signs into Pixel's original
   account by a new email link inside Pixel.
5. Ordinary same-owner reconciliation must remove only Pixel's old receiver:
   **0/0/0/1/1/1/0**, no automatic registration and pairing preserved. Fresh
   personal receiver review through the recipient-only pilot restores baseline;
   restore ordinary and compare the new receipt/provider bytes exactly.
6. Both accounts signed in, Tecno's recorder/receiver bytes unchanged, Pixel zero
   recorder files, no driver authority/recording, both flags false and no worker,
   event, delivery, alert or upload. Save actual results and limitations; M6.8
   remains incomplete. Any ambiguous outcome ends the attempt; recover through
   ordinary signed-in owner checks, never manual row deletion or fixture forcing.

The scoped review covered the real owner change, two personal email-link
flows (including possible third-account Auth creation), replacement account's
explicit local Sign out and fresh original-owner
receiver consent. No enable window, synthetic fixture, network toggle, scheduler,
new Google backend key or administrative token is needed. Do not execute from the completed sign-out,
Auth-loss, offline or interruption-recovery approvals.

## Observed live result (2026-11-09)

- Fresh baseline **0/0/0/2/2/1/1**, both flag digests `false`, no recorder or
  driver vault. The probe update preserved the old receiver/provider bytes and
  reported ready. The maintainer opened the third account's link inside Pixel.
- The probe reported **Account changed; local recipient cleanup confirmed**.
  Receipt/provider were absent, recorder files unchanged and encrypted journal
  present/changed. Counts stayed **0/0/0/2/2/1/1**. A journal fingerprint alone
  does not prove its contents; subsequent original-owner reconciliation is
  separate evidence of the retained cleanup work.
- Restored ordinary `37906dc`: third account Signed in, explicit pairing reload
  showed **No Guardian connections**, profile setup affordance, and alert reload
  showed **No currently accessible alerts**. No old connection/alert rows appeared;
  Check this phone reported unregistered. No profile/pairing edits or receiver
  registration were performed for this account. One ordinary local Sign out preserved both original device
  rows and the journal: **0/0/0/2/2/1/1**. Its Auth account remains, locally signed
  out; it was not deleted.
- Personal original-account sign-in triggered ordinary reconciliation:
  **0/0/0/1/1/1/0**. Explicit local check stayed unregistered and pairing reload
  preserved the guardian role. Fresh personal receiver consent restored
  **0/0/0/2/2/1/1**. Ordinary `37906dc` was restored with the replacement
  receipt/provider bytes identical across the update; local registered check
  and Signed in Account passed.
- Tecno's **11,857 recorder files**, receipt and provider matched the fresh
  baseline; its original Account also showed Signed in. Pixel has zero recorder
  files. Both networks validated, no RecorderService or driver vault. Both
  hosted flags stayed `false`, retired worker digest unchanged and no local
  worker. No event, delivery, push, recording or trip upload. No runtime fix,
  dependency, schema, permission or backend key change.

The first ordinary Drive hierarchy dump timed out after update; a screenshot
showed a responsive screen. Navigating its observed You target restored reads.
A moved target after asynchronous reload was refused before input and resolved
by fresh state/scrolling. No Auth action was retried for these observation failures.

This closes the reviewed third-account replacement/recovery gate. Ordinary UI
isolation observations apply to the restored ordinary process; the native fake
remains modeled evidence. Natural Auth expiry, active driver replacement and
physical/OEM/vehicle reliability remain separate. Mounted, calibration,
ingestion/cancellation and performance gates remain deferred/open; M6.8 is
incomplete. Source `4fb65f6` CI remains the code baseline; closure is documentation only.
