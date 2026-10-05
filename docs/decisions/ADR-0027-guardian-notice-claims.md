# ADR-0027 — Persist Guardian notice claims before display

- Date: 2026-10-05
- Status: Accepted; native and isolated physical checks passed, live FCM pending

## Decision

FCM retries and lost provider responses can repeat an authorized delivery ID.
A stable Android notification tag suppresses repeated sound while the notice is
present, but cannot prevent it reappearing after dismissal. Retain up to 1,024
delivery IDs inside the existing encrypted, no-backup recipient authority record.
Bind this history to the same device/generation and registration lifetime.
Serialize claims across Android vault instances. Require current generation,
credential and local lifetime at claim time, after a positive server receipt.
Persist and verify the claim before attempting generic notification display;
recheck local authority after the claim. No ID is evicted while the registration
is valid. Capacity denies additional notices; withdrawal and fresh registration
are required to reset the history. Never clear history because a notice was
dismissed, the process restarted, a receipt response was lost or the clock changed.

Use recipient plaintext format v2 with compact 16-byte UUIDs and a 20 KiB
bound; a full record occupies less than 17 KiB. Read v1 as an empty claim history
and upgrade on the first write, keeping the existing Keystore key/encryption
domain. The outer authenticated-encryption format remains unchanged. Existing
authority erase on withdrawal, expiry or account change also erases this history.
No new file, key, dependency, network field or Auth credential is introduced.

An uncertain claim write denies display and disables that vault instance, but
preserves the atomic old/new ciphertext and key for restart and revocation.
Unlike an initial registration write, it must not destroy an existing receipt
and the IDs needed to revoke its server row. A restart may retry only if the
atomic record lacks the claim; no notice was attempted on that failing path.

## Limits

This is at most one display attempt per claimed ID in one registration, not
exactly-once delivery. Process death or notification failure after durable claim
can suppress that notice permanently. Device receipt still means receipt, not
display or human attention; the authenticated inbox remains available. A missing
server response does not create a claim, so a later push can retry. There is no
new retry worker, Firebase initialization, wake lock or recorder I/O.

Pre-v2 displays cannot be reconstructed during upgrade. Downgrading to a build
that reads only v1 refuses v2 authority. Live FCM, process-death timing and OEM
notification behavior remain physical validation gates. The final local check
and Android notification call cannot be atomic with remote permission revocation;
generic text and guarded detail access continue to limit that race.

## Validation

Test v1 upgrade/key preservation, encrypted restart, concurrent duplicates,
capacity without eviction, expiry/generation/credential denial, uncertain writes
before and after replacement, and withdrawal. Receiver tests cover dismissal,
recreation, lost receipt response, replacement/expiry during the server reply and
withdrawal during claim. Extend the isolated physical recipient-vault proof to
claim and reject a duplicate through separate Android vault instances. Keep both
production Guardian functions disabled during these checks.
