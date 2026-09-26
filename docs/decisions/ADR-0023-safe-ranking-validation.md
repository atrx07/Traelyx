# ADR-0023 — Local analysis and consented safe ranking evidence

Date: 2026-09-26

Status: Accepted and deployed for M6.6; final CI pending.

## Context

Recorded trips have durable raw chunks but no production scoring invocation.
Owner-writable compact cloud summaries are intentionally insufficient for rank
admission. The maintainer approved completing these prerequisites within M6.6.

## Decision

Run existing native version-1 pipelines only on explicit foreground local
analysis of completed trips. Require the user to identify the recorded phone
mount direction; never infer phone-top-forward. Compare stationary calibration
from the first and last non-overlapping 30-second windows. Missing, degraded,
or changed orientation remains limited/unavailable. Version this orchestration
independently. It does not change the scoring thresholds or pretend to detect
yaw-only phone rotation. Store the original audit and events atomically in
existing local tables. Never overwrite a previous score. Analysis failure or
process loss leaves recording and finalization intact and can be retried.

The initial foreground reader is bounded to 32 MiB, one million raw samples,
720,000 analysis frames, 20,000 chunks and 10,000 accepted events. Larger trips
remain recorded/replayable/exportable but cannot use this reader. No recorder
sampling, permissions, wake locks or background scheduling changes.

Ranking version 1 is an experimental, friends-only comparison. Separately
consent to share username/display name and aggregate results with accepted
friends, and to store a minimized private validation dossier. Explicitly choose
the trip's broad vehicle class from the account's saved vehicle classes; unknown
classes are ineligible. Keep car, motorcycle and other comparisons separate.
Each comparison history uses one class until withdrawn. The dossier
contains version identifiers, opaque trip ID/digest, aggregate duration and
quality evidence, dimension evidence durations and ordered event categories
with bounded severity/confidence weights. It excludes raw streams, coordinates,
exact dates, device identifiers, vehicle labels, speed and physical G values.
Existing summary sync consent does not cover this submission.

The server validates the exact schema/versions, evidence coverage, integrity
exclusions and complete score state, then independently derives four dimension
scores from events using scoring v1. No submitted score or rank is authoritative.
Admission additionally requires at least 60 seconds moving evidence and full
four-dimension evidence. Deduplicate immutable submissions, bind them to the
authenticated expected account and enforce quotas. Direct client table access
is forbidden. Withdrawal removes that owner's ranking evidence and projection.

After ten accepted submissions, compare smoothness over the latest five,
consistency as 100 minus their mean absolute deviation, and improvement as
their mean minus the preceding five's mean. Use server acceptance order, not
an invented trip chronology. These are ranking aggregates, not changes to trip
scoring v1 or Drive DNA consistency. No driving-volume, speed or G rewards.
Friend removal/blocking immediately hides the projection. Private profiles do
not become public; names are separately consented snapshots.

## Limits

Server validation checks supplied evidence and arithmetic; it cannot establish
physical truth, driver identity or authenticity on a compromised device. Local
hashes are deduplication evidence, not attestation. Self-selected submissions
and submission order limit comparison. The scoring baseline is synthetic-fixture
reviewed, not population calibrated. UI must describe these limits and never
label ranks as proof of safe driving. A paid attestation dependency is not added.
