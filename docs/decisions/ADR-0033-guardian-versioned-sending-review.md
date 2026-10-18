# ADR-0033: Separate fresh Guardian sending review from local evaluation consent

- Date: 2026-10-18
- Status: local, isolated physical and full source CI checks pass; live validation pending

## Decision

Existing driver reviews say sending is unavailable. Keep those reviews as
evaluation-only version 0; enabling a build flag cannot upgrade them. A separate
`TRAELYX_GUARDIAN_SENDING_PILOT` defaults false and additionally requires the
existing debug driver pilot. The sending variant discloses Supabase/Firebase,
permitted event metadata, connected-recipient name sharing, the full observed
cancellation window, irreversible handoff and unreliable delivery. Its extra
acknowledgement starts unchecked and creates version 1 only after confirmation.
Review age/owner/mount/safety/recipient checks remain mandatory. Unknown versions
and inconsistent acknowledgement/version pairs fail before activation side effects.

Use a distinct strict native `beginSending` request containing the ordinary
proposal fields plus `sendingAcknowledged=true` and `sendingReviewVersion=1`.
The native bridge rejects it unless the installed package is debuggable. The
old `begin` contract remains unchanged and rejects added sending fields. The
Flutter service and controller also require the sending pilot before proceeding.
An older native implementation fails the new request rather than falling back
to evaluation consent or sending without review.

Bind the acknowledgement only to the exact in-memory proposal and successful
local commit. The sender requires a current bound lease and that same fresh
activation's sending identity. Capture a non-null identity before recovery so
expiry clearing both values cannot produce a successful null/null comparison.
Stop, account loss, replacement, failed activation, expiry, reboot and missing
authority deny sending. No sending flag enters the encrypted persisted schema;
process reopening requires a new review under ADR-0029. Same-owner recovery of
a still-live in-process activation preserves its reviewed permission. Stale
cleanup for an older activation cannot revoke a newer review.

The existing per-review cancellation token, exact cleanup journal and server
revision fence remain in force through foreground acceptance of commit success.
Cancellation-offer proof and the bounded scheduler/IO remain governed by
ADR-0031 and ADR-0032. Backend acceptance still does not prove delivery or help.

## Consequences and validation boundaries

- Ordinary installed builds keep both pilots false and perform no new activation
  or send. Release UI hides the pilot and the native package guard denies it.
- No migration, dependency, permission, sampling change or new network field.
- Tests inject review availability and fake ports; an isolated physical proof
  uses a random encrypted namespace and no server session or transport.
- Reviewed hosted activation/Stop, actual on-device consent, accepted cancellation
  under a live lease, active recording and physical/two-account reliability remain
  required before M6.8 completion. Source authorization does not enable production.

Source `9835ad4` passes full CI
[39147698943](https://github.com/atrx07/Traelyx/actions/runs/39147698943), including
484 native app/390 Flutter tests, debug/release APKs, server policies and artifacts.
The scoped physical proof preserves real recorder/receiver data and sign-in.
