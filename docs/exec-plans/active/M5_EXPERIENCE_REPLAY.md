# Execution Plan — M5 Experience & Replay

**Status:** Active
**Owner:** agent/maintainer
**Milestone:** M5 — Experience & Replay
**Started:** 2026-08-25
**Last updated:** 2026-08-25

## Context budget / references

Read only:

- `AGENTS.md` and `app/AGENTS.md`
- `docs/product/UX_SPEC.md` sections 9–10 and 17–18
- `docs/technical/MAP_ARCHITECTURE.md`, the M3.7 replay-channel contract in `TELEMETRY_SPEC.md`, the replay-marker rules in `EVENT_ENGINE.md`, and the map-cache section of `STORAGE_SPEC.md`
- `android/AGENTS.md` and only the native chunk/bridge sections needed for a read-only local route boundary
- `docs/governance/TESTING_POLICY.md`, `DEFINITION_OF_DONE.md`, and the roadmap synchronization/approval sections of `DOCUMENTATION_POLICY.md`
- `docs/exec-plans/ROADMAP.md` M5 and `docs/exec-plans/milestones/M5_EXPERIENCE_REPLAY.md`
- affected Flutter trip-result/map code, native read-only route bridge, and tests

Do not inspect M5.6 or later implementation until its approval gate. Autonomous playback, replay animation, commentary, ML, cloud, online tile-provider selection, and unrelated technical specifications remain outside M5.5.

## Goal

Add one deterministic manual replay clock that synchronizes the existing verified route, a coordinate-free evidence graph, and persisted governed event ranges without changing recorder acquisition, analysis meaning, or requiring a network service.

## User-visible result

Completed Drive, Trips, DNA, and offline route experiences remain intact. A trip result exposes one scrub control and time cursor shared by its map marker, route/event evidence graph, and persisted event selection. Missing route or event evidence remains explicit and cannot fabricate telemetry, while the timeline stays useful when one visual layer is unavailable.

## In scope

- Completed M5.1–M5.4 experiences.
- M5.5 synchronized manual replay clock only.
- Deterministic route-marker interpolation that never crosses a governed route gap and handles the antimeridian by the shortest longitude path.
- One coordinate-free evidence graph and cursor over verified route-coverage spans and persisted event ranges, with event-to-time seeking.
- Explicit absent/invalid layer behavior, accessible scrub semantics, text-scale/reduced-motion compatibility, and physical offline Tecno QA.

## Out of scope

- M5.6 replay animation and every later M5 substep.
- Autonomous playback/timers, play/pause/speed controls, camera or path animation, event pulses, or commentary.
- Online tiles, geocoding, provider credentials, downloaded regions, or a third-party map dependency/provider choice.
- New replay-telemetry/native bridge, score/event/baseline persistence, or analysis execution; M3.7 display channels remain native-only until separately governed exposure exists.
- Native acquisition/service/recorder semantics, database schema, permissions, export format, account, share transport, or network behavior changes.
- New dependencies or provider choices.

## Preconditions

- M0–M4 are complete and archived.
- Maintainer authorized M5 and M5.1 on 2026-08-25.
- Maintainer authorized M5.2 on 2026-08-25 after M5.1 completed at `8cf95902803fc227e5a26749a178c583c70c69ab`.
- Maintainer authorized M5.3 on 2026-08-25 after M5.2 completed at `c233cc5f2a300defaa804ed75de0508f1c09d12d`.
- Maintainer authorized M5.4 on 2026-08-25 after M5.3 completed at `5829c13107456ce394c6779040fa337e84893b17`.
- Maintainer authorized M5.5 on 2026-08-25 after M5.4 completed at `f2c1f147269051e70427d3a61c9f9a2305c8e9fd`.
- Local `main` was clean and synchronized with `origin/main` at `f2c1f147269051e70427d3a61c9f9a2305c8e9fd` before M5.5 began.
- A Tecno LH8n is connected through ADB for physical validation.
- Maintainer requires the Tecno to remain Wi-Fi/data offline by default and to be notified before any phone-side internet is requested. The active SIM data flag, Wi-Fi flag, and active default network were confirmed off/off/none at M5.5 start.

