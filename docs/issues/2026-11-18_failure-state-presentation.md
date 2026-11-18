# Live failures and scrolled provider feedback were easy to miss

**Status:** Reproduced in synthetic fixtures; presentation repair and affected
regressions, full 636-test Flutter suite, analysis/builds and packaged policy pass.
Source CI and fix commit pending.

## Symptoms / cause

The live Drive model selected its healthy headline after checking initial sample
counts and persistent motion accuracy, without checking existing GPS/save failure
counters. Compact health could show a problem while the main headline stayed
positive. The bridge's cumulative low-accuracy GPS counter was not presented.
The existing bridge test fixture already contained one such fix. New probes fail
on the previous presentation for GPS off/error, low accuracy and storage errors.

Commentary settings placed failure feedback near the top of a long lazy list.
Testing the connection farther down the form could create an off-screen message.
This is a presentation defect; no actual missed field warning, lost trip, leaked
key or hosted incident was established.

## Repair / validation

Live headline priority now includes save/verification failures and GPS evidence
limitations using existing counters, preserving the stop/confirmation controls.
Copy distinguishes cumulative limitations from current GPS accuracy and avoids
guaranteeing continued preservation after save failures. All health details stay
available; there is no new sensor/scoring/safety transition.

Settings feedback stays visible outside the scrolling form, with a live region
and bounded scrollable height above keyboard insets. Credential/provider guidance is bounded; corrupt
route retry remains a nondestructive reread. Offline summary messages distinguish
a failed upload from a no-due-work attempt. The [five-area matrix](../reference/FAILURE_UX_PASS_V1.md)
checks synthetic failure/recovery, no automatic requests, local data/queue
preservation, large text and reduced motion. No production database/schema,
dependency, permission, payload or ordinary phone installation changed.

## Recovery / remaining risks

Park before reviewing recorder warnings. Missing evidence cannot be recreated by
this UI. Route retry does not repair damaged files. Replacing a key is local and
turns cloud permission off; a later send still needs explicit consent. Failed
summary uploads retain their queue and existing backoff/ownership rules.

Host fixtures do not establish current GPS freshness, real provider acceptance,
physical storage/OEM recovery or Android keyboard/accessibility behavior.
