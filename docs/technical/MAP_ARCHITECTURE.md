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

## 6. Cache

Cache size must be visible/clearable. Do not let map cache silently become hundreds of MB without controls.