## Affected components

- `lib/features/trips/domain/` immutable replay timeline/interpolation state
- `lib/features/trips/application/` deterministic manual clock controller
- `lib/core/maps/` offline route marker rendering
- the trip-result replay section and coordinate-free evidence timeline graph
- related domain/controller/renderer/widget/navigation tests
- roadmap/status documentation

## Data/privacy/security implications

No new collection, persistence, permission, secret, share transport, analytics, tile request, or network flow. The clock consumes only the already-transient bounded route geometry and allowlisted persisted event ranges. Coordinates remain excluded from timeline graph data, semantics, logs, diagnostics, analytics, cache metadata, and network payloads.

## Compatibility/migration implications

No schema, platform-channel, or data migration. Map-data/recorder bridge v1, raw chunk/schema versions, M3.7 replay telemetry, scoring, and historical results remain unchanged.

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
- [x] 15. Add an isolated versioned native route bridge that verifies complete local chunk evidence, applies governed GNSS sanity decisions, and returns bounded transient display geometry without storage metadata.
- [x] 16. Activate the provider-neutral map/cache contract with an offline canvas and integrate truthful available/unavailable/error route states into local trip results.
- [x] 17. Cover native reduction/invalid evidence, strict Dart parsing, renderer geometry, cache controls, privacy semantics, reduced motion, large text, and navigation compatibility.
- [x] 18. Run all M5.4 host/device gates offline, synchronize status, commit/push atomically, verify remote main and CI, then stop at M5.5.
- [x] 19. Add immutable replay timeline/snapshot models and one deterministic manual clock with bounded seeking, gap-safe/dateline-safe route interpolation, and persisted-event activation.
- [x] 20. Synchronize the offline map marker, coordinate-free route/event evidence graph, scrub control, time labels, and event seeking without autonomous animation.
- [x] 21. Cover clock boundaries, gaps, antimeridian, unavailable/invalid layers, event ranges, semantics/privacy, reduced motion, text scale, and navigation compatibility.
- [x] 22. Run all M5.5 host/device gates offline, synchronize status, commit/push atomically, verify remote main and CI, then stop at M5.6.

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
- [x] focused M5.4 native route bridge, Dart parser, map controller/renderer, widget, and navigation tests
- [x] M5.4 missing/corrupt/gapped/oversized route and cache-state checks
- [x] M5.4 reduced-motion, semantics/privacy, text-scale, and narrow/wide layout checks
- [x] M5.4 Tecno debug/release route rendering and explicit offline cold-launch QA with database preserved
- [x] focused M5.5 timeline, controller, map-marker, evidence-graph, widget, and navigation tests
- [x] M5.5 clock bounds, gaps, antimeridian, route/event layer independence, contradictory-event, and event-seek checks
- [x] M5.5 coordinate-free semantics, adjustable actions, 2× text, zero-duration event, and no-autoplay checks
- [x] M5.5 Tecno debug/release genuine-route scrub QA with synchronized marker/graph, database preserved, and phone fully offline

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
- M5.2 summary/result models continue to exclude raw routes, chunk paths, checksums, and device identifiers; M5.4 precise geometry is isolated to a bounded transient route model and never enters semantics or logs.
- Direct `/trips/:tripId` navigation is safe, missing records fail clearly, and large text keeps back/navigation and result content reachable.
- DNA uses an original ring/fingerprint signature rather than a generic radar chart, while every dimension remains understandable without the graphic or color.
- Complete, partial, and unavailable profile evidence remain distinct from uncalibrated, emerging, established, and recalibrating lifecycle state.
- Values and recent direction render only from a strict persisted snapshot; missing or malformed evidence never becomes a score, trend, percentile, or confidence claim.
- Reduced motion removes signature interpolation, large text remains scrollable, and screen readers receive a complete textual profile summary.
- No baseline owner key, baseline/trip ID, route, raw sample, vehicle/context identifier, or storage path enters UI models or semantics.
- A selected local trip renders verified GNSS geometry without an account, tile service, or network; start, end, and discontinuities are distinguishable without color.
- Missing, incomplete, corrupt, mixed-version, or contradictory native evidence fails closed to an explicit route-unavailable state rather than a partial or synthetic path.
- Feature code consumes only Traelyx map coordinates/intents/cache state; no provider SDK type or endpoint leaks into domain or presentation code.
- The offline renderer fits route bounds, avoids connecting across governed GNSS gaps, remains usable at 2× text, and exposes a coordinate-free semantic summary.
- Cache bytes/availability are visible and clearable; the local-canvas provider truthfully reports zero unavailable tile cache and performs no network request.
- One deterministic manual clock drives the time labels, scrub control, verified route marker, coordinate-free evidence cursor, and persisted event activation/seeking.
- Route-marker interpolation never crosses a governed gap and follows the shortest longitude path at the antimeridian; times without verified position remain explicitly unavailable.
- Missing route geometry does not remove valid persisted event timing, missing events do not remove route replay, and malformed or out-of-range event ranges are excluded rather than extending independent recorded evidence.
- Replay semantics expose only duration, time, verified span/event counts, and marker availability; no coordinate, trip ID, raw sample, storage path, or provider metadata is announced.
- M5.5 remains manual and deterministic: it introduces no timer, autoplay, camera/path animation, event pulse, playback-speed control, or new native replay-telemetry bridge.

