"""Offline qualification of two checksum-pinned public EventNet source releases.

Emits reviewed schema/label/timing aggregates only. Never trains, predicts,
downloads, exports raw data or admits a source to a model split.
"""

from __future__ import annotations

import argparse
from collections import Counter
import csv
from decimal import Decimal, InvalidOperation
import hashlib
import io
import json
import math
from pathlib import Path
import re
import sqlite3
import sys

VERSION = "eventnet-public-qualification-v1"
MAX_ROWS = 200_000
HARVARD = (11_571_200, "bb0c592c1899d1a74c9ff100c75cbb5ffb50033a70284276cf51139ec81c76d9")
ZENODO = {
    "Labeled_events_1.csv": (4616, "07f3adec8af07278ce1c948be4ea2f94058d2972419791cd15237aa1f0a6c120"),
    "Labeled_events_2.csv": (2444, "c571d85471dc23fcbef51c301e322cc03ac2ada3894c5f65af3986fb80c1a6b7"),
    "Labeled_events_3.csv": (4022, "c593f405303849e9d0e68616e128bd6f06be5bee37e9682e2b0d718852fef0c4"),
}
LABELS = {
    "0": "non-aggressive event", "1": "aggressive right-turn",
    "2": "aggressive left-turn", "3": "aggressive lane change to the right",
    "4": "aggressive braking", "5": "aggressive acceleration",
    "6": "aggressive lane change to the left",
}
HARVARD_LABELS = {
    "Accelerate", "Aggressive Accelerate", "Aggressive Brake", "Aggressive Left",
    "Aggressive Right", "Brake", "Idling", "Left", "Right",
}
COLUMNS = ["TIME", "ACCEL_X", "ACCEL_Y", "ACCEL_Z", "GYRO_X", "GYRO_Y", "GYRO_Z", "CURRENT_SPEED", "ACTIVITY"]


class InvalidSource(ValueError):
    pass


def require(value, reason):
    if not value:
        raise InvalidSource(reason)


def pinned_bytes(path: Path, pin: tuple[int, str]):
    size, digest = pin
    # Inspect this immutable byte snapshot after verification, not a reopened path.
    require(path.stat().st_size == size, "source_size")
    with path.open("rb") as stream:
        data = stream.read(size+1)
    require(len(data) == size and hashlib.sha256(data).hexdigest() == digest, "source_digest")
    return data


def decimal(value):
    require(type(value) is str and len(value) <= 32, "numeric_text")
    try:
        result = Decimal(value)
    except InvalidOperation:
        raise InvalidSource("numeric_text") from None
    require(result.is_finite() and abs(result) <= 86_400, "numeric_range")
    return result


def label_summary(data: bytes):
    require(0 < len(data) <= 16_384, "label_size")
    reader = csv.DictReader(io.StringIO(data.decode("utf-8-sig"), newline=""))
    require(reader.fieldnames == ["start", "end", "event", "target", "timesync", "sample"], "label_columns")
    counts, previous_end, previous_sample, sync = Counter(), Decimal(0), -1, None
    normal_seconds = Decimal(0)
    durations = []
    aliases = 0
    for index, row in enumerate(reader):
        require(index < 1000 and None not in row and all(v is not None for v in row.values()), "label_rows")
        start, end, offset = (decimal(row[k]) for k in ["start", "end", "timesync"])
        require(0 <= previous_end <= start < end and offset >= 0, "label_interval")
        require(re.fullmatch(r"[0-9]{1,6}", row["sample"]) and int(row["sample"]) == previous_sample+1, "label_sequence")
        require(sync is None or sync == offset, "label_sync")
        target, text = row["target"], row["event"].strip()
        # Explicit release-specific spelling aliases, not inferred semantic labels.
        if text == "evento n\u00e3o agressivo":
            text = "non-aggressive event"
        require(target in LABELS and text == LABELS[target], "label_identity")
        aliases += int(row["event"] != text)
        counts[LABELS[target]] += 1
        duration = end-start
        if target == "0":
            normal_seconds += duration
        durations.append(duration)
        previous_end, previous_sample, sync = end, int(row["sample"]), offset
    require(durations, "empty_labels")
    return {"intervals": len(durations), "class_counts": dict(sorted(counts.items())),
            "annotated_nonaggressive_seconds": float(normal_seconds),
            "minimum_interval_seconds": float(min(durations)), "explicit_spelling_aliases": aliases}


