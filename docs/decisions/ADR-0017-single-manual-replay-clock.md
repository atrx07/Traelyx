# ADR-0017 — Single manual replay clock

**Status:** Accepted

## Context

M5.5 must synchronize the verified offline route, an evidence graph, and governed persisted event ranges without inventing analysis or introducing autonomous animation. The existing M5.4 map-data boundary already provides bounded route points with trip-relative offsets, while result persistence may contain event start/end offsets. Native M3.7 also defines richer replay display channels, but those channels do not currently cross an application bridge.

Creating separate map, graph, and event cursors would permit visible drift and contradictory active state. Expanding the native bridge during this presentation step would broaden scope and precise-evidence exposure without being necessary for deterministic manual inspection.

## Decision

Use one immutable application replay timeline and one timer-free manual clock. Recorded duration and verified route extent establish the independent clock boundary. Event timing may establish a boundary only when it is the sole valid evidence; events outside an independently established boundary are excluded as contradictory.

Every M5.5 consumer derives from the same selected duration: time labels, scrub semantics, route marker, coordinate-free evidence cursor, active event ranges, and event-to-time seeking. Route-marker interpolation is allowed only between adjacent points in one verified segment and uses the shortest longitude delta across the antimeridian. A governed gap produces no marker.

Route and event layers fail independently. The graph contains only route-coverage spans and persisted event ranges, never coordinates. M3.7 replay channels remain native-only until a separately governed, versioned exposure is justified. M5.5 adds no timer, autoplay, playback speed, camera/path animation, or event pulse.

## Consequences

Positive:

- map, graph, event state, and accessibility values cannot drift onto different clocks;
- manual replay stays deterministic, testable, offline, and schema-neutral;
- gap and antimeridian behavior is explicit and auditable;
- missing route or event evidence degrades only the affected layer;
- later animation can consume the same clock instead of creating another authority.

Negative:

- the M5.5 graph cannot yet show native M3.7 speed, acceleration, yaw, or confidence channels;
- genuine trips without persisted events can validate only route replay on a physical device;
- a later versioned bridge may still be needed for richer replay telemetry.

## Revisit if

A governed application boundary exposes M3.7 replay channels, persistence adds a new authoritative replay extent, or measured animation requirements cannot consume the same clock. Any revision must preserve one selected time, independent layer failure, gap-safe interpolation, coordinate-free semantics, and offline core behavior.
