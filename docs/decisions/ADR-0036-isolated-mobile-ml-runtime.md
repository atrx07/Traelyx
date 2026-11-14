# ADR-0036 — Isolated mobile ML runtime benchmark

**Status:** Accepted for experimental tooling only
**Date:** 2026-11-14

## Context

M7.4 needs quantized export and physical-device evidence for the frozen M7.2/3
source-space experiment. Its labels, timing and sensor units still prevent
production promotion. Adding a runtime to the recorder would confound this test
and unnecessarily expose live user state.

## Decision

Use ONNX and CPU-only ONNX Runtime 1.32.0 behind an isolated export/harness
boundary. Evaluate one predeclared S8S8 per-channel QDQ MinMax configuration,
fitting ranges exclusively on training windows. Keep both exported variants and
their numerical acceptance/rejection evidence. Do not retry against held-out
results. Preserve historical weights, normalizer, calibrator and reports.

Use a standalone, permission-free Android package with generated inputs only.
It has no app components except self-targeting instrumentation, no core-app
dependency, and no production integration. Strip ORT's default telemetry
provider and network permissions; set ORT_DISABLE_TELEMETRY before initialization
and explicitly disable telemetry. Verify the packaged manifest before install.
Only trusted generated, digest-checked models may be loaded. Remove this task's
benchmark package after gathering aggregates. Never read core-app private data.

ExecuTorch remains an alternative; its reviewed export dependency graph is
broader. This decision does not select a production runtime. See
`reference/EVENTNET_MOBILE_V1.md` for dependency review and reproducible protocol.

## Consequences

The optional native runtime adds substantial benchmark APK overhead even for
492 parameters. CPU timing includes Java/JNI/output handling; a short USB test
does not establish battery drain or recording reliability. A rejected quantized
artifact may be measured for engineering evidence, but cannot be integrated.
Removing this entire tool leaves core recording/scoring/history unchanged.
