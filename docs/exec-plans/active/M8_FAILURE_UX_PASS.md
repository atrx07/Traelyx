# Execution Plan — M8.5 failure UX pass

**Status:** Complete — bounded synthetic failure/recovery and host UI pass
**Owner:** agent/maintainer
**Milestone:** M8.5
**Started / last updated:** 2026-11-18

## Context / goal

Authorized after M8.4 closure `da9908f`; user permits Pixel_10 emulator or
physical-phone UI inspection if needed. Review the canonical five failure areas:
low GPS, corruption, provider failure, invalid key and offline cloud. Keep local
recording/history usable and present bounded, actionable recovery guidance.

Read root/app/tests AGENTS, UX_SPEC sections6/7/16–19, COMMENTARY_SPEC section9,
SYNC_SPEC section8, MVP_SCOPE, DoD and existing affected implementation/tests.
Native acquisition contracts are read only to interpret existing health counters.
No unrelated ML, signing or historical plans are needed.

## Scope / implications

Inspect existing flows before repair. Current live summary can remain positive
despite reported GPS or storage failures; low-accuracy GNSS counters are not
presented. Provider failures already preserve built-in narration, and sync
failures already retain queues. Verify those guarantees through production
widgets/services and deterministic synthetic failures, including retry/recovery,
large text, reduced motion and bounded messages without raw errors or secrets.

No sensor thresholds, acquisition/wake policy, scoring, schema, dependency,
permission, consent, payload, account or live provider changes. Do not access
ordinary phone history, replace its app, send network requests or start M8.6.
Use host-rendered UI fixtures first; emulator inspection is optional if a
platform-dependent uncertainty remains. Any actual device check must identify
its separate scope and preserve existing app data/accounts.

## Steps / gates

- [x] Inspect the five required areas, existing specs and tests.
- [x] Repair confirmed misleading/missing failure guidance only.
- [x] Verify failures and explicit recovery with regression/widget tests.
- [x] Review narrow/large-text UI rendering and document limits.
- [x] Run formatting, analysis, full Flutter tests, builds/contracts and source CI.
- [x] Publish bounded matrix and synchronize status/roadmap for the completion commit.

## Acceptance / risks

Live GPS/storage failures must not look unqualifiedly healthy. Cumulative
low-accuracy evidence must not be called current accuracy or a fresh fix.
Missing/corrupt routes show no fabricated partial path and retain local data.
Cloud failures keep built-in narration, explain appropriate recovery and never
expose credentials/provider bodies or silently retry. Offline sync retains
history/queue and requires explicit foreground retry after the existing delay.
Critical controls remain usable with large text; no troubleshooting while moving.

Host injection cannot establish physical GNSS recovery, OEM behavior, provider
availability or real account/credential handling. Existing physical/ML acceptance,
pre-release profiling/private-reporting and distribution holds remain.

## Progress / completion

Live headline/save/GPS presentation and scrolled settings feedback repaired.
Corrupt-route reread and provider/summary guidance clarified. Affected 114 tests
and eight readable synthetic 390×844 / 2× captures pass; keyboard-inset feedback
layout is covered. Final analysis, all 636 Flutter tests, ordinary debug/arm64 release builds and
packaged privacy policy pass. All four
[source CI jobs 44277975977](https://github.com/atrx07/Traelyx/actions/runs/44277975977)
pass for `3fab32914b9d2b7916fb0ab4d2730eb712255b0f`, including full Flutter/native
tests, generated schemas, eight Linux PNG captures, QA builds/lint, ordinary APKs
and independent packaged privacy policy. Product repairs are in `40debce` and the
capture portability correction is in `3fab329`.
No device or live provider/account interaction. See FAILURE_UX_PASS_V1.md.
Initial checkpoint `40debce` CI44275674425 exposed exact-case SDK font paths
hidden by Windows and a cached failed-load future that stalled later captures.
The run was cancelled to inspect logs; use exact official archive names and cache
only successful loads. Local bytes match the immutable SDK archive. No font or
dependency was added. Its unrelated standalone benchmark also failed packageDebug
without a nested cause; the unchanged benchmark passes the fresh source run.

M8.5 is complete at this bounded scope. Schema remains 4, with no new dependency,
permission, acquisition/scoring/consent/payload change or ordinary phone access.
Actual device keyboard/accessibility, physical sensor/storage/OEM recovery,
provider/key acceptance and hosted sync remain unverified. Pre-release profiling,
private reporting, carried M6.8/M7 acceptance and distribution holds remain.
Persist the docs-only closure to origin/main and verify clean synchronization.
Stop after M8.5; M8.6 requires explicit authorization and has not begun.
