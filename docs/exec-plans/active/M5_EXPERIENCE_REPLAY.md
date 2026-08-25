# Execution Plan — M5 Experience & Replay

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M5 — Experience & Replay
**Started:** 2026-08-25
**Last updated:** 2026-08-25

## Context budget / references

Read only:

- `AGENTS.md` and `app/AGENTS.md`
- `docs/product/UX_SPEC.md` sections 1–6 and 17–18
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization/approval sections of `DOCUMENTATION_POLICY.md`
- `docs/exec-plans/ROADMAP.md` M5 and `docs/exec-plans/milestones/M5_EXPERIENCE_REPLAY.md`
- affected Flutter Drive/navigation/theme code and tests

Do not inspect M5.2 or later implementation until its approval gate. Map, commentary, ML, cloud, and unrelated technical specifications remain outside M5.1.

## Goal

Turn the existing recorder controls into a calm, glanceable ready screen and a distraction-minimized live recording mode without changing native recorder semantics.

## User-visible result

Drive opens with truthful recording readiness and its primary action visible before secondary tools. While recording, Traelyx presents an unmistakable dedicated live state, compact GPS/motion/local-save health, no primary navigation, and a protected end-and-save confirmation.

## In scope

- M5.1 Ready/Drive screen only.
- Ready, permission-recovery, loading, failure, recording, degraded-recording, stopping, finalization, and private-export presentation states.
- Presentation-level recorder-health reduction over existing versioned bridge evidence.
- Navigation suppression while a Drive recording is active.
- Widget, navigation, accessibility, text-scale, and physical Tecno QA.

## Out of scope

- M5.2 trip history/results and every later M5 substep.
- New speed, distance, elapsed-time, map, replay, scoring, or explanation data.
- Native recorder, bridge, telemetry, database schema, permissions, export format, account, or network behavior changes.
- New dependencies or provider choices.

## Preconditions

- M0–M4 are complete and archived.
- Maintainer authorized M5 and M5.1 on 2026-08-25.
- Local `main` was clean and synchronized with refreshed `origin/main` at `9ec5573242cba007e97a6a6773910bc12a2e3eef`.
- A Tecno LH8n is connected through ADB for physical validation.

## Affected components

- `lib/features/bootstrap/application/drive_control_model.dart`
- `lib/features/bootstrap/presentation/bootstrap_screen.dart`
- `lib/features/navigation/presentation/app_navigation_shell.dart`
- related Flutter widget/application/navigation tests
- roadmap/status documentation

## Data/privacy/security implications

No new data collection, storage, permission, identifier, secret, route display, or network flow. Existing `.tripdebug` export remains an explicit precise-private action and is visually demoted, not weakened.

## Compatibility/migration implications

None. Existing bridge/schema/algorithm versions and historical results remain unchanged.

## Implementation steps

- [x] 1. Add a pure, deterministic presentation model for truthful ready/live health states over existing permission and aggregate recorder evidence.
- [x] 2. Recompose Drive so readiness and the primary action precede secondary local tools and remain usable at supported text scales.
- [x] 3. Add a dedicated live mode with unmistakable recording/degraded states, compact health, suppressed navigation, and protected end-and-save confirmation.
- [x] 4. Cover ready, loading, failure, live, degraded, stopping, confirmation, navigation, semantics, reduced-motion, and text-scale behavior.
- [x] 5. Run host gates, debug/release builds, Tecno installation and physical QA, privacy review, documentation synchronization, commit, push, and remote verification.

## Tests / validation

- [x] Dart formatting check and static analysis
- [x] focused application/widget/navigation tests
- [x] complete Flutter test suite
- [x] complete native Kotlin unit-test suite and governed telemetry/intelligence regressions
- [x] repository validation and secret/privacy review
- [x] debug APK build and size comparison
- [x] release APK build without private signing material
- [x] Tecno ready/loading/permission/live/degraded/stopping/finalization presentation and recorder smoke validation
- [x] Tecno text/layout, touch-target, back/background/resume, notification, and navigation-suppression checks
- [x] scoped device cleanup with no QA trip/export left behind

## Acceptance criteria

- The current truthful readiness/action state and its primary control appear before optional export or diagnostic detail on a phone viewport.
- Loading or failed prerequisite evidence disables Start; no permission prompt occurs without an explicit tap.
- Labels describe exact available evidence and never fabricate sensor calibration, confidence percentages, distance, duration, or speed.
- Active recording is impossible to confuse with the ready state, keeps GPS/motion/local-save limitations visible, and removes navigation distractions.
- Ending a drive requires an explicit confirmation and communicates that verified local evidence will be saved.
- Persistent unreliable motion accuracy is shown as limited, while one transient unreliable sample is not promoted to a permanent warning.
- Critical controls remain reachable with large touch targets, screen-reader semantics, and supported text scaling; user-visible transitions respect disabled animations.
- Existing native recording, finalization, precise-private export, accountless/local-only, and fail-closed contracts remain intact.

## Risks

- The bridge does not currently expose authoritative live speed, distance, or elapsed duration, so M5.1 must not synthesize them.
- A live screen can hide useful failure detail if health reduction is too aggressive; typed aggregate warning states and tests must keep limitations visible.
- Navigation suppression must follow the shared recorder provider without creating a second recorder state source.
- Physical QA on one Android 14 OEM does not establish multi-device layout or lifecycle reliability.

## Decisions made during execution

- Use only existing versioned aggregate bridge evidence; do not expand the native bridge for decorative metrics.
- Keep `.tripdebug` export available after finalization but below the primary recording flow because it is a privacy-sensitive developer/user tool, not the ready-state objective.
- Protect End Drive with a confirmation step rather than a gesture that could be inaccessible or hard to discover.
- Treat idle motion health as `On Start`, because the native idle aggregate does not prove current sensor availability; surface persistent unreliable accuracy as `Limited` only after recording supplies evidence.
- Expose the merged primary-action semantics node with its own tap action so screen readers retain operability while duplicated visual child semantics remain excluded.

## Progress log

- 2026-08-25: M5 and M5.1 authorized. Plan activated after confirming clean synchronized `main`, loading the scoped UI/testing contracts, inspecting existing implementation/tests, and capturing the current Tecno ready screen.
- 2026-08-25: Implemented the pure ready/live presentation reducer, recomposed the ready and live Drive views, suppressed primary navigation while recording, and added application/widget/navigation regressions for all governed states.
- 2026-08-25: Formatting and analysis passed; 101 Flutter tests and 211 native Kotlin tests passed with zero failures; repository validation found no known secret pattern or sensitive filename. Final debug and release APKs measured 166.17 MiB and 53.16 MiB.
- 2026-08-25: The Tecno debug cycle verified ready, live/degraded, confirmation/cancel, background, relaunch, notification, stopping, finalization, and scoped cleanup. ADB exposed the final Start node as enabled/clickable above fold in both debug and release. The exact pre-QA database hash and all four original trip roots were preserved, the exact QA trip and 106 generated chunks were removed, temporary device artifacts were deleted, and no recorder service remained.

## Completion summary

M5.1 is complete. Drive is now a truthful, accessible ready/live recorder experience without changing recorder, permission, bridge, schema, scoring, export, or privacy behavior. The active M5 plan remains here for continuity; work is stopped at the explicit M5.2 approval gate.
