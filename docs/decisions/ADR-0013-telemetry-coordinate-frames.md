# ADR-0013 — Right-handed ENU and forward-left-up telemetry frames

**Status:** Accepted

## Context

M3.4 must transform Android device-frame IMU evidence without confusing tilt, phone yaw, travel course, and vehicle heading. Android fixes raw sensor axes to the device's natural orientation: +X points right, +Y points toward the top, and +Z points out of the screen; display rotation does not swap those axes. Android location bearing is horizontal travel direction and is unrelated to device orientation. A stationary accelerometer gravity vector therefore resolves tilt but cannot reveal geographic or vehicle yaw.

Primary platform references are the official [Android sensor coordinate-system documentation](https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview#sensors-coords) and [`Location.getBearing`](https://developer.android.com/reference/android/location/Location#getBearing()).

## Decision

Traelyx uses right-handed version-1 frames:

- device: unchanged Android +X right, +Y device-top, +Z screen-out;
- navigation/world: ENU, +X east, +Y north, +Z up;
- vehicle: +X forward, +Y left, +Z up.

Transform matrices are orthonormal, positive-determinant, row-major source-to-target maps. M3.3's measured stationary gravity direction resolves only a leveled right/forward/up frame with explicitly unobservable geographic yaw. A device-to-vehicle transform requires an explicit device-frame forward mount hint; Traelyx does not silently assume that the phone top points forward. A vehicle-to-ENU transform additionally requires an M3.2-usable GNSS bearing with source speed at least 3 m/s, bearing accuracy at most 30 degrees, and age at most 2 seconds. Mock-location state degrades the result but remains evidence rather than a sole integrity verdict.

A later non-overlapping stationary calibration whose gravity direction differs by more than 10 degrees invalidates the prior tilt assumption. An insufficient or unevaluated comparison degrades mount quality. Rotation only about the gravity axis remains explicitly unobservable without independent orientation evidence. M3.4 performs coordinate transformation only: it does not remove gravity, filter signals, or create the M3.5 derived channels.

## Consequences

Positive:

- longitudinal/lateral/vertical signs have one auditable right-handed convention;
- tilt, mount alignment, travel course, and geographic yaw cannot be silently conflated;
- unavailable, stale, degraded, mock, invalidated, and unobservable states propagate explicitly;
- raw vectors, timestamps, status, and flags remain unchanged under native authority.

Negative:

- vehicle/world channels remain unavailable without explicit mount alignment and usable moving GNSS course;
- stationary evidence cannot detect phone rotation solely around the gravity axis;
- phones moved after calibration require new trustworthy evidence before high-confidence transforms resume.

## Revisit if

A governed rotation-vector/magnetometer source is added, a validated automatic mount-alignment procedure replaces the explicit forward hint, or multi-device fixture evidence justifies changing the versioned thresholds or conventions.
