# Execution Plan — M8.1 Android torture matrix

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M8.1
**Started:** 2026-11-17
**Last updated:** 2026-11-18

## Context budget / references

- Root, Android, app and test AGENTS; documentation/testing/definition-of-done policy.
- `ANDROID_TRACKING.md`; existing recorder service, acquisition, chunk and finalization tests.
- `M7_HANDOFF_V1.md`, Android emulator workflow and relevant tooling failures only.

## Goal / user-visible result

Execute a reproducible Android recorder failure/recovery matrix, repair confirmed
defects and retain privacy-safe evidence with explicit platform/physical limits.

## In scope

- A separately identified, accountless debug QA build using the production recorder.
- Background, screen-off, activity recreation, provider/network loss, process
  interruption, durable recovery/finalization and device-condition coverage.
- Existing Pixel AVD and desk-safe Tecno checks; exact owned-fixture cleanup.

## Out of scope

M8.2 and later substeps, live Guardian/account changes, public distribution,
model activation, staged driving, physical mounted/vehicle/OEM acceptance.
M7.4/M7.5 and M6.8 acceptance remain carried forward.

## Preconditions / affected components

User authorized M8.1. Main tree was clean at `9e2aeff`, matching origin/main.
Discover and verify device/AVD identity before mutation. Never clear/uninstall the
main package. Android test-only code/build selection and an operator tool are
the initial affected components; expand production code only for demonstrated bugs.

## Data/privacy/security and compatibility

No accounts, hosted requests, keys, new dependencies, scoring or schema changes
are planned. QA raw samples stay app-private and are deleted only by exact
test-owned identity. Public reports contain aggregate outcomes, no raw logs,
routes, timestamps of samples, device serials, account identifiers or secrets.
Normal debug/release identities and default build behavior must remain unchanged.
No sampling, batching or wake policy change without measured justification.

## Implementation steps

- [x] Inspect current recorder contracts/tests and authorized device inventory.
- [x] Add guarded QA build and bounded, repeatable instrumentation/operator path.
- [x] Run matrix on Pixel and desk-safe physical cases on Tecno; fix regressions.
- [x] Validate normal build, unit/regression suites, lint and repository contracts.
- [x] Record matrix, unresolved limits and synchronize project status.
- [ ] Inspect exact diff, commit/push atomically, check source CI and remote HEAD.

## Tests / acceptance criteria

- Positive recorder progress requires newly persisted, verified chunks and samples,
  stable identity and visible foreground notice, rather than active state alone.
- Interrupted-process recovery preserves the previously committed chunk prefix,
  marks recovery explicitly and never creates a duplicate trip.
- GNSS loss is observable, IMU acquisition continues and provider recovery is
  demonstrated where controllable; offline recording does not require cloud access.
- Stop retains verified finalization before explicit fixture-only cleanup.
- Each result labels platform, method, duration and limitations; unsupported or
  unexecuted physical conditions are never reported as passes.
- Main app/accounts/recordings remain preserved; changed device settings restored.
- Native tests, relevant Flutter integration tests, app lint, both debug identities,
  instrumentation compilation and repository contracts pass; source CI is observed.

## Risks / decisions

USB and emulator screen-off do not prove deep suspend, OEM long-duration behavior,
battery efficiency or road GNSS quality. Do not lift carried-forward gates from
short stationary checks. No release/tag/assets or external APK distribution.

## Progress log

- 2026-11-17: Pixel and Tecno authorized and connected. Existing lifecycle runner
  inspects short background/screen intervals but requires a real GNSS fix and has
  broad cleanup; new checks will be isolated from the ordinary package.
- 2026-11-17: Both final stationary matrices and actual QA-process interruption/
  recovery pass. Seven pinned committed chunks survive each interruption; new
  persisted motion/chunks and recovered flags pass. Fixture cleanup and main
  recorder/Guardian/preferences fingerprints match on every successful phase.
  Pixel also passes controlled provider loss/fix return, offline recording and
  battery-saver progress; physical radio/location/power settings were preserved.
- Runner development corrected reused-Activity waiting, an active AtomicFile scan
  race and confusion between persisted active state and a live writer. These were
  test-runner repairs; no production recorder defect/change is claimed. Failed
  attempts were retained locally and exact-owned cleanup passed before retries.
- 2026-11-18: Resumed after usage interruption. Saved final device reports and
  cleanup results verified; no devices connected and no new device operation.
  Formatting (225 files), Flutter analysis/592 tests, seven operator regressions,
  ordinary debug build/package isolation, 528 app-native tests plus 68 dependency
  tests, scoped app lint and repository contracts pass. Source CI remains pending.
  Ignored local.properties was restored byte-for-byte after scoped lint escaping.

## Completion summary

Local implementation/validation passes. See
[`ANDROID_TORTURE_MATRIX_V1.md`](../../reference/ANDROID_TORTURE_MATRIX_V1.md) and
[`m8-android-v1-result.json`](../../reference/m8-android-v1-result.json).
M8.1 remains active until source CI and persistence gates pass. No new dependency,
provider, production recorder behavior, sampling/wake policy, schema or scoring
change. Short USB-connected checks do not establish secure keyguard/deep suspend,
real GNSS obstruction, reboot, OS/OEM kills, thermal/storage/battery or vehicle
reliability. M6.8/M7 acceptance and the distribution hold are unchanged.
