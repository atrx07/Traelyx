# Execution Plan — M5 Experience & Replay

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M5 — Experience & Replay
**Started:** 2026-08-25
**Last updated:** 2026-08-25

## Context budget / references

Read only:

- `AGENTS.md` and `app/AGENTS.md`
- `docs/product/UX_SPEC.md` sections 7–8 and 17–18
- `docs/product/DRIVE_DNA_SPEC.md`, plus the baseline shape in `docs/technical/DATA_MODEL.md`
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization/approval sections of `DOCUMENTATION_POLICY.md`
- `docs/exec-plans/ROADMAP.md` M5 and `docs/exec-plans/milestones/M5_EXPERIENCE_REPLAY.md`
- affected Flutter DNA/navigation/database-access code and tests

Do not inspect M5.4 or later implementation until its approval gate. Map, replay, commentary, ML, cloud, and unrelated technical specifications remain outside M5.3.

## Goal

Turn the existing recorder controls, local trip index, and governed Drive DNA lifecycle into a calm accountless experience with a truthful original signature visual, without changing native recorder or analysis semantics.

## User-visible result

Drive and Trips retain their completed local-first experiences. DNA presents a fingerprint-like ring signature with individually understandable dimensions, lifecycle/evidence state, recent direction only when persisted, version provenance, and an honest insufficient-history state when no governed baseline exists.

## In scope

- Completed M5.1 Ready/Drive and M5.2 Trip history/result experiences.
- M5.3 Drive DNA visual only.
- Widget, navigation, accessibility, text-scale, and physical Tecno QA.
- Read-only local `driver_baselines` snapshots from schema version 1.
- Original ring/signature, dimension legend, lifecycle, trend, provenance, and complete/partial/unavailable states.
- Loading/error/malformed-evidence and truthful no-persisted-baseline states.

## Out of scope

- M5.4 map work and every later M5 substep.
- New baseline/score/event persistence or production execution of the M4 analysis engine.
- New comparison, percentile, trend, or confidence claims not already present in a governed persisted snapshot.
- Native recorder, bridge, telemetry, database schema, permissions, export format, account, share transport, or network behavior changes.
- New dependencies or provider choices.

## Preconditions

- M0–M4 are complete and archived.
- Maintainer authorized M5 and M5.1 on 2026-08-25.
- Maintainer authorized M5.2 on 2026-08-25 after M5.1 completed at `8cf95902803fc227e5a26749a178c583c70c69ab`.
- Maintainer authorized M5.3 on 2026-08-25 after M5.2 completed at `c233cc5f2a300defaa804ed75de0508f1c09d12d`.
- Local `main` was clean and synchronized with refreshed `origin/main` at `c233cc5f2a300defaa804ed75de0508f1c09d12d` before M5.3 began.
- A Tecno LH8n is connected through ADB for physical validation.

## Affected components

- new `lib/features/drive_dna/` domain, read-only data, application-provider, painter, and presentation boundaries
- `lib/app/traelyx_router.dart`
- related Flutter widget/application/navigation tests
- roadmap/status documentation

## Data/privacy/security implications

No new data collection, storage, permission, identifier, secret, raw route display, share transport, or network flow. DNA reads only the latest existing local baseline snapshot; owner namespace, baseline ID, trip IDs, raw telemetry, route data, and device/context identifiers never enter presentation state. No baseline is synthesized from the Tecno's existing trips.

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
- [x] 11. Add immutable Drive DNA presentation models and a strict read-only adapter over existing baseline snapshots.
- [x] 12. Replace the DNA placeholder with the original accessible ring signature, lifecycle/progress, dimension, trend, and provenance hierarchy.
- [x] 13. Cover complete, partial, unavailable, emerging, recalibrating, malformed, loading/error, reduced-motion, semantics, and large-text behavior.
- [x] 14. Run all M5.3 host/device gates, synchronize status, commit/push atomically, verify remote main and CI, then stop at M5.4.

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
- [x] focused M5.3 model/repository/widget/navigation/painter tests
- [x] M5.3 complete/partial/unavailable/loading/error/malformed-evidence checks
- [x] M5.3 reduced-motion, semantics, text-scale, and narrow/wide layout checks
- [x] M5.3 Tecno debug/release local-only DNA smoke with database preserved

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
- DNA uses an original ring/fingerprint signature rather than a generic radar chart, while every dimension remains understandable without the graphic or color.
- Complete, partial, and unavailable profile evidence remain distinct from uncalibrated, emerging, established, and recalibrating lifecycle state.
- Values and recent direction render only from a strict persisted snapshot; missing or malformed evidence never becomes a score, trend, percentile, or confidence claim.
- Reduced motion removes signature interpolation, large text remains scrollable, and screen readers receive a complete textual profile summary.
- No baseline owner key, baseline/trip ID, route, raw sample, vehicle/context identifier, or storage path enters UI models or semantics.

## Risks

