# Future ordinary-trip diagnostic — Tecno and Redmi v1

## When to read

Use when the maintainer is ready for a normal journey and later private analysis.
No trip is needed now. One phone is sufficient if using both is impractical.
This is a diagnostic recording, not a frozen training or acceptance experiment.
The [collection protocol](EVENTNET_EVIDENCE_COLLECTION_V1.md) remains authoritative
for independent truth, consent, split custody and eventual model evaluation.

## Purpose and limits

Check actual record/save/export, GNSS acquisition/coverage, motion accuracy/flags,
channel gaps and observed background behavior. Compare the phones' diagnostics
when both are available. The Redmi's earlier stationary export had reported
accuracy 3 and no GNSS fixes; this does not prove field calibration. Keep the
Tecno's known sensor concerns and recorded unreliable status intact. Apply no
offset, gravity/frame correction, quality override or inferred event labels.

Two phones in one vehicle remain one driver/journey. Neither is calibrated ground
truth for the other. Their boot clocks are unrelated; do not subtract timestamps,
align by wall clock alone, or claim agreement proves timing/strength. A quiet
segment is not automatically a normal-class label. A useful diagnostic may still
be inadmissible for model training/evaluation. Keep this qualification-exposed
journey out of future locked evaluation; do not later call it an untouched test.

## Parked preparation

1. Use the ordinary Traelyx main app, with production inference disabled. Before
   the future test, record each installed app version/build provenance and phone
   model/Android version privately. Request a reviewed APK then if needed; no
   new installation is required by this document. Preserve installed data if a
   signature conflict occurs; never uninstall/clear data to make the test work.
2. Check free storage and battery. Note each power/charging state and intended
   screen state. Leave Guardian and optional cloud/provider requests inactive;
   local mode needs no account, MIUI account or ADB. Do not revoke existing account
   state or change settings just to run this diagnostic.
3. Secure each available phone separately in a stable mount that does not obstruct
   the driver or controls. Note placement and orientation; a parked photograph or
   sketch is optional and stays private. Do not leave a phone loose or handheld.
   If two safe mounts are unavailable, use one phone. No new equipment purchase,
   camera, screen stream or deliberate synchronization gesture is required.
4. At a safe parked location with an appropriate sky view, enable the normal
   location permissions and inspect recorder readiness. A fixed GPS wait does not
   establish readiness. If fixes remain unavailable, note that result and proceed
   only as a diagnostic if ordinary recording is available; never override it.
5. Start each recording while parked. Leave the phones still for roughly 30–60
   seconds before normal travel. This is useful setup context, not a calibration
   pass threshold. Starting at different times is acceptable and must be noted.

## Ordinary journey and finish

- Use an already planned normal journey; roughly 15–30 minutes is convenient if
  available, not a required duration or acceptance threshold. Shorter/failed files
  are useful evidence. Do not extend a journey just to fill a dataset.
- Drive normally and obey road rules. Do not stage hard braking, acceleration,
  cornering, impacts, GNSS loss, network loss or process termination. No driver
  interaction with either phone while moving. A passenger may make brief private
  notes if available; recollections remain unverified observations, not labels.
- Let the phones follow their intended normal screen/background state. Avoid
  changing mounts or toggling settings mid-journey. If an interruption happens,
  preserve it and report what was observed without assuming its cause.
- Once safely parked at the destination, leave the phones still for roughly
  30–60 seconds if convenient, then end/save through the normal UI. Verify idle
  state and that the saved trip is visible before exporting. Do not restart a
  failed recorder or delete evidence solely to obtain a clean result.
- Note each battery/power state, elapsed duration, visible GPS/motion warnings,
  interruptions and save/export result. Battery deltas are observations; they
  do not establish controlled battery drain or cross-phone efficiency.

## Export and private handoff

Export **each** saved trip through Local tools → Export private drive fixture →
Export private `.tripdebug`. Preserve the original bytes. Use USB/MTP or an
explicitly chosen private transfer; never commit or publicly post an export.
Exports may contain precise routes, wall times and raw motion even if a route
is unavailable on screen. Android 10 manual installation/export needs no ADB.

On this computer use ignored `.dart_tool/m7-field-trip/incoming/tecno/` and
`incoming/redmi/`. Keep a private note with phone/build, mount, power/screen state,
which files belong to the same journey, stationary boundaries if known, warnings,
failures and approximate overlap. Say unknown rather than inventing times.
Do not put account/device identifiers, home/work addresses or raw notes in Git.
Return the available exports and notes; a missing second file is not a failure
of the first. Do not share API keys. No camera footage is required for this test.

The host reviewer hashes each original and uses the pinned aggregate inspector:

```powershell
$tripFile = 'C:\path\to\private-export.tripdebug'
$tripDigest = (Get-FileHash -LiteralPath $tripFile -Algorithm SHA256).Hash.ToLowerInvariant()
python -m tool.inspect_field_recording $tripFile --expected-sha256 $tripDigest
```

Use the repository's existing Python environment. The checksum binds the inspected
bytes, not installed-build provenance or consent. The inspector emits aggregate
quality only, reads one unbuffered descriptor, verifies its hash before/after
parsing and never extracts, repairs, uploads or trains. Raw path/hash stay local.
It has no cross-device alignment or event-detection comparator. A parse failure
preserves the export; investigate privately instead of editing the archive.

## Review and acceptance decisions

For each file report verified integrity, channel counts/coverage gaps, IMU status
and flagged-sample distributions, mock GNSS count, missing evidence and observed
record/save/export outcome. Review the phones separately before comparing their
aggregates. Inspect unknown statuses as unknown; do not silently map them to good.
The host report's time span covers archived samples, not necessarily UI duration.

These can establish a bounded field diagnostic and expose next defects. They do
not establish calibration, independent maneuver/severity truth, false severe
events/hour, classifier accuracy, held-out drivers, sustained battery efficiency,
Guardian acceptance or formal M7 completion. Training needs separate consent,
source/feature admission and independent annotation. A new versioned candidate
must use justified frozen metrics/splits and pass quality, parity, calibration,
efficiency and runtime/integration gates. Preserve the rejected v1 artifact and
all earlier results. See the [current handoff ledger](M7_HANDOFF_V1.md).
