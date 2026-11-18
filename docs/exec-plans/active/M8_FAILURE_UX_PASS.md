# Execution Plan — M8.5 failure UX pass

**Status:** Active
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
- [ ] Run formatting, analysis, full Flutter tests, builds/contracts and source CI.
- [ ] Publish bounded matrix, synchronize status/roadmap, commit/push and verify.

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
Corrupt-route reread and provider/summary guidance clarified. Affected114 tests
and eight readable synthetic 390×844 / 2× captures pass; keyboard-inset feedback
layout is covered. Final analysis, all 636 Flutter tests, ordinary debug/arm64 release builds and
packaged privacy policy pass. Source CI remains pending; the source checkpoint
is not substep completion.
No device or live provider/account interaction. See FAILURE_UX_PASS_V1.md.
Stop after M8.5; M8.6 requires explicit authorization.
