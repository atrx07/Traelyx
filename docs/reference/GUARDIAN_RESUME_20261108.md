# M6.8 interruption recovery — 2026-11-08

## Scope

Read when resuming after the laptop interruption reported on this date. This
records recovery of the existing two-account desk setup, not a new alert test
or a driving/accuracy claim. The previous offline-check scope was already closed
and pushed in `484542c`; no interrupted send, worker or live test was resumed.

## Observations and recovery

- Repository clean at `484542c`; Pixel_10 was stopped. Restarted the same AVD
  with existing data, without a wipe. Both devices became ADB-authorized and
  reported validated connectivity; neither had an active recorder or driver vault.
- The authorized wake/swipe unlocked Tecno. Traelyx opened normally but Account
  was signed out. All **11,857 recorder files** matched the preceding baseline.
  Local receipt/provider state had changed; later inspection confirmed absence.
  The reason for Auth loss is **not established**. Do not attribute it to the
  laptop failure, receiver expiry or a specific Auth error without evidence.
- Pixel remained signed in. Its zero recorder files and receipt/provider bytes
  matched the final ordinary-build baseline from the completed offline check.
- Both hosted enable digests still matched `false`; retired worker digest was
  unchanged. Aggregate sessions/events/deliveries/devices/unexpired/pairs/ready
  pairs were **0/0/0/2/1/1/1**: one receiver row was expired. This is receiver
  expiry evidence, not proof of how or why Tecno lost Auth.
- The maintainer personally signed into the same Tecno account by email link.
  Ordinary reconciliation removed the old receiver row: **0/0/0/1/1/1/1**.
  Pairing stayed intact and explicit Check this phone reported unregistered.
- Update-installed the previously reviewed recipient-only pilot on Tecno without
  clearing data. The maintainer personally completed fresh receiver consent.
  Its local registration and hosted **0/0/0/2/2/1/1** passed. No new registration
  was requested on Pixel.
- Restored ordinary pilot-off `37906dc` on Tecno. Its new receipt/provider bytes
  were identical across the update; explicit ordinary Check this phone reported
  registered. All 11,857 recorder hashes stayed unchanged. Pixel's existing
  receipt/provider and recorder state stayed identical. Both accounts were
  signed in, both driver vaults absent and both backend sending flags stayed off.

## Validation and limits

Fresh private manifests and fixed-label ADB observations were used; private
identifiers, tokens, emails, routes and raw device logs are not included here.
Read-only dashboard queries verified the aggregate transitions above. No app
source, dependency, schema, credential, sampling, permission, pairing or profile
change; no alert, recording or trip upload. This recovery needed no code fix.

This does not reproduce natural Auth expiry or establish its cause. It does not
close different-account replacement, mounted driving, calibration, active
cancellation/ingestion or general physical/OEM reliability gates. M6.8 remains
incomplete; vehicle checks remain deferred by the maintainer. Prepare the next
bounded account-replacement procedure and validate it before requesting its
separate live production review. Do not reuse prior test approvals.
