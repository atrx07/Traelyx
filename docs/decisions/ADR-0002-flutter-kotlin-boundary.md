# ADR-0002 — Flutter UI + Native Kotlin Recorder Boundary

**Status:** Accepted

## Context

Flutter is excellent for UI/cross-platform logic, but reliable long-running Android GPS/IMU recording requires direct lifecycle/background control.

## Decision

Use Flutter/Dart for application/UI and portable analytics; use Kotlin native Android foreground-service infrastructure for acquisition/buffering. Connect through a versioned bridge.

## Consequences

Positive:
- robust screen-lock/background path;
- direct Android sensor APIs;
- future iOS can have equivalent native recorder behind shared Flutter UI.

Negative:
- two language/runtime boundaries;
- bridge/integration testing required.

## Revisit if

A mature open-source SDK demonstrably meets all timing/reliability/control requirements with lower complexity.
