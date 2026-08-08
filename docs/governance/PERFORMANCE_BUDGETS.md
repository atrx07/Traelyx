# PERFORMANCE_BUDGETS.md — Size, Runtime, Battery & Storage Budgets

## When to read

Read when adding heavy dependencies/assets/models, changing sensor sampling/filtering, modifying replay animation, or preparing release.

## 1. Philosophy

Budgets begin as provisional targets and become measured gates. Do not invent precision before benchmarking.

## 2. APK size

Provisional goals:

- keep modern arm64 release APK comfortably below ~80 MB if practical;
- investigate unexplained >10 MB release-over-release growth;
- avoid >120 MB without a documented reason;
- large local LLMs are separate downloads, never silently bundled.

Actual budgets should be recalibrated after first full-feature build.

## 3. Core ML

Aim for total core classifier/anomaly models in low tens of MB or less, ideally ~5–12 MB combined if quality supports it.

## 4. Replay

Target smooth 60 fps on supported mid/high-range devices during normal replay. Degrade effects before dropping core synchronization.

Measure frame times rather than eyeballing.

## 5. Recorder

Establish measured targets after Stage 2 prototype for:

- battery drain %/hour;
- CPU %;
- memory;
- dropped IMU samples;
- GNSS gaps;
- thermal impact.

No final numeric gate is set until real-device baseline exists.

## 6. Inference

Set target inference latency per EventNet window after prototype. It must be comfortably below window cadence and not monopolize UI thread.

Run inference outside UI-critical execution path.

## 7. Storage

Measure raw MB/hour by configured sampling. The storage manager should make retention transparent.

Map cache and downloaded local models have user-visible size/clear actions.

## 8. Database scale

Trip list/detail should remain responsive with at least 1,000 summarized trips on target hardware; exact query-time budgets become concrete after first implementation.

## 9. Regression reporting

Release notes/CI should surface:

- APK size;
- bundled model size;
- critical benchmark deltas;
- major DB growth changes.
