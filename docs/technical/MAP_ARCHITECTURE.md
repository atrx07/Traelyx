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

### 4.1 M5.5 synchronized manual clock

M5.5 introduces one deterministic application-owned manual clock over existing recorded duration, verified M5.4 route-point offsets, and allowlisted persisted event ranges. The same selected time drives the visible labels, scrub control, route marker, route/event evidence cursor, active-event state, and event-to-time seeking. There is no timer, autoplay, speed control, camera/path animation, or new native replay-telemetry bridge in this step.

Marker interpolation is valid only between adjacent points in the same governed route segment. A selected time inside a GNSS gap has no verified marker, and longitude interpolation follows the shortest path across the antimeridian. Route and event layers degrade independently: valid event timing remains usable without route geometry, while route replay remains usable without persisted events. When recorded duration or route extent establishes the independent clock boundary, contradictory events outside it are excluded rather than extending the replay.

The M5.5 evidence graph is intentionally coordinate-free and represents verified route-coverage spans plus persisted event ranges. It is not a substitute for the native-only M3.7 speed, acceleration, yaw, or confidence display channels. Later animation must consume this same clock instead of creating a second time source.

### 4.2 M5.6 deterministic playback and framing

M5.6 extends that same application-owned controller with play, pause, replay, lifecycle pause, and deterministic 0.5×/1×/2× advancement. A presentation ticker supplies elapsed deltas but owns no evidence time: the controller remains the sole replay clock, clamps at the recorded boundary, and stops at the end. Manual scrub and persisted-event selection pause playback before seeking.

The local canvas draws verified completed-path progress over muted future-route context without joining governed segment gaps. Overview fits the full route; follow framing interpolates toward a bounded marker-centered viewport only when a verified marker exists. A time inside a governed gap falls back to the truthful overview and exposes no marker. Active persisted events may pulse from the same selected time, so route position, path progress, evidence cursor, event state, and visual phase cannot drift onto independent clocks.

When system animations are disabled, autonomous playback and event pulsing are disabled while manual seeking and explicit overview/follow framing remain available. M5.6 adds no native bridge, M3.7 telemetry exposure, schema, dependency, provider, or network behavior.

## 5. Privacy

Fetching map tiles can expose approximate viewed areas to tile providers. Document this in privacy behavior and avoid adding analytics trackers.

The M5.4 local-canvas provider fetches no tiles and emits no network request. Precise route geometry remains local and transient: exclude it from logs, diagnostics, analytics, semantics/accessibility labels, cache metadata, and unrelated application state. Accessibility describes only the verified display-point count, segment count, start/end/gap cues, selected replay time, camera mode, playback state/speed, and whether a verified marker or active persisted event exists. Replay evidence semantics may expose only duration, cursor time, route-span count, and persisted-event count; they never expose coordinates, trip identifiers, or raw samples.

## 6. Cache

Cache size must be visible/clearable. Do not let map cache silently become hundreds of MB without controls.

The local-canvas provider has no tile store and therefore reports `0 B`, unavailable. The cache control remains visible and its clear operation is a safe no-op. A future tile provider must implement the same status/clear contract before activation.
