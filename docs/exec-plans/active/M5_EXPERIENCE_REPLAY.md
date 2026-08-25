# Execution Plan — M5 Experience & Replay

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M5 — Experience & Replay
**Started:** 2026-08-25
**Last updated:** 2026-08-25

## Context budget / references

Read only:

- `AGENTS.md` and `app/AGENTS.md`
- `docs/product/UX_SPEC.md` sections 1–7 and 17–18
- `docs/product/MVP_SCOPE.md` Experience scope and the relevant local-history sections of `docs/technical/DATA_MODEL.md` and `STORAGE_SPEC.md`
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization/approval sections of `DOCUMENTATION_POLICY.md`
- `docs/exec-plans/ROADMAP.md` M5 and `docs/exec-plans/milestones/M5_EXPERIENCE_REPLAY.md`
- affected Flutter Drive/Trips/navigation/database-access code and tests

Do not inspect M5.3 or later implementation until its approval gate. Map, commentary, ML, cloud, and unrelated technical specifications remain outside M5.2.

## Goal

Turn the existing recorder controls and local trip index into a calm, glanceable ready/live experience plus truthful accountless trip history and result hierarchy without changing native recorder or analysis semantics.

## User-visible result

Drive opens with truthful recording readiness and its primary action visible before secondary tools. While recording, Traelyx presents an unmistakable dedicated live state, compact GPS/motion/local-save health, no primary navigation, and a protected end-and-save confirmation. Trips lists locally indexed drives newest first and opens an evidence-backed result that distinguishes recorded facts from analysis that has not been persisted yet.

## In scope

- Completed M5.1 Ready/Drive screen.
- M5.2 Trip history/result only.
- Ready, permission-recovery, loading, failure, recording, degraded-recording, stopping, finalization, and private-export presentation states.
- Presentation-level recorder-health reduction over existing versioned bridge evidence.
- Navigation suppression while a Drive recording is active.
- Widget, navigation, accessibility, text-scale, and physical Tecno QA.
- Read-only local trip, vehicle, chunk, event, and score summaries from schema version 1.
- Empty/loading/error/not-found and missing-distance/score/confidence/event states.

## Out of scope

- M5.3 Drive DNA visual and every later M5 substep.
- New speed, distance, elapsed-time, map, replay, scoring, or explanation data.
- New score/event persistence or production execution of the M4 analysis engine.
- Native recorder, bridge, telemetry, database schema, permissions, export format, account, share transport, or network behavior changes.
- New dependencies or provider choices.

## Preconditions

- M0–M4 are complete and archived.
- Maintainer authorized M5 and M5.1 on 2026-08-25.
- Maintainer authorized M5.2 on 2026-08-25 after M5.1 completed at `8cf95902803fc227e5a26749a178c583c70c69ab`.
- Local `main` was clean and synchronized with refreshed `origin/main` at `9ec5573242cba007e97a6a6773910bc12a2e3eef`.
- A Tecno LH8n is connected through ADB for physical validation.

## Affected components

- `lib/features/bootstrap/application/drive_control_model.dart`
- `lib/features/bootstrap/presentation/bootstrap_screen.dart`
- `lib/features/navigation/presentation/app_navigation_shell.dart`
- new `lib/features/trips/` domain, read-only data, application-provider, and presentation boundaries
- `lib/app/traelyx_router.dart` and `lib/app/traelyx_routes.dart`
- related Flutter widget/application/navigation tests
- roadmap/status documentation

## Data/privacy/security implications

No new data collection, storage, permission, identifier, secret, raw route display, share transport, or network flow. History reads existing local summary/index tables only; raw chunk paths, checksums, coordinates, and exact telemetry never enter presentation state. Existing `.tripdebug` export remains an explicit precise-private action and is visually demoted, not weakened.

## Compatibility/migration implications

None. Existing bridge/schema/algorithm versions and historical results remain unchanged.

## Implementation steps

- [x] 1. Add a pure, deterministic presentation model for truthful ready/live health states over existing permission and aggregate recorder evidence.
- [x] 2. Recompose Drive so readiness and the primary action precede secondary local tools and remain usable at supported text scales.
- [x] 3. Add a dedicated live mode with unmistakable recording/degraded states, compact health, suppressed navigation, and protected end-and-save confirmation.
- [x] 4. Cover ready, loading, failure, live, degraded, stopping, confirmation, navigation, semantics, reduced-motion, and text-scale behavior.
- [x] 5. Run host gates, debug/release builds, Tecno installation and physical QA, privacy review, documentation synchronization, commit, push, and remote verification.
- [x] 6. Add immutable trip-history/result models and a read-only repository over existing schema-v1 summary/index tables.
- [x] 7. Replace the Trips placeholder with newest-first local history and explicit empty/loading/error states.
- [x] 8. Add deep-link-safe trip results with identity, recorded metrics, integrity/confidence, local evidence, and honest unavailable-analysis states.
- [x] 9. Cover ordering, aggregation, malformed evidence, navigation, missing evidence, accessibility, and text-scale behavior.
- [x] 10. Run all M5.2 host/device gates, synchronize status, commit/push atomically, verify remote main and CI, then stop at M5.3.

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
- [x] focused M5.2 repository/model/widget/navigation tests
- [x] M5.2 empty/loading/error/not-found and malformed-evidence checks
- [x] M5.2 Tecno local-history/detail, back/deep-link, text/layout, and no-network smoke checks
- [x] M5.2 debug/release APK installation with pre-existing data preserved

