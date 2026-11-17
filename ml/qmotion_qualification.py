"""Offline, pinned Q-Motion metadata audit; no sensor loading or model admission."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
import io
import json
import math
from pathlib import Path, PurePosixPath
import re
import sys

from .qualify_eventnet_sources import InvalidSource, pinned_bytes, require

VERSION = "qmotion-metadata-qualification-v1"
PROFILE = Path(__file__).with_name("qualification") / "qmotion-v1.json"
CLASSES = ("acceleration", "braking", "bump", "curve", "zig-zag")
BUTTONS = {*CLASSES, "collecting-data", "cobblestone", "depression", "hole", "railroad-crossing"}
SCENARIOS = {"0": "intended_baseline", "1": "tire_pressure", "4": "intended_aggressive"}


def read_inputs(root, profile):
    require(type(profile) is dict, "profile_contract")
    require(profile.get("profile_version") == 1 and type(profile.get("profile_version")) is int,
            "profile_version")
    files = profile.get("files")
    require(type(files) is list and 0 < len(files) <= 64, "profile_files")
    root = root.resolve(strict=True)
    result, seen, total = [], set(), 0
    for entry in files:
        require(type(entry) is dict, "profile_entry")
        name, size, digest = entry.get("path"), entry.get("bytes"), entry.get("sha256")
        require(type(name) is str and "\\" not in name and ":" not in name, "profile_path")
        relative = PurePosixPath(name)
        require(not relative.is_absolute() and str(relative) == name and
                not any(part in ("", ".", "..") for part in name.split("/")) and name not in seen,
                "profile_path")
        require(type(size) is int and 0 < size <= 32768 and type(digest) is str and
                re.fullmatch(r"[a-f0-9]{64}", digest), "profile_pin")
        total += size
        require(total <= 200_000, "profile_total")
        target = (root / Path(*relative.parts)).resolve(strict=True)
        require(target.is_relative_to(root), "profile_path")
        require(entry.get("role") in {"document", "guideline", "rotation", "annotation"}, "profile_role")
        result.append((entry, pinned_bytes(target, (size, digest))))
        seen.add(name)
    return result


def guidelines(data, collection_date):
    require(0 < len(data) <= 4096, "guideline_size")
    reader = csv.DictReader(io.StringIO(data.decode("utf-8-sig"), newline=""))
    require(reader.fieldnames == ["Code", "Rosbag", "SMC", "Driver_ID"], "guideline_columns")
    rows = []
    for row in reader:
        require(len(rows) < 100 and None not in row and all(type(v) is str and len(v) <= 128 for v in row.values()),
                "guideline_rows")
        match = re.match(r"AMI_UC([014])_NO([12])-", row["Code"])
        require(match and row["Rosbag"].strip() and row["Driver_ID"].strip(), "guideline_identity")
        rows.append({"key": (collection_date, row["Rosbag"]), "driver": row["Driver_ID"],
                     "smc": row["SMC"], "scenario": SCENARIOS[match[1]], "occupants": int(match[2])})
    require(rows, "empty_guidelines")
    return rows


def intervals(data):
    require(0 < len(data) <= 32768, "annotation_size")
    rows = json.loads(data)
    require(type(rows) is list and 0 < len(rows) <= 1024, "annotation_rows")
    by_button, previous, reverse_pairs = defaultdict(list), None, 0
    for row in rows:
        require(type(row) is dict and set(row) == {"buttonId", "time", "event"}, "annotation_columns")
        button, event, text = row["buttonId"], row["event"], row["time"]
        require(type(button) is str and button in BUTTONS and event in ("start", "stop") and
                type(text) is str and len(text) <= 32, "annotation_value")
        try:
            timestamp = datetime.strptime(text, "%Y-%m-%d %H:%M:%S.%f")
        except ValueError:
            raise InvalidSource("annotation_time") from None
        reverse_pairs += int(previous is not None and timestamp < previous)
        previous = timestamp
        by_button[button].append((timestamp, event))
    pairs = []
    for button, values in by_button.items():
        start = None
        # Preserve explicit source start/stop pairing. Edited annotation bounds
        # can overlap; sorting timestamps before pairing invents duplicate starts.
        for timestamp, event in values:
            if event == "start":
                require(start is None, "annotation_duplicate_start")
                start = timestamp
            else:
                require(start is not None and timestamp > start, "annotation_unmatched_stop")
                pairs.append((button, start, timestamp))
                start = None
        require(start is None, "annotation_unclosed_start")
    collecting = [(start, end) for button, start, end in pairs if button == "collecting-data"]
    require(len(collecting) == 1, "annotation_recording_bounds")
    driving = [(button, start, end) for button, start, end in pairs if button in CLASSES]
    overlapping = sum(a != b and max(s1, s2) < min(e1, e2)
                      for i, (a, s1, e1) in enumerate(driving) for b, s2, e2 in driving[i+1:])
    same_class_overlapping = sum(a == b and max(s1, s2) < min(e1, e2)
                                for i, (a, s1, e1) in enumerate(driving) for b, s2, e2 in driving[i+1:])
    return {"counts": Counter(button for button, _, _ in driving),
            "control_seconds": round((collecting[0][1]-collecting[0][0]).total_seconds(), 6),
            "reverse_pairs": reverse_pairs, "overlapping_class_pairs": overlapping,
            "overlapping_same_class_pairs": same_class_overlapping,
            "events_outside_control_bounds": sum(start < collecting[0][0] or end > collecting[0][1]
                                                  for _, start, end in driving)}


def rotation_summary(data):
    require(0 < len(data) <= 4096, "rotation_size")
    lines = []
    padding_rows = 0
    for line in data.decode("utf-8-sig").splitlines():
        if not line.strip("; "):
            padding_rows += 1
            continue
        require(line.endswith(";;;;"), "rotation_dialect")
        lines.append(line[:-4])  # Explicit release-specific spreadsheet padding.
    reader = csv.DictReader(lines)
    require(reader.fieldnames == ["Date", "Vehicle", "Sensor_source", "Rotation_matrix", "Idle_vector"],
            "rotation_columns")
    errors, determinants, seen = [], [], set()
    for row in reader:
        require(len(errors) < 32 and None not in row and all(type(v) is str for v in row.values()), "rotation_rows")
        require(row["Vehicle"] == "AMI" and row["Sensor_source"] in ("ROS", "SMC"), "rotation_source")
        key = (row["Date"], row["Sensor_source"])
        require(key not in seen, "rotation_duplicate")
        seen.add(key)
        parsed = []
        for column, count in [("Rotation_matrix", 9), ("Idle_vector", 3)]:
            text = row[column]
            require(len(text) <= 256 and text.startswith("[") and text.endswith("]"), "rotation_vector")
            values = [float(x) for x in text[1:-1].split()]
            require(len(values) == count and all(math.isfinite(v) for v in values), "rotation_vector")
            parsed.append(values)
        m = parsed[0]
        errors.append(max(abs(sum(m[3*i+k]*m[3*j+k] for k in range(3))-int(i == j))
                          for i in range(3) for j in range(3)))
        determinants.append(m[0]*(m[4]*m[8]-m[5]*m[7])-m[1]*(m[3]*m[8]-m[5]*m[6])+m[2]*(m[3]*m[7]-m[4]*m[6]))
    require(errors, "empty_rotations")
    return {"rows": len(errors), "ignored_spreadsheet_padding_rows": padding_rows,
            "maximum_gram_matrix_error": round(max(errors), 9),
            "determinant_range": [round(min(determinants), 9), round(max(determinants), 9)],
            "correction_applied": False, "native_frame_equivalence_accepted": False}


def audit_metadata(sessions, annotations):
    require(0 < len(sessions) <= 400 and len(annotations) <= 64, "metadata_bounds")
    keyed = {row["key"]: row for row in sessions}
    require(len(keyed) == len(sessions), "duplicate_session")
    drivers = sorted({row["driver"] for row in sessions})
    groups = {driver: {"group": i+1, "sessions": 0, "annotation_files": 0,
                       "scenario_counts": Counter(), "manual_interval_counts": Counter(),
                       "recording_control_seconds": 0.0} for i, driver in enumerate(drivers)}
    source_groups, totals, seen = defaultdict(set), Counter(), set()
    reverse, overlapping, same_class_overlapping, outside, auxiliary_only = 0, 0, 0, 0, 0
    for row in sessions:
        group = groups[row["driver"]]
        group["sessions"] += 1
        group["scenario_counts"][row["scenario"]] += 1
        if row["smc"]:
            source_groups[row["smc"]].add(row["driver"])
    for key, data in annotations:
        require(key in keyed and key not in seen, "annotation_session_identity")
        seen.add(key)
        summary = intervals(data)
        group = groups[keyed[key]["driver"]]
        group["annotation_files"] += 1
        group["manual_interval_counts"].update(summary["counts"])
        group["recording_control_seconds"] += summary["control_seconds"]
        totals.update(summary["counts"])
        reverse += summary["reverse_pairs"]
        overlapping += summary["overlapping_class_pairs"]
        same_class_overlapping += summary["overlapping_same_class_pairs"]
        outside += summary["events_outside_control_bounds"]
        auxiliary_only += int(not summary["counts"])
    for group in groups.values():
        group["manual_interval_counts"] = {c: group["manual_interval_counts"][c] for c in CLASSES}
        group["missing_manual_classes"] = [c for c in CLASSES if not group["manual_interval_counts"][c]]
        group["recording_control_seconds"] = round(group["recording_control_seconds"], 6)
    return {"sessions": len(sessions), "driver_groups": len(drivers),
            "sessions_missing_smartphone_source": sum(not row["smc"] for row in sessions),
            "smartphone_sources_shared_across_drivers": sum(len(v) > 1 for v in source_groups.values()),
            "annotation_files": len(annotations), "auxiliary_only_annotation_files": auxiliary_only,
            "manual_interval_counts": {c: totals[c] for c in CLASSES}, "groups": list(groups.values()),
            "annotation_array_adjacent_reverse_pairs": reverse,
            "reverse_pair_interpretation": "annotation serialization order, not sensor clock rollback",
            "overlapping_different_manual_class_pairs": overlapping,
            "overlapping_same_manual_class_pairs": same_class_overlapping,
            "manual_events_outside_recording_control_bounds": outside,
            "verified_normal_driving_seconds": None}


def qualify(root):
    profile = json.loads(PROFILE.read_text(encoding="utf-8"))
    inputs = read_inputs(root, profile)
    sessions, annotations, rotations, documents = [], [], [], 0
    for entry, data in inputs:
        role = entry["role"]
        if role == "guideline":
            sessions.extend(guidelines(data, entry["collection_date"]))
        elif role == "annotation":
            annotations.append(((entry["collection_date"], entry["session"]), data))
        elif role == "rotation":
            rotations.append(rotation_summary(data))
        else:
            documents += 1
    summary = audit_metadata(sessions, annotations)
    require(summary["sessions"] == profile["expected_sessions"] and
            summary["driver_groups"] == profile["expected_driver_groups"] and
            summary["annotation_files"] == profile["expected_annotation_files"] and
            len(rotations) == 1 and documents == 4, "release_completeness")
    return {"qualification_version": VERSION, "source": profile["source"], "license": profile["license"],
            "pinned_metadata_files": len(inputs), "metadata_bytes": sum(len(data) for _, data in inputs),
            "grouped_label_coverage": summary, "rotation_metadata": rotations[0],
            "documented_phone_timing": "within_second_reconstructed_sample_times",
            "processed_normal_labels": "assigned_from_session_or_annotation_absence_not_verified_negatives",
            "processed_rule_labels": "not_independent_ground_truth",
            "sensor_streams_loaded": False, "model_training_or_predictions": False,
            "model_feature_contract_accepted": False, "training_admitted": False,
            "production_evaluation_admitted": False, "split_assigned": False,
            "blocking_evidence": ["independent_normal_exposure_missing", "native_preprocessing_equivalence_unverified",
                "source_quality_and_units_adapter_unverified", "approximate_annotation_and_reconstructed_time",
                "class_mapping_and_grouped_protocol_not_frozen", "nc_intended_distribution_not_approved"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = qualify(args.root)
    except (OSError, ValueError, TypeError, KeyError, csv.Error, OverflowError, RecursionError):
        print("Q-Motion qualification failed: invalid or unavailable pinned metadata. No model data admitted.", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
