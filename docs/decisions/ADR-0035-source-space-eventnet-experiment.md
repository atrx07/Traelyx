# ADR-0035 — Source-space EventNet experiment before production feature alignment

**Status:** Accepted
**Date:** 2026-11-11

## Context

M7.2 calls for a small TCN baseline with driver-held-out evaluation. The M7.1
source version 2 cannot support grouping/timing and stays quarantined. The
publisher's version 3 adds driver/class/task IDs to the same 1,114 rows, allowing
a predeclared driver split, while sampling/units/frame/labels remain limited.

## Decision

Add registry schema v2 specifically for a source-space, experiment-only import.
Preserve v1 entries/results and the existing synthetic corpus. Remove clock-of-
day, retain coarse relative time, and group by driver/class/task before windowing.
Use one fixed trailing seven-source-row window per task, not invented timing.
Freeze driver 1/2/3 as train/validation/test, train-only normalization and
validation-only checkpoint selection. Keep four source labels separate from
governed Traelyx events. No final score or safety state consumes these outputs.

Use isolated hash-pinned CPU PyTorch for training. Save a small, data-only JSON
checkpoint and full provenance/uncalibrated metrics, with unsupported severe/
timing metrics explicitly unavailable. No pickle or pretrained model is loaded.
The detailed immutable experiment contract is `reference/EVENTNET_BASELINE_V1.md`.

## Consequences

A working held-out-driver baseline is possible without silently accepting the
data as production-ready or changing M7.1's conclusions. The small population
and feature/label mismatch cap interpretation; no mobile/generalization/safety
claim follows from macro F1. M7.3 calibration and M7.4 export stay separately
authorized, and promotion needs suitable verified evidence and all normal gates.