## Acceptance criteria

- The current truthful readiness/action state and its primary control appear before optional export or diagnostic detail on a phone viewport.
- Loading or failed prerequisite evidence disables Start; no permission prompt occurs without an explicit tap.
- Labels describe exact available evidence and never fabricate sensor calibration, confidence percentages, distance, duration, or speed.
- Active recording is impossible to confuse with the ready state, keeps GPS/motion/local-save limitations visible, and removes navigation distractions.
- Ending a drive requires an explicit confirmation and communicates that verified local evidence will be saved.
- Persistent unreliable motion accuracy is shown as limited, while one transient unreliable sample is not promoted to a permanent warning.
- Critical controls remain reachable with large touch targets, screen-reader semantics, and supported text scaling; user-visible transitions respect disabled animations.
- Existing native recording, finalization, precise-private export, accountless/local-only, and fail-closed contracts remain intact.
- Trips are ordered newest first and remain usable without an account or network.
- Result hierarchy shows only persisted duration, distance, completion/recovery, integrity, score/event, and aggregate chunk evidence; absent or malformed evidence never becomes a positive claim.
- Raw routes, coordinates, chunk paths, checksums, and device identifiers never enter the UI model or semantics tree.
- Direct `/trips/:tripId` navigation is safe, missing records fail clearly, and large text keeps back/navigation and result content reachable.

## Risks

- The bridge does not currently expose authoritative live speed, distance, or elapsed duration, so M5.1 must not synthesize them.
- A live screen can hide useful failure detail if health reduction is too aggressive; typed aggregate warning states and tests must keep limitations visible.
- Navigation suppression must follow the shared recorder provider without creating a second recorder state source.
- Physical QA on one Android 14 OEM does not establish multi-device layout or lifecycle reliability.
- Production finalization currently leaves distance, confidence, events, and scores unavailable; M5.2 must present those absences as product truth rather than synthesizing analysis.
- Schema-v1 text states and aggregate JSON must be reduced through explicit allowlisted parsing before presentation.

## Decisions made during execution

- Use only existing versioned aggregate bridge evidence; do not expand the native bridge for decorative metrics.
- Keep `.tripdebug` export available after finalization but below the primary recording flow because it is a privacy-sensitive developer/user tool, not the ready-state objective.
- Protect End Drive with a confirmation step rather than a gesture that could be inaccessible or hard to discover.
- Treat idle motion health as `On Start`, because the native idle aggregate does not prove current sensor availability; surface persistent unreliable accuracy as `Limited` only after recording supplies evidence.
- Expose the merged primary-action semantics node with its own tap action so screen readers retain operability while duplicated visual child semantics remain excluded.
- Keep M5.2 read-only and schema-neutral. Production score/event execution and persistence require a later separately governed integration step.
- Treat the result as shareable visual hierarchy, not authorization to add OS sharing or expose route/raw telemetry.

## Progress log

- 2026-08-25: M5 and M5.1 authorized. Plan activated after confirming clean synchronized `main`, loading the scoped UI/testing contracts, inspecting existing implementation/tests, and capturing the current Tecno ready screen.
- 2026-08-25: Implemented the pure ready/live presentation reducer, recomposed the ready and live Drive views, suppressed primary navigation while recording, and added application/widget/navigation regressions for all governed states.
- 2026-08-25: Formatting and analysis passed; 101 Flutter tests and 211 native Kotlin tests passed with zero failures; repository validation found no known secret pattern or sensitive filename. Final debug and release APKs measured 166.17 MiB and 53.16 MiB.
- 2026-08-25: The Tecno debug cycle verified ready, live/degraded, confirmation/cancel, background, relaunch, notification, stopping, finalization, and scoped cleanup. ADB exposed the final Start node as enabled/clickable above fold in both debug and release. The exact pre-QA database hash and all four original trip roots were preserved, the exact QA trip and 106 generated chunks were removed, temporary device artifacts were deleted, and no recorder service remained.
- 2026-08-25: M5.2 authorized. Scoped UX/data/storage contracts and the current schema/finalization path confirmed that trip/chunk facts are persisted while production score/event analysis is not; implementation will preserve that distinction.
- 2026-08-25: Implemented immutable trip/result presentation models, a read-only fail-closed Drift repository, newest-first history, deep-link-safe results, honest unavailable-analysis states, aggregate local evidence, and repository/widget/navigation coverage without schema, dependency, recorder, analysis, account, or network changes.
- 2026-08-25: Final formatting and analysis passed; 114 Flutter tests and 211 native Kotlin tests passed with zero failures; repository JSON/YAML and secret validation passed. Debug and release APKs measured 166.21 MiB and 53.74 MiB.
- 2026-08-25: Tecno debug/release QA preserved the exact `b6cb4afe541a277dae5b0b70a7cd9ed11b9824457833288e710548f64b21d99c` database and all four existing trips. Newest-first history, result hierarchy, Android back, semantics, compact layout, 3,689 verified chunks, 2,322 GNSS samples, 939,895 motion samples, explicit missing analysis, clean fatal logs, and recorder-service inactivity were verified; temporary phone-side M5.2 dumps were removed.

## Completion summary

M5.1 and M5.2 are complete. The active M5 plan remains here for continuity and is stopped at the explicit M5.3 approval gate.
