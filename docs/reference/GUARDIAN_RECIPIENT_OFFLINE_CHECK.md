# M6.8 registered receiver offline sign-out check

## Scope and current gate

Preparation only (2026-10-21); **no live offline action or retry is approved or
run**. The completed [controlled Auth-loss check](GUARDIAN_RECIPIENT_AUTH_LOSS_CHECK.md)
has a closed approval. This check uses the ordinary app's explicit Sign out and
must not reuse the raw SDK fault-injection entrypoint.

Expected contract: when server cleanup cannot be confirmed, explicit Sign out
reports cancellation and keeps Auth plus local recipient/provider state for an
explicit retry. After connectivity returns, one reviewed online retry revokes
the exact receiver before local cleanup and Auth release. Sign-in preserves the
pairing without automatic registration; fresh personal consent is required to
register again. Do not claim that a whole-sign-out failure identifies which
cleanup RPC failed; native driver Stop precedes recipient server revocation.

## Prepared operator and local checks

`tool/guardian_recipient_offline_check.mjs` is a standalone Node operator, not an
app dependency, scheduler or backend caller. No new dependency/provider, build,
schema, permission or runtime application change.

- `inspect <adb-path>` only reads the fixed `emulator-5554` target and requires
  the emulator property, stable original network switches, airplane mode off,
  a validated network/default route, signed-in Account UI with a unique enabled
  Sign out button, a recipient receipt/provider marker and no driver vault or
  recorder service. It prints booleans only; fingerprints stay in memory.
- `run <adb-path> --reviewed` is for a separately approved live window. It saves
  original Wi-Fi/mobile switches in an ignored checkpoint, disables both, waits
  up to 15 seconds for both switches off and no default network, then rechecks
  Account/recording/network before at most one Sign out tap.
- Wait up to 35 seconds for the exact cleanup-cancelled message, retained
  Signed in and enabled retry action. Unexpected sign-out, timeout, reconnection,
  changed receipt/provider bytes or unavailable UI is failure/uncertainty, never
  an automatic retry. ADB commands have a 60-second offline-phase budget.
- `finally` attempts both original switches, including when the first restore
  command fails; it does not turn on a switch that was originally off. Require
  matching switches and a validated/default network before success, with a
  separate 35-second command budget and 25-second restoration poll. Recheck Auth
  and exact receipt/provider fingerprints after restoration. A host/process
  kill or power loss can prevent finally from running: inspect the checkpoint
  and guest state on resume before any later test. Never assume restoration.
- No online retry, consent, registration, Firebase token acquisition, worker,
  enable-flag change, alert or trip upload is wired in this operator. Account
  screen navigation and hosted aggregate checks remain explicit operator steps.

Thirteen simulated operator tests pass, including unknown/ambiguous observations,
partial disable, spontaneous reconnect, timeout/unexpected sign-out, receipt loss,
restoration failure, original-off switches and command-budget expiry. All 45
existing account-binding/device-registration regressions pass. Pixel read-only
inspect passes with Wi-Fi/mobile on; both ADB devices are authorized/online/idle.
Repository validation and syntax checks pass. Exact-source CI must pass before
requesting the concrete production review. No network switch or Auth mutation
has occurred during preparation.

## Proposed production scope after CI

Ask approval for one offline Sign out attempt on the registered Pixel, automatic
restoration of its saved network switches, one explicit online Sign out retry
after verified failure/recovery, and same-account email-link sign-in completed by
the maintainer. Fresh receiver consent creates a replacement Firebase routing
token and private Supabase registration. Restore the ordinary pilot-off app
after using the already reviewed recipient-only pilot for that consent.

Both functions remain false throughout; no alert, driving, recording, permission,
pairing, profile, schema or backend-key change. Tecno stays online, signed in and
untouched apart from read-only preservation checks. Do not replay the operator
after any failed/uncertain result; inspect safely under the approved recovery
scope. No new third account or physical driving is part of this proposal.

## Bounded live sequence after separate approval

1. Fresh manifests and local registered checks for both devices; no recorder or
   driver vault. Both dashboard flags false, no local worker, known Pixel guardian
   pairing and ordinary build. Hosted sessions/events/deliveries/devices/unexpired/
   pairs/ready pairs must be **0/0/0/2/2/1/1**. Open Pixel Account and inspect.
2. Run the one-shot operator once. Require `passed`, `signout_attempted` and
   `network_restored` all true; inspect the fixed UI cancellation, retained Auth,
   original switch values and unchanged recorder/receiver/provider fingerprints.
   Confirm host-side counts remain **0/0/0/2/2/1/1** after connectivity settles.
   A late or unexpected server change is a partial result, not proof of retention.
3. Only after confirmed recovery, perform the approved online Sign out once.
   Require signed-out UI and receiver/provider absence; hosted baseline becomes
   **0/0/0/1/1/1/0**. Preserve pairing and all trip evidence. No automated retry
   loop or direct SQL deletion to force expected counts.
4. Maintainer signs into the same Pixel account via an email link inside Pixel.
   Verify no automatic registration and preserved pairing, then obtain fresh
   personal recipient review. Verify replacement registration and original
   hosted baseline, restore ordinary build preserving the new receipt/provider
   bytes, and check both accounts signed in plus Tecno preservation.
5. Verify actual network restoration, both flags false and no queued alert or
   worker. Document limits: emulator failure/retry evidence is not natural-expiry,
   third-account, mounted-driving or physical/OEM reliability evidence. M6.8
   remains incomplete until its other required gates pass.
