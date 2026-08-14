# Real Drive Test Record — M2.8-2026-08-14-TECNO-REPEAT

**Date:** 2026-08-14
**Build/commit:** `6ba17a0` application tree; installed APK SHA-256 `94eeb9c33a2c62c2aa92d40a4a5cc69d3bcdbadecbb288f6c8efc624054d1181`
**Android device/model:** Tecno LH8n
**Android version:** 14
**Vehicle profile/class:** Motorcycle
**Phone mounting/orientation:** Secured in rider pocket; uncontrolled/body-relative orientation
**Trip ID:** `6021f033-7e04-4652-884b-696c4b0563da`
**Trip duration:** 39m17.136s

## Safety

The maintainer performed a normal commute followed by a more dynamic but self-reported legal test phase. No dangerous maneuver was required or requested. Human timestamps and rider-observed speeds are approximate annotations, not calibrated ground truth.

## Scenario

- screen lock? yes; locked for approximately 99% of the recording, except one mid-ride status check and the final Stop interaction
- app backgrounded? yes; recording continued under the native foreground service while the screen was locked
- network loss? not intentionally induced during this repeat; earlier M2.7 validation covers explicit offline survival
- GNSS loss/tunnel? no sustained loss; expected first-fix acquisition occurred before departure
- phone moved? yes; unplugged, pocketed, carried downstairs, one mid-ride check, and final Stop interaction
- notable naturally occurring events: rough rural surface during departure, dense traffic, a roughly localized speed-breaker impact near T+15m30s, and a more dynamic riding phase after approximately T+30m30s

## Rider annotations

- T+00:00: Traelyx recording started while connected to the laptop.
- T+00:30: Field timing began; phone unplugged and pocketed.
- T+03:12: Reported vehicle movement began.
- T+03:12 to T+30:30: Normal/moderate commute, rider-observed speeds usually 40–50 km/h with traffic-related reductions.
- Approximately T+15:30: Roughly localized hard speed-breaker impact.
- T+30:30 to T+37:50: More dynamic acceleration and maneuvering, with rider-observed brief peaks near 80 km/h.
- T+37:50: Reported ride end.

All annotations above are approximate. GNSS speed indicates vehicle-like movement continued until approximately T+39m05s, about 75 seconds beyond the annotated end. This is recorded as an annotation offset, not a recorder-integrity failure.

## Recorder health

- archive duration/chunks: 2,357.136108808s across 3,689 ordered chunks
- GNSS sample count/rate: 2,322 fixes at approximately 1 Hz after acquisition
- accelerometer sample count/rate: 469,953 samples, approximately 199.4 samples/s
- gyroscope sample count/rate: 469,942 samples, approximately 199.4 samples/s
- chunk coverage: maximum gap 9.954497ms
- GNSS coverage: first fix at T+35.230730434s; maximum later adjacent gap 1.312s; trailing coverage 0.595s
- accelerometer coverage: starts and ends at trip bounds; maximum adjacent gap 14.931245ms
- gyroscope coverage: 79.630811ms leading interval, 4.976616ms trailing interval, and maximum adjacent gap 14.931245ms
- dropped samples: no unexplained discontinuity indicated by ordered archive inspection; the archive cannot prove that Android delivered every possible hardware event
- service restarts: none observed or reported; recovery was not required
- chunk corruption: zero; all archive entries, checksums, sequence bounds, counts, and decoded samples verified
- finalization/indexing: completed normally; return inspection found no active service, active state, or pending finalization
- battery start/end: not measured for this repeat; the earlier diagnostic attempt's coarse 40% to 38% observation remains non-controlled evidence only

## Sensor quality

- All accelerometer samples preserved Android accuracy status `0` / `SENSOR_STATUS_UNRELIABLE` and their original device-frame values without compensation, filtering, or counter-bias.
- All gyroscope samples preserved accuracy status `3` with no quality flags.
- Accelerometer and gyroscope samples were ordered, finite, continuous, and numerically plausible for this uncontrolled pocket-carried fixture.
- The Tecno's independently reproduced roughly +0.04 g positive Z-axis bias remains a known fixture-quality limitation for later M3 calibration/confidence work, not an M2.8 integrity failure.

## Aggregate telemetry preview

These are provisional GNSS-derived diagnostics, not calibrated vehicle-frame channels, event detections, or production scores:

- approximate GNSS-integrated distance: 22.4 km
- detected vehicle interval: approximately T+3m30.5s to T+39m04.5s
- average speed across the detected vehicle interval, including traffic: 37.7 km/h
- moving average with GNSS speed at least 7.2 km/h: 38.9 km/h
- maximum GNSS speed: 79.4 km/h at approximately T+36m33.5s; supported by a 13-sample run at or above 70 km/h rather than a single-sample spike
- normal annotated phase: median 38.9 km/h, 95th percentile 45.3 km/h, maximum 55.9 km/h
- dynamic annotated phase: median 45.4 km/h, 95th percentile 68.6 km/h, maximum 79.4 km/h
- scalar speed-change proxy: mean absolute change rose from 0.44 m/s² in the normal phase to 0.71 m/s² in the dynamic phase; the 95th percentile rose from 1.14 to 1.71 m/s²
- turn-load proxy: 95th-percentile GNSS course/speed-derived lateral activity rose from 1.21 to 1.72 m/s², approximately 42% higher in the dynamic phase and partly attributable to its higher speed
- the broad speed-breaker annotation window contains elevated accelerometer/gyroscope activity around T+15m09s to T+15m30s, but it is not uniquely the trip's strongest disturbance and is not labeled as a confirmed event

No cornering, acceleration-consistency, safety, or Drive DNA score is assigned. Auditable filtering, frame transformation, derived channels, events, and scoring begin in later authorized milestones.

## False positives/negatives

- No event engine exists in M2, so no production event classification was evaluated.
- The rider's claim that 65–70 km/h was common across the entire dynamic interval is not fully supported as a duration-wide statement: approximately 9.6% of its GNSS fixes were at least 65 km/h. Multiple sustained high-speed runs and the brief near-80 km/h peak are supported.
- The approximate speed-breaker window shows a meaningful local disturbance, but stronger disturbances occurred elsewhere and pocket/body motion prevents a vehicle-frame attribution.

## Fixture export

- fixture filename: `traelyx-6021f033-7e04-4652-884b-696c4b0563da.tripdebug`
- archive size: 19,960,737 bytes
- SHA-256: `9c955fa151f1aad9956404353aad093a12ea3c69573d15fbac336522db6f09ed`
- native/host verification: exact hash match and independent strict inspection passed
- precise location removed/retained and why: the `precise_private` archive remains only in the maintainer-controlled phone export and app-private evidence for later authorized local processing; it is excluded from Git, logs, and this record. The temporary host analysis copy was removed after verification.
- metadata anonymized: this committed record contains aggregate evidence only; the private archive itself is intentionally not anonymized and contains the original precise route

## Acceptance

M2.8 passes. Positive GNSS readiness preceded departure; locked/background recording covered essentially the full trip; GNSS and both raw IMU channels are synchronized, ordered, finite, and continuous without an unexplained catastrophic gap; Stop finalized and indexed normally; and the exported archive verified independently with exact device/host hash equality. The known Tecno accelerometer status-0/Z-bias limitation remained truthful and unchanged. No mounted-orientation, vehicle-frame, event, or scoring validity is claimed.

## Follow-up

- Preserve this exact private fixture locally for authorized M3 decoder/resampler, calibration/confidence, and regression work.
- Do not introduce Tecno-specific counter-bias or modify M2 raw telemetry semantics.
- M3 remains behind the explicit user-authorization gate.
