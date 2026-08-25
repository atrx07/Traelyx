# MAP_ARCHITECTURE.md — Mapping Layer

## When to read

Read for map widgets, route rendering, tile providers, offline/cache behavior, geocoding, or map privacy.

## 1. Principle

Map rendering must be replaceable and must not require a paid service for core use.

Preferred ecosystem candidates: MapLibre and/or `flutter_map`, selected through prototype/benchmarking.

## 2. Map abstraction

Application features should consume project-level concepts:

- show route;
- show current marker;
- select event;
- camera follow/fit bounds;
- scrub marker to time;
- cache policy/status.

Avoid leaking one provider SDK's types throughout domain code.

### 2.1 M5.4 local-canvas baseline

M5.4 activates the abstraction with a dependency-free Flutter canvas provider. It draws verified local route geometry, fits the full route, marks start/end/discontinuities without relying on color, requires no network, and makes no tile request. This route-only view must be described as an **offline route view**, not as a street basemap.

The provider-neutral map-data bridge is `io.github.atrx07.traelyx/map-data/v1`. `loadTripRoute` accepts one selected local trip ID and returns only contract version/state, GNSS-processing version, bounded counts/reduction state, and at most 4,096 display points containing trip offset, latitude/longitude, and a segment-start flag. It must not return trip IDs, chunk paths/checksums, provider names, source wall time, raw quality fields, or device identifiers.

Android lists the complete app-private chunk sequence and streams each chunk through a checksum-verifying GNSS-only decoder off the UI thread. IMU fields are parsed and validated without allocating IMU samples, so route memory scales with GNSS evidence rather than the high-rate motion stream. The reader then applies governed M3.2 GNSS decisions and fails closed for missing sequences, corruption, mixed contracts, contradictory ordering, or an unrepresentable discontinuity count. Low-accuracy/clock/anchor-changing exclusions and governed gaps break the visible path. Flutter validates the exact response shape and keeps accepted coordinates only in the selected result's transient route state.

## 3. Tiles

OpenStreetMap data is open, but public community tile servers are not an unlimited production CDN. Respect tile usage policies and make tile source configurable.

Strategies may include:

- compliant community/development provider;
- self-hosted tiles later;
- user-configurable tile endpoint;
- limited cache;
- offline regions later.

Do not silently introduce a paid mandatory tile API.

## 4. Replay

Route geometry should be drawn from local trip data. The replay clock drives marker position independent of network tile availability; missing tiles should degrade the basemap, not destroy telemetry replay.

## 5. Privacy

Fetching map tiles can expose approximate viewed areas to tile providers. Document this in privacy behavior and avoid adding analytics trackers.

The M5.4 local-canvas provider fetches no tiles and emits no network request. Precise route geometry remains local and transient: exclude it from logs, diagnostics, analytics, semantics/accessibility labels, cache metadata, and unrelated application state. Accessibility describes only the verified display-point count, segment count, and start/end/gap cues.

## 6. Cache

Cache size must be visible/clearable. Do not let map cache silently become hundreds of MB without controls.

The local-canvas provider has no tile store and therefore reports `0 B`, unavailable. The cache control remains visible and its clear operation is a safe no-op. A future tile provider must implement the same status/clear contract before activation.
