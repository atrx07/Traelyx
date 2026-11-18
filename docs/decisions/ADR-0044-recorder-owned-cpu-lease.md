# ADR-0044 — Recorder-owned renewable CPU lease

**Status:** Accepted; bounded physical lifecycle/continuity and full source CI pass
**Date:** 2026-11-18

## Context

M8.2's unplugged, locked Tecno QA recording finalized intact but contained
~263-second motion gaps, zero GNSS fixes and ~19,200 samples per motion channel
over ~1,045 seconds. The recorder remained an active foreground service. Its
default calibrated sensors are non-wake-up sources, and acquisition held no CPU
wake lock. USB-connected M8.1 checks did not establish suspend behavior.

Android requires an application receiving non-wake-up sensor events during
screen-off operation to keep the application processor awake. A foreground
service alone is not that CPU guarantee. See
[SensorManager](https://developer.android.com/reference/android/hardware/SensorManager)
and [suspend-mode semantics](https://source.android.com/docs/core/interaction/sensors/suspend-mode).
See the [incident record](../issues/2026-11-18_screen-off-recorder-suspend.md)
for measured facts and the limits of attribution.

## Decision — power policy v1

The production native recorder owns a non-reference-counted partial wake lock
only while explicit recording/recovery acquisition and its final flush run.
Acquire after successful foreground promotion and before starting the writer or
sensor listeners. Keep it through GNSS loss; that is when motion evidence is
especially needed. Release on Stop, start failure, fatal failure and destruction.
Process death releases Android ownership; recovery establishes a new lease.

Use an SDK acquisition timeout of 120 seconds, renewed every 30 seconds. A lost,
expired, regressed-clock or failed lease is a visible recorder error and stops
acquisition; never silently reacquire after a potentially missing interval.
Duplicate Start does not add ownership. The timeout is a leak safeguard, not a
claim of a hard deadline under a stalled Android callback queue or OEM fault.

Pure lease tests cover renewal/loss/failures and idempotent release. Device QA
must verify held/released lifecycle and continuous unplugged samples. Android's
normal `WAKE_LOCK` permission adds no runtime prompt. Do not request battery
optimization exemption or change sensor rates, batching, frames or quality masks.

## Alternatives / consequences

- Retaining the no-lock assumption fails the observed locked/GNSS-loss case.
- Selecting different wake-up sensors is hardware-dependent and may change
  calibrated sensor characteristics; it is a separately governed acquisition
  decision, not a silent replacement of the current evidence sources.
- A lock in the QA observer during recording would hide the production defect.
  QA therefore uses no observer lock during recording. Its separate post-recording
  CPU-awake idle control is explicitly labeled, bounded and released, and is not
  presented as deep-suspend idle or an attributable battery-cost subtraction.

CPU wakefulness has a battery cost. M8.2 must measure it after continuity is
validated; low drain caused by missing evidence is not efficiency. No new
dependency, cloud access, sampling change, raw/schema migration, scoring/model
version or rewriting of historical results follows. Existing field/OEM/M6.8 and
ML acceptance gates remain open, and distribution remains held.

The corrected Tecno run passes 602 seconds of locked/unplugged continuity, with
recording elapsed time equal to uptime. GNSS was intermittent; uninterrupted
GNSS absence after repair remains untested. CPU was ~41% of one core, with motion
delivered near 200 Hz for 100 Hz requests. The short battery observation is coarse.
The separate idle observer requested a lease but still showed 23.458 seconds of
suspend; ownership alone is not an OEM wakefulness guarantee. See the
[baseline](../reference/PERFORMANCE_BASELINE_V1.md) for exact limits and cost.
