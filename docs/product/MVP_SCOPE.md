# Traelyx — v0.1 MVP Scope

## When to read

Read before adding a feature, expanding an execution plan, or accepting "while we're here" work. This is the anti-scope-creep contract.

## MVP objective

Ship a GitHub-distributed signed Android APK that feels technically serious and distinctive, while remaining stable enough for real users to record and analyze trips.

## IN SCOPE — Foundation

- Flutter Android application.
- Native Kotlin recorder/foreground service.
- Local-first accountless mode.
- Drift/SQLite structured storage.
- Compact raw telemetry chunk storage.
- App settings and diagnostics.
- GitHub CI for tests/build validation.
- Local release signing workflow.

## IN SCOPE — Recording / telemetry

- Manual start/stop trip recording.
- GNSS location, speed, bearing, accuracy, timestamps.
- Accelerometer and gyroscope acquisition.
- Sensor/GNSS timestamp alignment.
- calibration/orientation correction approach suitable for mobile mounting.
- filtering/noise handling.
- distance/duration/moving time.
- longitudinal/lateral/vertical derived motion where confidence permits.
- telemetry confidence and sensor integrity flags.
- robust background/screen-lock recording.

## IN SCOPE — Analysis

- deterministic event baseline;
- hard/abrupt acceleration evidence;
- hard/abrupt braking evidence;
- cornering/high lateral-load evidence;
- road-impact/pothole distinction support where feasible;
- phone-moved / invalid-orientation evidence;
- explainable versioned scoring;
- Drive DNA dimensions;
- historical baseline/trend comparison;
- integrity audit and rank eligibility.

## IN SCOPE — Experience

- dark-first original design system;
- 5-or-fewer primary navigation destinations;
- minimal drive mode;
- trip history/details;
- synchronized animated replay;
- event-anchored animated commentary bubbles;
- commentary tone selector;
- reduced-motion accessibility;
- storage manager;
- export/debug fixture support.

## IN SCOPE — Accounts / online

Subject to free-tier viability:

- Supabase Auth;
- email/password or passwordless fallback as selected during implementation;
- Google sign-in where configuration remains free/practical;
- profiles;
- compact cloud trip summaries;
- social/friend capability;
- safe rankings;
- Guardian Connect;
- Row Level Security;
- user data deletion path.

## IN SCOPE — Commentary

- procedural narrator built into app;
- provider abstraction;
- optional BYO cloud API key;
- Groq adapter may be first cloud provider, but code must not depend on one permanent model;
- model discovery/configurable model selection;
- sanitized event dossier; no full route required;
- fallback to procedural narrator.

A downloadable local LLM is **optional/stretch within v0.1** only if it does not jeopardize recorder/scoring quality. The architecture must support it even if the model package ships later.

## IN SCOPE — ML

- model/data pipeline skeleton;
- EventNet candidate (small temporal model, likely TCN);
- context model candidate where proven useful (GRU/TCN);
- anomaly/integrity model candidate;
- model manifests/audit logs;
- on-device inference benchmark;
- user correction/labeling UX after drives where appropriate;
- opt-in anonymized data contribution design.

A deterministic baseline must work before ML promotion.

## EXPLICITLY POST-MVP

Unless the maintainer changes scope:

- iOS production release;
- Google Play/App Store distribution;
- paid services required for core operation;
- OBD-II hardware integration;
- turn-by-turn navigation;
- radar/camera enforcement databases;
- public-road racing modes;
- max-speed competition;
- convoy voice/chat platform;
- large bundled LLMs;
- automatic video creation/editing;
- large-scale offline world map bundles;
- fleet-management enterprise features;
- insurance/telematics commercial integrations.

## Scope-change procedure

To move a post-MVP item into MVP:

1. explain user value;
2. estimate engineering and test burden;
3. identify new dependencies/costs/privacy risk;
4. update this file;
5. update roadmap/active plan;
6. create an ADR if architecture changes.

An agent must not make this decision unilaterally.
