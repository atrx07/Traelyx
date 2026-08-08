# Traelyx — Architecture

## When to read

Read the relevant sections when a change crosses boundaries between UI, native tracking, telemetry processing, storage, cloud, ML, or providers. Do not ingest this whole file for a tiny isolated widget change.

## 1. Architectural style

Traelyx is local-first, event-driven, auditable, modular, and provider-abstracted.

High-level flow:

```text
Android sensors/GNSS
        │
        ▼
Native Kotlin acquisition service
        │
        ▼
Crash-safe local buffering
        │
        ▼
Local telemetry storage
        │
        ▼
Dart telemetry pipeline
(filtering, alignment, frames, confidence)
        │
        ├──────────────► deterministic event evidence
        │
        ├──────────────► on-device ML evidence
        │
        └──────────────► integrity evidence
                          │
                          ▼
                 Explicit versioned scoring
                          │
                   ┌──────┴──────┐
                   ▼             ▼
              Drive DNA      Commentary
                   │             │
                   └──────┬──────┘
                          ▼
                   Flutter presentation
                          │
                          ▼
             Optional sanitized cloud sync
```

## 2. Primary technologies

### Application / UI
- Flutter + Dart.
- Riverpod for application state and asynchronous/reactive state flows.
- `go_router` for navigation/deep links.
- Programmatic Flutter animation for replay and interaction where practical.

### Native Android
- Kotlin.
- Foreground service for durable trip acquisition.
- Android location/GNSS APIs as appropriate.
- `SensorManager` for accelerometer/gyroscope and related sensor access.
- Platform channel or a deliberately versioned native bridge to Flutter.

### Local persistence
- Drift over SQLite for structured local data.
- Chunked/binary or compact structured storage for high-frequency telemetry rather than one expensive relational row per raw sensor sample where profiling shows that approach is inferior.
- Explicit schema migrations and upgrade tests.

### Backend
- Supabase free tier for optional accounts, PostgreSQL, Row Level Security, social metadata, leaderboards, Guardian relationships, and compact cloud summaries.
- Raw high-frequency telemetry is not uploaded by default.

### Maps
- Provider-abstracted mapping layer.
- Prefer open MapLibre / `flutter_map` ecosystem components.
- Do not assume public OpenStreetMap tile infrastructure is unlimited production hosting.
- No mandatory paid tile API.

### ML
- Train primarily in Python/PyTorch.
- Deploy small, quantized on-device temporal models where useful.
- Prefer an edge runtime that supports Android and is compatible with the chosen exported model format; ExecuTorch is a leading candidate, but runtime choice is replaceable and must be benchmarked.
- ML evidence must remain versioned and auditable.

### CI/CD
- GitHub Actions for repeatable analysis/tests/build artifacts where safe.
- Final release signing initially occurs on the maintainer's trusted machine.
- GitHub Releases for distribution.

## 3. Responsibility boundaries

### Flutter owns
- screens and interaction;
- app navigation;
- visual design tokens;
- account/profile flows;
- trip list and trip detail UI;
- replay presentation;
- local analytics presentation;
- cloud sync orchestration at application level;
- provider settings and commentary UX.

### Kotlin native layer owns
- foreground-service lifecycle;
- GNSS/location acquisition;
- high-rate IMU acquisition;
- authoritative sensor timestamps;
- buffering during Flutter/UI absence;
- resilient acquisition when screen is locked;
- platform-specific battery/background behavior;
- reporting acquisition health.

### Dart telemetry engine owns
- decoding local acquisition data;
- timestamp alignment;
- transformations and coordinate correction;
- filters and smoothing;
- derived physical quantities;
- confidence propagation;
- deterministic event evidence;
- scoring orchestration;
- Drive DNA calculations;
- replay-ready reduced/derived channels.

### ML layer owns
- probabilistic event/context/anomaly/style evidence;
- model manifests/versioning;
- inference output confidence/probabilities;
- never the sole final safety or scoring decision.

### Cloud owns only what needs cloud
- auth identity;
- profile/social metadata;
- compact trip summaries selected for sync;
- ranking entries;
- Guardian relationship/notification routing metadata;
- sanitized, user-authorized cloud commentary inputs if chosen.

## 4. Local-first data authority

The local device should remain capable of:

- starting/stopping a drive;
- recording telemetry;
- calculating baseline trip summary;
- event detection;
- scoring/Drive DNA;
- trip history;
- replay;
- procedural commentary;
- export and deletion.

Online-only features may include:

- account sync;
- global/friend leaderboards;
- friends/social graph;
- Partner/Guardian connectivity;
- cloud-generated commentary using user-owned credentials;
- optional cloud backup if implemented later.

## 5. Data classes

Treat data according to sensitivity:

1. **Secrets** — API keys, signing credentials. Never sync unintentionally.
2. **Precise location history** — private by default; never exposed by leaderboard.
3. **Raw telemetry** — potentially identifying and storage-heavy; local by default.
4. **Derived trip analytics** — sync only when user opts into cloud features.
5. **Public profile/ranking fields** — explicitly designed to be public.
6. **Anonymous/consented ML contribution segments** — stripped of precise location and account identity where possible.

See `docs/product/PRIVACY_MODEL.md`.

## 6. Provider abstraction

All optional cloud commentary providers implement a common conceptual interface:

```text
CommentaryProvider
  listModels()
  validateCredential()
  generateCommentary(sanitizedEventDossier, settings)
```

The application should not hardcode a model forever. Providers regularly deprecate and rename models. The user may choose automatic recommendation, a discovered model, or an advanced custom model ID/endpoint where supported.

Maps should follow a similar boundary so rendering/provider changes do not leak throughout UI code.

## 7. Versioning requirements

The following must have explicit versions when persisted:

- telemetry schema;
- event taxonomy;
- scoring algorithm;
- Drive DNA feature/schema definition;
- ML model + feature schema;
- commentary event dossier schema;
- database schema/migrations;
- integrity rules where historic audit must be reproducible.

## 8. Failure philosophy

- Recording must fail loudly and diagnostically rather than silently dropping trips.
- Cloud outages must not destroy local functionality.
- Provider failure must fall back to procedural commentary where possible.
- Low sensor confidence must reduce certainty, not manufacture precise judgments.
- A failed ML model should not prevent deterministic baseline analysis.
- Corrupted telemetry should be isolated and preserved for debugging/export where safe rather than causing whole-database failure.

## 9. Expected source shape

A likely repository layout after bootstrap:

```text
app/
  lib/
    core/
      auth/
      database/
      maps/
      networking/
      permissions/
    telemetry/
      models/
      filters/
      fusion/
      events/
      scoring/
      integrity/
      drive_dna/
    features/
      recorder/
      dashboard/
      replay/
      trips/
      vehicles/
      leaderboard/
      guardian/
      profile/
      commentary/
    shared/
android/
ml/
tests/
docs/
```

The exact generated Flutter/Android layout may differ, but responsibility boundaries should remain intact.
