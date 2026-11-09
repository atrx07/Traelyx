# Guardian passive hosted refresh observation

## Scope and status

Source preparation and full CI pass for M6.8. The alternate debug entrypoint is
`tool/guardian_passive_refresh_probe.dart`; ordinary app code does not import it.
Twenty-one generated-state/UI checks, all 453 Flutter tests, analysis, repository
validation and the configured alternate debug build pass. Source `1e936e8`
passes full [CI 42606731458](https://github.com/atrx07/Traelyx/actions/runs/42606731458),
including native suites and debug/release builds. Fresh device/hosted-state
checks remain required before installing it on Pixel. The ignored prepared APK is
`.dart_tool/m6_8_passive_refresh_probe.apk`, SHA-256
`fa6a2f7194f050e18f491f9ee309004b59d928a6521beedbf087457ef5c44334`.

This observes successful normal **access-token rollover**. It does not force a
refresh, sign out, inject a session, change clocks/network/SDK settings, register
a receiver, activate a driver or enable either Guardian function. Supabase's
normal SDK auto-refresh/storage remains unchanged. Existing production owner
binding, exact cleanup and reconciliation remain in place; the observer adds
only metadata/native status reads. Unexpected Auth loss still invokes normal
cleanup; it must be reported as a failed observation and reviewed separately.

Successful rollover does not establish terminal natural Auth-session expiry,
revocation, active-driver teardown or physical/OEM/vehicle reliability. Those
remain separate acceptance gates. Do not use this check to waive mounted review.

## Admission and evidence

- Require a debug build, the explicit passive-probe define, the intended Traelyx
  project and all three Guardian pilots false, before initializing Auth.
- Require the original signed-in Pixel receiver, empty recipient/driver cleanup
  journals and disabled driver status. Both backend enable flags stay false.
- Begin once. Record only owner, reported expiry and receipt identity in memory;
  show only fixed result labels. Never export tokens, emails, IDs or Auth storage.
- A pass requires an observed SDK `tokenRefreshed` event with later reported
  expiry, passage of the original reported expiry boundary, current unexpired
  metadata for the same owner and unchanged native receipt/empty journals.
- Metadata advancement alone, stale events, stream closure or elapsed wall time alone cannot
  pass. Sign-in/sign-out/recovery events close the observation even if the owner
  returns to the same account. Owner/receipt/driver changes also deny a pass.
- Bound observation to 80 minutes using both a timer and wall deadline; rollback
  denies a pass. Backgrounding, cancellation, native errors/timeouts or process
  termination never record a pass. No results persist across process death.
- Independent private before/after file fingerprints must also prove the
  encrypted receiver/provider and recorder files unchanged. A UI result alone
  does not prove provider-storage preservation or hosted database counts.

## Operator sequence after source validation

1. Recheck both devices, ordinary sign-ins, no recorders/driver vaults, hosted
   aggregate baseline and disabled flags. Save fresh private preservation hashes
   and the current ordinary configured APK for restoration. Do not clear data.
2. Update-install the observer on Pixel only, with saved Auth/receiver state.
   Use `TRAELYX_GUARDIAN_PASSIVE_REFRESH_PROBE=true`, the ignored normal Auth
   config, and all recipient/driver/sending pilot defines explicitly false.
3. Begin passive observation once and keep Pixel foreground. Check the fixed UI
   result periodically; Check observation reads metadata/native state only.
   Allow up to 80 minutes. Do not accelerate expiry, request a link, press any
   explicit refresh/sign-out control or change system/network settings.
4. On success, cancellation, failure or deadline, restore the ordinary APK using
   a data-preserving update. Verify original sign-in/registration, exact file
   fingerprints, no driver/recorder and unchanged hosted aggregate baseline.
5. If Auth/receiver state changes unexpectedly, do not re-register or sign in
   automatically. Preserve available evidence and obtain the specific recovery
   input/approval. Do not re-run a failed observation silently.

## Validation record

The generated-state tests cover admission guards, genuine refresh plus boundary,
false positives, diagnostics, same/different-owner session replacement,
receipt/journal/driver changes, delayed native responses, cancellation, deadline,
clock rollback, lifecycle cancellation and fixed-text privacy. Native storage is
modeled here; the future hosted run must supply independent preservation proof.
No hosted observation or device installation has run during preparation.