- The bridge does not currently expose authoritative live speed, distance, or elapsed duration, so M5.1 must not synthesize them.
- A live screen can hide useful failure detail if health reduction is too aggressive; typed aggregate warning states and tests must keep limitations visible.
- Navigation suppression must follow the shared recorder provider without creating a second recorder state source.
- Physical QA on one Android 14 OEM does not establish multi-device layout or lifecycle reliability.
- Production finalization currently leaves distance, confidence, events, and scores unavailable; M5.2 must present those absences as product truth rather than synthesizing analysis.
- Schema-v1 text states and aggregate JSON must be reduced through explicit allowlisted parsing before presentation.
- Production currently persists no governed M4.5/M4.6 baseline snapshot, so physical M5.3 QA can validate only the truthful unavailable state rather than a real established profile.
- The baseline table's JSON payload predates an application presentation contract; the adapter must accept only an explicit allowlisted snapshot shape and fail visibly for anything else.

## Decisions made during execution

- Use only existing versioned aggregate bridge evidence; do not expand the native bridge for decorative metrics.
- Keep `.tripdebug` export available after finalization but below the primary recording flow because it is a privacy-sensitive developer/user tool, not the ready-state objective.
- Protect End Drive with a confirmation step rather than a gesture that could be inaccessible or hard to discover.
- Treat idle motion health as `On Start`, because the native idle aggregate does not prove current sensor availability; surface persistent unreliable accuracy as `Limited` only after recording supplies evidence.
- Expose the merged primary-action semantics node with its own tap action so screen readers retain operability while duplicated visual child semantics remain excluded.
- Keep M5.2 read-only and schema-neutral. Production score/event execution and persistence require a later separately governed integration step.
- Treat the result as shareable visual hierarchy, not authorization to add OS sharing or expose route/raw telemetry.
- Keep M5.3 read-only and schema-neutral; an empty baseline table is a valid uncalibrated product state, not permission to derive a profile in Flutter.
- Render recent direction only when the persisted snapshot contains an explicit bounded delta; do not infer a trend from timestamps or trip counts.

## Progress log

- 2026-08-25: M5 and M5.1 authorized. Plan activated after confirming clean synchronized `main`, loading the scoped UI/testing contracts, inspecting existing implementation/tests, and capturing the current Tecno ready screen.
- 2026-08-25: Implemented the pure ready/live presentation reducer, recomposed the ready and live Drive views, suppressed primary navigation while recording, and added application/widget/navigation regressions for all governed states.
- 2026-08-25: Formatting and analysis passed; 101 Flutter tests and 211 native Kotlin tests passed with zero failures; repository validation found no known secret pattern or sensitive filename. Final debug and release APKs measured 166.17 MiB and 53.16 MiB.
- 2026-08-25: The Tecno debug cycle verified ready, live/degraded, confirmation/cancel, background, relaunch, notification, stopping, finalization, and scoped cleanup. ADB exposed the final Start node as enabled/clickable above fold in both debug and release. The exact pre-QA database hash and all four original trip roots were preserved, the exact QA trip and 106 generated chunks were removed, temporary device artifacts were deleted, and no recorder service remained.
- 2026-08-25: M5.2 authorized. Scoped UX/data/storage contracts and the current schema/finalization path confirmed that trip/chunk facts are persisted while production score/event analysis is not; implementation will preserve that distinction.
- 2026-08-25: Implemented immutable trip/result presentation models, a read-only fail-closed Drift repository, newest-first history, deep-link-safe results, honest unavailable-analysis states, aggregate local evidence, and repository/widget/navigation coverage without schema, dependency, recorder, analysis, account, or network changes.
- 2026-08-25: Final formatting and analysis passed; 114 Flutter tests and 211 native Kotlin tests passed with zero failures; repository JSON/YAML and secret validation passed. Debug and release APKs measured 166.21 MiB and 53.74 MiB.
- 2026-08-25: Tecno debug/release QA preserved the exact `b6cb4afe541a277dae5b0b70a7cd9ed11b9824457833288e710548f64b21d99c` database and all four existing trips. Newest-first history, result hierarchy, Android back, semantics, compact layout, 3,689 verified chunks, 2,322 GNSS samples, 939,895 motion samples, explicit missing analysis, clean fatal logs, and recorder-service inactivity were verified; temporary phone-side M5.2 dumps were removed.
- 2026-08-25: M5.3 authorized. Scoped UX/Drive DNA/data contracts and current schema confirmed that the UI must support governed baseline snapshots while the physical Tecno truthfully remains uncalibrated because production baseline persistence is not integrated.
- 2026-08-25: Implemented immutable Drive DNA presentation state, a strict read-only Drift adapter, original custom-painted ring signature, textual dimensions/trends, lifecycle/progress, provenance, claim-free empty/error states, reduced motion, and responsive accessibility without schema, dependency, analysis, recorder, account, or network changes.
- 2026-08-25: Final formatting and analysis passed; 127 Flutter tests and 211 native Kotlin tests passed with zero failures; repository JSON/YAML and secret validation passed. Debug and release APKs measured 166.25 MiB and 54.07 MiB.
- 2026-08-25: Tecno debug/release and explicit offline QA verified the truthful uncalibrated ring screen, full semantics, scrolling, lower explanations, release parity, clean fatal logs, and recorder-service inactivity. Connectivity was restored exactly, the database remained `b6cb4afe541a277dae5b0b70a7cd9ed11b9824457833288e710548f64b21d99c`, final debug was restored, and all phone-side M5.3 dumps were removed.

## Completion summary

M5.1 through M5.3 are complete. The active M5 plan remains here for continuity and is stopped at the explicit M5.4 approval gate.
