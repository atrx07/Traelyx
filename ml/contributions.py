"""Explicit label-only contribution receipt. No training, telemetry import or network."""

import argparse
import json
from pathlib import Path
import re
import sys
import tempfile

from . import datasets as ds

EVENTS = {
    "EVT_ACCEL_STRONG", "EVT_ACCEL_ABRUPT_TRANSITION", "EVT_BRAKE_STRONG", "EVT_BRAKE_ABRUPT_TRANSITION",
    "EVT_CORNER_HIGH_LOAD_LEFT", "EVT_CORNER_HIGH_LOAD_RIGHT", "EVT_CORNER_ABRUPT_ENTRY", "EVT_CORNER_ABRUPT_EXIT",
    "EVT_ROAD_IMPACT", "EVT_PHONE_MOVED",
}
CHOICES = {"correct", "not_this_event", "road_impact", "device_moved", "unsure"}
HEADER = dict(format="traelyx_event_corrections", formatVersion=1, consentVersion=1, consentPurpose="detection_research",
              consentDeclared=True, labelProvenance="user_report_unverified", trainingUse="quarantine_only",
              containsPreciseLocation=False, containsRawTelemetry=False)


def _pairs(items):
    value = {}
    for key, item in items:
        ds.require(key not in value, "duplicate contribution field")
        value[key] = item
    return value


def validate(raw):
    ds.require(type(raw) is bytes and 0 < len(raw) <= 65536, "contribution size limit")
    value = json.loads(raw, object_pairs_hook=_pairs)
    ds.require(type(value) is dict and set(value) == set(HEADER)|{"labels"} and
               all(type(value[key]) is type(item) and value[key] == item for key, item in HEADER.items()), "unsupported contribution contract")
    labels = value["labels"]
    ds.require(type(labels) is list and 0 < len(labels) <= 128, "contribution count limit")
    for row in labels:
        ds.require(type(row) is dict and set(row) == {"detectedEvent", "reportedLabel", "eventEngineVersion", "telemetrySchemaVersion"} and
                   type(row["detectedEvent"]) is str and row["detectedEvent"] in EVENTS and
                   type(row["reportedLabel"]) is str and row["reportedLabel"] in CHOICES and
                   type(row["eventEngineVersion"]) is int and row["eventEngineVersion"] == 1 and
                   type(row["telemetrySchemaVersion"]) is int and row["telemetrySchemaVersion"] == 1, "unsupported contribution label")
    return value


def receive(source: Path, digest: str, accept_declared_consent=False):
    ds.require(accept_declared_consent is True, "declared-consent acknowledgment required")
    ds.require(type(digest) is str and re.fullmatch(r"[a-f0-9]{64}", digest), "source digest required")
    with source.open("rb") as stream: raw = stream.read(65537)
    ds.require(ds.sha256(raw) == digest, "source digest mismatch")
    value = validate(raw)
    root = ds.ROOT/"ml/data/private/contributions"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output links denied")
    root.mkdir(parents=True, exist_ok=True)
    target = root/digest
    ds.require(not target.exists() and not target.is_symlink() and not target.is_junction(), "never overwrite contribution receipt")
    manifest = dict(format="traelyx_correction_quarantine_manifest", manifest_version=1, source_format=HEADER["format"], source_format_version=1,
                    source_sha256=digest, source_bytes=len(raw), consent_version=1, consent_purpose="detection_research",
                    consent_evidence="self_reported_declaration_not_authenticated", label_provenance="user_report_unverified",
                    label_count=len(value["labels"]), training_use="blocked", model_training_eligible=False, identity_grouping="unavailable",
                    aligned_features="unavailable", source_quality="unavailable_in_minimized_export", privacy_class="categorical_labels_only",
                    limitations=["User reports are not verified labels or safety truth.",
                                 "No driver/trip grouping or aligned telemetry features are supplied; do not invent them or split rows for training.",
                                 "Further use needs consent/provenance review and a separately governed/versioned dataset."])
    with tempfile.TemporaryDirectory(prefix=".correction-receipt-", dir=root) as temporary:
        staging = Path(temporary)/"receipt"
        staging.mkdir()
        (staging/"contribution.json").write_bytes(raw)
        (staging/"manifest.json").write_bytes(ds.canonical_json(manifest))
        ds.require(not target.exists(), "contribution receipt appeared concurrently")
        staging.rename(target)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--accept-declared-consent", action="store_true")
    args = parser.parse_args()
    try: report = receive(args.source, args.expected_sha256, args.accept_declared_consent)
    except (OSError, ValueError, RuntimeError) as failure:
        print(f"Contribution receipt failed ({type(failure).__name__}); no training data published.", file=sys.stderr)
        raise SystemExit(2)
    count = report['label_count']
    print(f"Quarantined {count} unverified {'report' if count == 1 else 'reports'}; training remains blocked.")