def harvard_summary(data: bytes):
    require(0 < len(data) <= 16*1024*1024, "database_size")
    # Deserialize only verified/bounded input into memory. No source DB is opened
    # for writing and no WAL, sidecar, extension or source SQL is executed.
    connection = sqlite3.connect(":memory:")
    try:
        connection.enable_load_extension(False)
        connection.deserialize(data)
        connection.execute("PRAGMA trusted_schema=OFF")
        connection.execute("PRAGMA query_only=ON")
        operations = 0

        def limit():
            nonlocal operations
            operations += 1
            return int(operations > 10_000)

        connection.set_progress_handler(limit, 1000)
        objects = connection.execute("SELECT name,type,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' LIMIT 17").fetchall()
        require(len(objects) <= 16 and {x[0] for x in objects} <= {"SENSOR_TABLE", "android_metadata"}, "database_objects")
        require(all(kind == "table" and sql.lstrip().upper().startswith("CREATE TABLE") for _, kind, sql in objects), "database_tables")
        columns = connection.execute("PRAGMA table_info(SENSOR_TABLE)").fetchall()
        require([x[1] for x in columns] == COLUMNS, "database_columns")
        counts, rows, repeated, regressions, previous = Counter(), 0, 0, 0, None
        for row in connection.execute("SELECT TIME,ACTIVITY,ACCEL_X,ACCEL_Y,ACCEL_Z,GYRO_X,GYRO_Y,GYRO_Z,CURRENT_SPEED FROM SENSOR_TABLE ORDER BY rowid"):
            rows += 1
            require(rows <= MAX_ROWS, "database_rows")
            timestamp, label, *numbers = row
            require(type(timestamp) is str and re.fullmatch(r"[0-9]{2}:[0-9]{2}:[0-9]{2}", timestamp), "timestamp_format")
            h, m, s = map(int, timestamp.split(":"))
            require(h < 24 and m < 60 and s < 60, "timestamp_range")
            seconds = h*3600+m*60+s
            require(type(label) is str and label in HARVARD_LABELS, "activity_label")
            require(all(type(v) in (int, float) and math.isfinite(v) for v in numbers), "sensor_numeric")
            if previous is not None:
                repeated += int(seconds == previous)
                regressions += int(seconds < previous)
            previous = seconds
            counts[label] += 1
        require(rows, "empty_database")
        return {"rows": rows, "columns": COLUMNS, "activity_row_counts": dict(sorted(counts.items())),
                "timestamp_resolution_seconds": 1, "adjacent_equal_timestamp_pairs": repeated,
                "adjacent_backward_timestamp_pairs": regressions,
                "driver_or_trip_column_present": False, "sensor_accuracy_or_gnss_accuracy_column_present": False,
                "verified_ordinary_driving_exposure_seconds": None}
    finally:
        connection.close()


def qualify(source, path):
    if source == "harvard-f5jzhf-v1":
        result = {"source": "https://doi.org/10.7910/DVN/F5JZHF", "license": "CC0-1.0",
                  "findings": harvard_summary(pinned_bytes(path, HARVARD)),
                  "blocking_evidence": ["driver_trip_grouping_missing", "subsecond_timing_unavailable",
                      "feature_units_frame_quality_unverified", "independent_interval_truth_unverified",
                      "ordinary_negative_exposure_unverified", "unseen_grouped_evaluation_missing"]}
    else:
        require(source == "zenodo-6570972-v1-labels", "source_identity")
        trips = [label_summary(pinned_bytes(path/name, pin)) for name, pin in ZENODO.items()]
        totals = Counter()
        for trip in trips:
            totals.update(trip["class_counts"])
        result = {"source": "https://zenodo.org/records/6570972", "license": "CC-BY-4.0",
                  "findings": {"trips": trips, "intervals": sum(t["intervals"] for t in trips),
                      "class_counts": dict(sorted(totals.items())),
                      "annotated_nonaggressive_seconds": round(sum(t["annotated_nonaggressive_seconds"] for t in trips), 6),
                      "publisher_driver_count": 1, "streams_inspected": False},
                  "blocking_evidence": ["single_driver_no_independent_train_validation_test_groups",
                      "feature_stream_units_frame_quality_sync_unverified", "normal_exposure_not_continuously_reviewed",
                      "road_impact_phone_movement_truth_missing", "unseen_grouped_evaluation_missing"]}
    return {"qualification_version": VERSION, **result, "training_admitted": False,
            "production_evaluation_admitted": False, "model_predictions_computed": False,
            "disposition": "development_qualification_only", "fresh_locked_evaluation_eligible": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=["harvard-f5jzhf-v1", "zenodo-6570972-v1-labels"], required=True)
    parser.add_argument("--input", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = qualify(args.source, args.input)
    except (OSError, ValueError, sqlite3.Error, csv.Error, OverflowError):
        print("Source qualification failed: invalid or unavailable pinned input. No model data admitted.", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
