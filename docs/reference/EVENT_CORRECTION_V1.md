# Event correction and contribution v1 — M7.9

Local user reports are annotations, not rewritten detections, scores, integrity,
ranking eligibility or crash/Guardian state. No model learns automatically.
Only known finalized trips and rules-only detector-v1 canonical events can be reviewed.
Unknown/non-null model lineage is outside this version's correction contract.
No prompts appear in drive mode. A user explicitly opens post-drive review and
confirms they are parked; active/error/unknown recorder state blocks actions.
Foreground confirmation resets when leaving the app. This is a recorder/UI guard,
not proof of physical driving state or real-device reliability.

## Local authority

Drift schema 4 adds `trip_event_corrections`, with a cascading trip reference,
event ID and exact serialized source snapshot as its composite key. The source
snapshot includes persisted event fields and telemetry schema, so changed
evidence cannot silently inherit a correction. No event FK: replaced detections
do not erase old reports or silently attach them to new evidence. Reads identify
stale notes; only exact current-source matches may be exported. User removal or
whole-trip deletion erases notes; raw-only retention does not.

Choices: `correct`, `not_this_event`, `road_impact`, `device_moved`, `unsure`.
They are unverified self-reports with explicit provenance, not probabilities or
verified ground truth. Keep local creation/update timestamps, revision and optional
consent-version/time. Cap notes at128 per trip. Reject stale revisions, malformed
storage and unsupported snapshots. Wall-clock creation/update metadata may move
backward; revisions order edits, so a clock adjustment cannot prevent withdrawal.
Editing defaults to no contribution permission
unless the user chooses it again. Consent version1 means permission to include
that report in a detection-research export, not account/signup consent.

## Manual contribution

No network endpoint, outbox or automatic upload. A separate preview describes
exact included notes and exclusions, then an explicit action opens Android's
document picker. Serialize note edits/revocations/removal/export within the app
while an export is pending. Recheck source/consent revisions before opening the
picker and again through a one-use native-to-Dart authorization callback after
picker return, before writing. The callback compares the exact reviewed source,
revision and permission, including changes made by another database writer.
The internal request token never enters the saved JSON. Missing, mismatched,
failed or timed-out (5 seconds) authorization prevents the write. Cancel/failure/activity destruction never reports success; do not retain
a temporary private file. Recheck recorder idle at picker return. Already saved
copies are outside the app and cannot be withdrawn by toggling local permission.

Strict JSON format (only these fields):

```json
{
  "format": "traelyx_event_corrections",
  "formatVersion": 1,
  "consentVersion": 1,
  "consentPurpose": "detection_research",
  "consentDeclared": true,
  "labelProvenance": "user_report_unverified",
  "trainingUse": "quarantine_only",
  "containsPreciseLocation": false,
  "containsRawTelemetry": false,
  "labels": [{"detectedEvent": "EVT_BRAKE_STRONG", "reportedLabel": "unsure", "eventEngineVersion": 1, "telemetrySchemaVersion": 1}]
}
```

Use1–128 entries and at most64KiB. Allow only the ten canonical event-v1 IDs and
the five report choices. Unknown/extra fields, identifiers, coordinates, times,
measurements, free text, probabilities, unsupported versions and undeclared
consent are rejected in Dart/native/receiver validation. No local trip/event ID,
source snapshot, consent time, contributor/device identity or absolute/relative
trip position is exported. No severity/confidence percentage is fabricated.

## Receiver / dataset governance

`python -m ml.contributions --source <reviewed-file> --expected-sha256 <digest>
--accept-declared-consent` explicitly acknowledges that consent is a self-reported
declaration, not authenticated proof. Strictly validate before writing to ignored
`ml/data/private/contributions/<sha256>/`. Preserve source hash/version, declared
consent/provenance, categorical reports and limitations; refuse overwrite/links.
Do not log source contents/paths or read private recordings automatically.

Training use stays blocked: no verified labels, time-aligned features or driver/
trip grouping are supplied by this deliberately minimized package. Consent is
necessary but not sufficient. Further use requires governed evidence, appropriate
group splits, provenance/consent review and a separately versioned dataset.
No existing experiment, historical result or production model is changed.
