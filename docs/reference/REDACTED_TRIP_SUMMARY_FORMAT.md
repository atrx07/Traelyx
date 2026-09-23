# Redacted trip summary format version 1

## Purpose and privacy class

`traelyx.redacted_trip_summary` is a user-directed local JSON export of bounded, non-route trip outcomes. Format version 1 has privacy class `redacted_summary`. It is not an anonymity guarantee, a public/community fixture, or permission to upload or publish data.

It always declares:

- `format: traelyx.redacted_trip_summary`;
- `format_version: 1`;
- `privacy_class: redacted_summary`;
- `contains_precise_location: false`;
- `contains_raw_telemetry: false`.

## Allowed payload

The remaining keys are fixed and deterministic:

- `duration_millis`: non-negative integer or `null`;
- `distance_meters`: non-negative finite number rounded to three decimal places or `null`;
- `completion_state`, `recovery_state`, `integrity_state`: one of `verified`, `limited`, `review_required`, `unavailable`, or `not_assessed`;
- `telemetry_schema_version`: positive integer;
- `event_count`: non-negative integer;
- `overall_score`, `score_eligibility`, and `scoring_version`: all present as a complete group or all `null`. Score is finite in `0..100`; eligibility uses the evidence-state allowlist; version uses only letters, digits, `.`, `_`, or `-` and is at most 64 characters.

Unknown or partial inputs fail closed. Android encodes UTF-8 with stable key order and writes only through an explicit system document destination.

## Deliberate exclusions

Version 1 contains no trip/account/device/vehicle identifier, owner namespace, wall-clock date/time, coordinate, route geometry, raw GNSS/IMU sample, chunk/storage reference, checksum, provider metadata, commentary text, or secret. It performs no network request and does not mutate the authoritative trip.

Precise diagnosis or replay evidence belongs only in the separately documented version-1 `.tripdebug` archive, whose privacy class is `precise_private`.