## Risks

- The bridge does not currently expose authoritative live speed, distance, or elapsed duration, so M5.1 must not synthesize them.
- A live screen can hide useful failure detail if health reduction is too aggressive; typed aggregate warning states and tests must keep limitations visible.
- Navigation suppression must follow the shared recorder provider without creating a second recorder state source.
- Physical QA on one Android 14 OEM does not establish multi-device layout or lifecycle reliability.
- Production finalization currently leaves distance, confidence, events, and scores unavailable; M5.2 must present those absences as product truth rather than synthesizing analysis.
- Schema-v1 text states and aggregate JSON must be reduced through explicit allowlisted parsing before presentation.
- Production currently persists no governed M4.5/M4.6 baseline snapshot, so physical M5.3 QA can validate only the truthful unavailable state rather than a real established profile.
- The baseline table's JSON payload predates an application presentation contract; the adapter must accept only an explicit allowlisted snapshot shape and fail visibly for anything else.
- Returning precise geometry across an in-process bridge expands transient location exposure; strict result parsing, bounded points, no semantics/logging, and an isolated contract must prevent it from leaking into diagnostics or unrelated UI state.
- Loading thousands of native chunks can block UI or overgrow a method-channel payload; route decoding must run off the UI thread and display reduction must have a deterministic hard bound.
- A route-only canvas lacks street context by design; copy must call it an offline route view rather than implying that basemap tiles are present.
- The genuine Tecno trips have no persisted governed events, so event-button and active-range behavior is deterministic widget/domain evidence rather than a physical persisted-event claim.
- M3.7 replay telemetry remains native-only; the M5.5 evidence graph represents verified route coverage and persisted event ranges, not speed/acceleration/yaw display channels.

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
- Keep recorder bridge v1 coordinate-free. Introduce a separate map-data contract so precise selected-trip geometry cannot leak into recorder health/diagnostics consumers.
- Use the governed M3.2 sanity decisions for route inclusion and segment breaks; do not draw every raw fix or reimplement telemetry validity in Flutter.
- Ship a dependency-free local canvas as the M5.4 provider so core route rendering is useful offline and no tile endpoint, credential, policy dependency, or mandatory cost is introduced.
- Decode and validate one chunk at a time while retaining only GNSS records for display. The first physical build exposed unacceptable heap pressure from materializing roughly 940,000 motion samples for a route-only read; the streaming path preserves the same strict envelope validation without retaining IMU objects.
- Use one application-owned manual clock over already available recorded duration, verified route offsets, and persisted event ranges. Do not add a timer or expose M3.7 native replay channels during M5.5.
- Let recorded duration and verified route extent establish the independent clock boundary; accept event-only timing when it is the sole evidence, but exclude persisted events that contradict an independently established extent.
- Interpolate only within one verified route segment, use the shortest antimeridian longitude delta, and report no marker inside governed gaps.
- Give the route image, adjustable clock, and evidence graph isolated coordinate-free semantics nodes; physical UI-Automator hierarchy is part of the accessibility gate because widget semantics alone did not expose OEM node merging.

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
- 2026-08-25: M5.4 authorized. Clean synchronized main, scoped map/UX/storage/native contracts, and the physical Tecno were checked. The active SIM data flag and Wi-Fi are off with no active default network; phone-side internet is neither required nor authorized implicitly.
- 2026-08-25: Implemented the separate map-data bridge, strict bounded Dart adapter, dependency-free offline canvas, fit/start/end/gap rendering, coordinate-free semantics, truthful unavailable/error states, and zero-byte unavailable cache control. No dependency, endpoint, credential, schema, recorder, account, or upload behavior changed.
- 2026-08-25: First-device profiling caught route-only decoding materializing 939,895 motion samples and peaking near the Tecno's 256 MiB Java heap. Replacing that path with complete per-chunk validation that retains only GNSS reduced the observed Java heap to about 17 MiB while preserving the genuine 2,322-sample route result; the optimized route rendered 2,122 bounded points across 10 segments with 9 gaps.
- 2026-08-25: Final formatting and analysis passed; 138 Flutter tests, 214 native Kotlin tests, three trip-debug inspector tests, and repository JSON/YAML/secret validation passed with zero failures. Debug and release APKs measured 166.28 MiB and 54.23 MiB.
- 2026-08-25: Tecno optimized-debug/release QA verified the genuine 39-minute route, start/end and non-color gap cues, scroll/layout, coordinate-free semantics, cache no-op feedback, clean fatal logs, recorder-service inactivity, and explicit offline operation. Wi-Fi/data/default network remained off/off/none throughout, the exact database hash and four existing trips were preserved, final debug was restored, and all phone-side M5.4 artifacts were removed.
- 2026-08-25: M5.5 authorized after synchronized `main` at `f2c1f147269051e70427d3a61c9f9a2305c8e9fd`. Scoped replay/map/event contracts and the Tecno baseline confirmed that M5.5 could reuse existing route offsets and persisted event ranges without phone internet, a dependency, schema change, or native bridge expansion.
- 2026-08-25: Implemented immutable replay timeline/snapshot state, a timer-free manual clock, bounded event activation/seeking, gap-safe/dateline-safe marker interpolation, a coordinate-free route/event evidence graph, and synchronized trip-result controls. Invalid layers fail independently and no coordinate enters graph data or semantics.
- 2026-08-25: Focused QA caught and fixed a 2×-text legend overflow and missing screen-reader adjustment actions. Physical debug QA then caught OEM semantics-node merging; route, slider, and graph semantics were isolated and verified as compact coordinate-free nodes on the rebuilt APK.
- 2026-08-25: Final formatting and analysis passed; 145 Flutter tests, 214 native Kotlin tests, three trip-debug inspector tests, and repository JSON/YAML/secret validation passed with zero failures. Debug and release APKs measured 166.30 MiB and 54.68 MiB.
- 2026-08-25: Tecno debug/release QA loaded the genuine 39m17s route with 2,122 display points, 10 spans, and 9 gaps, then scrubbed to 31:00 with synchronized route marker and evidence cursor. Wi-Fi/data/default network stayed off/off/none, no fatal app log or recorder service appeared, the exact database hash and four trips were preserved, final debug was restored, and all phone-side M5.5 artifacts were removed.

## Completion summary

M5.1 through M5.5 are complete. M5.5 adds only a deterministic manual application clock over existing verified route offsets and persisted event ranges; M5.6 replay animation is not authorized.
