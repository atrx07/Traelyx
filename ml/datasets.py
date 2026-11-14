#!/usr/bin/env python3
"""Offline, bounded, checksum-verified dataset imports. Python standard library only."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile

try:
    from . import synthetic_corpus
except ImportError:
    import synthetic_corpus

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "ml/registry"
SCHEMA = ROOT / "docs/reference/dataset-registry.schema.json"
IMPORT_ROOT = ROOT / "ml/data/private/imports"
IMPORT_VERSION = 1
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_ROWS = 100_000
PUBLIC_HEADER = ["Target(Class)", "GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ"]
OUTPUT_HEADER = [
    "sample_index", "driver_group", "trip_group", "partition", "elapsed_ms",
    "source_label", "source_label_name", "ax", "ay", "az", "gx", "gy", "gz",
]
CHANNELS = ("ax", "ay", "az", "gx", "gy", "gz")


class InvalidDataset(ValueError):
    """Diagnostics contain contract paths/row numbers, never source data."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InvalidDataset(message)


def canonical_json(value: object) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True,
                       allow_nan=False) + "\n").encode("utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _pairs(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def load_json(path: Path) -> dict:
    try:
        require(path.stat().st_size <= 256 * 1024, "JSON exceeds size limit")
        with path.open("rb") as stream:
            data = stream.read(256 * 1024 + 1)
        require(len(data) <= 256 * 1024, "JSON exceeds size limit")
        value = json.loads(data, object_pairs_hook=_pairs,
                           parse_constant=lambda _: require(False, "non-finite JSON"))
        require(type(value) is dict, "JSON root must be an object")
        return value
    except (OSError, ValueError, RecursionError) as error:
        if isinstance(error, InvalidDataset):
            raise
        raise InvalidDataset("cannot read valid bounded JSON") from None


def validate_schema(value: object, schema: dict, path: str = "entry") -> None:
    """Evaluate only our checked-in schema vocabulary; reject unsupported keywords.

    This is not a general JSON Schema implementation. Failing on unknown keywords
    prevents a future schema constraint from being silently ignored.
    """
    supported = {
        "$schema", "$id", "title", "description", "type", "const", "enum",
        "required", "properties", "additionalProperties", "items", "minItems",
        "maxItems", "minLength", "maxLength", "pattern", "minimum", "maximum",
    }
    require(not (schema.keys() - supported), "unsupported schema keyword")
    kinds = {
        "object": type(value) is dict, "array": type(value) is list,
        "string": type(value) is str, "integer": type(value) is int,
        "number": type(value) in (int, float), "boolean": type(value) is bool,
        "null": value is None,
    }
    expected = schema.get("type", list(kinds))
    if isinstance(expected, str):
        expected = [expected]
    require(all(kind in kinds for kind in expected), "unsupported schema type")
    require(any(kinds[kind] for kind in expected), f"{path}: wrong type")
    if "const" in schema:
        require(value == schema["const"], f"{path}: wrong constant")
    if "enum" in schema:
        require(value in schema["enum"], f"{path}: unknown choice")
    if type(value) is dict:
        require(set(schema.get("required", [])) <= value.keys(), f"{path}: missing field")
        properties = schema.get("properties", {})
        for key, child in value.items():
            rule = properties.get(key, schema.get("additionalProperties", True))
            require(rule is not False, f"{path}: unknown field")
            if isinstance(rule, dict):
                # Arbitrary keys can be untrusted; keep them out of diagnostics.
                child_path = f"{path}.{key}" if key in properties else f"{path}.item"
                validate_schema(child, rule, child_path)
    elif type(value) is list:
        require(schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", MAX_ROWS),
                f"{path}: invalid list length")
        for child in value:
            validate_schema(child, schema.get("items", {}), f"{path}[]")
    elif type(value) is str:
        require(schema.get("minLength", 0) <= len(value) <= schema.get("maxLength", 4096),
                f"{path}: invalid string length")
        if "pattern" in schema:
            require(re.fullmatch(schema["pattern"], value) is not None, f"{path}: invalid text")
    elif type(value) in (int, float):
        require(type(value) is int or math.isfinite(value), f"{path}: non-finite number")
        require(schema.get("minimum", -math.inf) <= value <= schema.get("maximum", math.inf),
                f"{path}: number out of bounds")


def validate_entry(entry: dict) -> None:
    if entry.get("schema_version") == 2:
        validate_schema(entry, load_json(ROOT / "docs/reference/dataset-registry-v2.schema.json"))
        require(entry["channels"] == {name: "m/s2" if name.startswith("a") else "deg/s"
                                      for name in CHANNELS}, "source-v3 channel units contract")
        require(entry["groups"] == {"source-driver-1": "train", "source-driver-2": "validation",
                                    "source-driver-3": "test"}, "source-v3 locked split contract")
        require(entry["source_labels"] == {"1": "sudden_acceleration", "2": "sudden_right_turn",
                                           "3": "sudden_left_turn", "4": "sudden_braking"},
                "source-v3 label contract")
        return
    validate_schema(entry, load_json(SCHEMA))
    require(set(entry["channels"]) == set(CHANNELS), "six explicit IMU channels required")
    require(bool(entry["source_labels"]), "source labels required")
    require(all(re.fullmatch(r"[a-z0-9_]{1,64}", key) for key in entry["source_labels"]),
            "source label keys must be safe tokens")
    require(all(re.fullmatch(r"[a-z0-9-]{1,64}", key) for key in entry["groups"]),
            "driver group keys must be safe tokens")
    require(bool(entry["known_limitations"]), "limitations required")
    public = entry["import_format"] == "mendeley-raw-v2"
    expected_channels = {name: ("m/s2" if name.startswith("a") else
                                "deg/s" if public else "rad/s") for name in CHANNELS}
    require(entry["channels"] == expected_channels, "channel units disagree with source format")
    require(entry["label_provenance"] == ("publisher_annotations" if public else "synthetic_scenario"),
            "label provenance disagrees with source format")
    require(entry["label_confidence"] == ("unverified" if public else "synthetic_not_field_validated"),
            "label confidence disagrees with source evidence")
    require(entry["source_kind"] == ("public" if public else "synthetic"),
            "source kind and importer disagree")
    require(entry["training_use"] == ("blocked" if public else "synthetic_only"),
            "M7.1 data cannot be promoted for training")
    if public:
        require(entry["license"] == "CC-BY-4.0", "public license not reviewed")
        require(entry["groups"] == {}, "public source has no row-level groups")
        require(entry["time_basis"] == "unavailable", "public timestamps unavailable")
        require(entry["unit_status"] == "source_declared_unverified", "public units unverified")
    else:
        require(entry["license"] == "CC0-1.0", "synthetic license contract")
        require(entry["time_basis"] == "synthetic_elapsed_ms", "synthetic time contract")
        require(entry["unit_status"] == "synthetic_defined", "synthetic unit contract")
        require(set(entry["groups"].values()) == {"train", "validation", "test"},
                "synthetic corpus must exercise all partitions")


def registry_entries() -> list[dict]:
    entries = []
    identities = set()
    for path in sorted(REGISTRY.glob("*.json")):
        entry = load_json(path)
        validate_entry(entry)
        identity = (entry["dataset_id"], entry["version"])
        require(identity not in identities, "duplicate dataset identity")
        identities.add(identity)
        entries.append(entry)
    require(bool(entries), "empty registry")
    return entries


def source_bytes(entry: dict, source: Path | None) -> bytes:
    if entry["source_kind"] == "synthetic":
        require(source is None, "synthetic source is generated, not supplied")
        data = synthetic_corpus.generate()
    else:
        require(source is not None, "explicit local public source required")
        require(not source.is_symlink() and source.is_file(), "regular source file required")
        with source.open("rb") as stream:
            data = stream.read(MAX_SOURCE_BYTES + 1)
    require(len(data) <= MAX_SOURCE_BYTES, "source exceeds size limit")
    require(len(data) == entry["source_bytes"], "source length mismatch")
    require(sha256(data) == entry["source_sha256"], "source SHA-256 mismatch")
    return data


def parse_rows(entry: dict, data: bytes):
    """Preserve source numerics/labels; never infer time or driver boundaries."""
    if entry["import_format"] == "mendeley-grouped-v3":
        yield from _grouped_public_rows(entry, data)
        return
    try:
        text = data.decode("utf-8")
    except UnicodeError:
        raise InvalidDataset("source must be UTF-8") from None
    require("\x00" not in text, "NUL in source")
    public = entry["import_format"] == "mendeley-raw-v2"
    expected = PUBLIC_HEADER if public else synthetic_corpus.HEADER
    try:
        reader = csv.reader(io.StringIO(text, newline=""), strict=True)
        require(next(reader, None) == expected, "unexpected columns; privacy allowlist required")
        trips = {}
        closed_trips = set()
        last_trip = None
        count = 0
        for index, row in enumerate(reader):
            count += 1
            require(count <= MAX_ROWS, "row limit exceeded")
            require(len(row) == len(expected), f"row {count}: wrong column count")
            require(all(len(value) <= 128 for value in row), f"row {count}: field too long")
            record = dict(zip(expected, row))
            label = record["Target(Class)" if public else "label"]
            require(label in entry["source_labels"], f"row {count}: unknown source label")
            if public:
                values = [record[name] for name in ("AccX", "AccY", "AccZ", "GyroX", "GyroY", "GyroZ")]
                grouping = ["", "", "quarantine", ""]
            else:
                values = [record[name] for name in CHANNELS]
                driver, trip, partition = (record[name] for name in expected[:3])
                require(re.fullmatch(r"[a-z0-9-]{1,64}", trip) is not None,
                        f"row {count}: invalid trip group")
                require(driver in entry["groups"] and entry["groups"][driver] == partition,
                        f"row {count}: driver partition mismatch")
                require(re.fullmatch(r"[0-9]{1,12}", record["elapsed_ms"]) is not None,
                        f"row {count}: invalid elapsed time")
                elapsed = int(record["elapsed_ms"])
                if last_trip != trip:
                    require(trip not in closed_trips, f"row {count}: noncontiguous trip")
                    if last_trip is not None:
                        closed_trips.add(last_trip)
                if trip in trips:
                    old_driver, old_partition, old_label, old_elapsed = trips[trip]
                    require((driver, partition, label) == (old_driver, old_partition, old_label),
                            f"row {count}: trip provenance changed")
                    require(elapsed > old_elapsed, f"row {count}: elapsed time not increasing")
                trips[trip] = (driver, partition, label, elapsed)
                last_trip = trip
                grouping = [driver, trip, partition, record["elapsed_ms"]]
            for value in values:
                require(re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?", value) is not None,
                        f"row {count}: invalid numeric field")
                require(math.isfinite(float(value)), f"row {count}: non-finite numeric field")
            yield [index, *grouping, label, entry["source_labels"][label], *values]
        require(count > 0, "empty dataset")
    except (csv.Error, OverflowError, ValueError) as error:
        if isinstance(error, InvalidDataset):
            raise
        raise InvalidDataset("malformed CSV") from None


def _grouped_public_rows(entry: dict, data: bytes):
    """V3 clock-of-day never leaves this reader; coarse elapsed is not resampled."""
    header = ["Class", "DriverID", "TaskID", "Hour", "Minute", "Second",
              "GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ"]
    try:
        reader = csv.reader(io.StringIO(data.decode("utf-8"), newline=""), strict=True)
        require(next(reader, None) == header, "unexpected source-v3 privacy columns")
        seen = set()
        last_trip = None
        start = previous = 0
        count = 0
        for index, row in enumerate(reader):
            count += 1
            require(count <= MAX_ROWS and len(row) == len(header), "source-v3 row bounds")
            require(all(len(value) <= 128 for value in row), "source-v3 field bounds")
            label, raw_driver, task = row[:3]
            require(label in entry["source_labels"], "source-v3 unknown label")
            require(raw_driver in {"Driver-1", "Driver-2", "Driver-3"}, "source-v3 unknown driver")
            driver = "source-driver-" + raw_driver[-1]
            require(re.fullmatch(r"[1-9][0-9]{0,3}", task) is not None, "source-v3 invalid task")
            trip = f"{driver}-c{label}-t{task}"
            require(all(re.fullmatch(r"[0-9]{1,2}", value) for value in row[3:6]),
                    "source-v3 invalid clock")
            hour, minute, second = map(int, row[3:6])
            require(hour < 24 and minute < 60 and second < 60, "source-v3 clock bounds")
            clock = hour * 3600 + minute * 60 + second
            if trip != last_trip:
                require(trip not in seen, "source-v3 noncontiguous task")
                seen.add(trip)
                start = previous = clock
            require(clock >= previous, "source-v3 time reversal; do not infer midnight")
            previous, last_trip = clock, trip
            values = row[9:12] + row[6:9]
            for value in values:
                require(re.fullmatch(r"-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?", value) is not None,
                        "source-v3 invalid numeric field")
                require(math.isfinite(float(value)), "source-v3 non-finite numeric field")
            yield [index, driver, trip, entry["groups"][driver], (clock - start) * 1000,
                   label, entry["source_labels"][label], *values]
        require(count == entry["source_expected_rows"] and len(seen) == entry["source_expected_tasks"],
                "source-v3 row/task population mismatch")
    except (UnicodeError, csv.Error, ValueError, OverflowError) as error:
        if isinstance(error, InvalidDataset):
            raise
        raise InvalidDataset("malformed source-v3 CSV") from None


def import_dataset(entry: dict, source: Path | None, output_root: Path = IMPORT_ROOT) -> dict:
    validate_entry(entry)
    data = source_bytes(entry, source)
    # User chooses the local source, but registry text cannot choose filesystem paths.
    require(not any(parent.is_symlink() or parent.is_junction()
                    for parent in (output_root, *output_root.parents)),
            "output ancestors cannot be symlinks or junctions")
    output_root.mkdir(parents=True, exist_ok=True)
    output_root = output_root.resolve()
    target = output_root / f"{entry['dataset_id']}--{entry['version']}--import-v{IMPORT_VERSION}"
    require(not target.exists() and not target.is_symlink(), "import already exists; never overwrite")
    # Same-filesystem rename publishes both files only after all rows validate.
    with tempfile.TemporaryDirectory(prefix=".import-", dir=output_root) as temporary:
        staging = Path(temporary) / "result"
        staging.mkdir()
        samples = staging / "samples.csv"
        counts = {}
        partitions = {}
        record_count = 0
        with samples.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.writer(stream, lineterminator="\n")
            writer.writerow(OUTPUT_HEADER)
            for row in parse_rows(entry, data):
                writer.writerow(row)
                record_count += 1
                counts[row[5]] = counts.get(row[5], 0) + 1
                partitions[row[3]] = partitions.get(row[3], 0) + 1
        manifest = {
            "import_version": IMPORT_VERSION,
            "dataset_id": entry["dataset_id"], "dataset_version": entry["version"],
            "registry_entry_sha256": sha256(canonical_json(entry)),
            "registry_entry": entry,
            "source_sha256": sha256(data), "source_bytes": len(data),
            "preprocessing_version": entry["preprocessing_version"],
            "label_schema": entry["label_schema"], "label_provenance": entry["label_provenance"],
            "label_confidence": entry["label_confidence"], "source_labels": entry["source_labels"],
            "channels": entry["channels"], "reported_rate_hz": entry["reported_rate_hz"],
            "time_basis": entry["time_basis"], "unit_status": entry["unit_status"],
            "license": entry["license"], "attribution": entry["attribution"],
            "source": entry["source"], "privacy": entry["privacy"],
            "training_use": entry["training_use"], "known_limitations": entry["known_limitations"],
            "record_count": record_count, "source_label_counts": counts,
            "partition_counts": partitions, "driver_partitions": entry["groups"],
            "samples_sha256": sha256(samples.read_bytes()),
        }
        (staging / "manifest.json").write_bytes(canonical_json(manifest))
        require(not target.exists(), "import appeared concurrently; never overwrite")
        os.rename(staging, target)
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "import"))
    parser.add_argument("--dataset", help="registered dataset ID")
    parser.add_argument("--version", help="registered dataset version")
    parser.add_argument("--source", type=Path, help="local public CSV; never uploaded")
    args = parser.parse_args(argv)
    try:
        entries = registry_entries()
        if args.command == "validate":
            require(args.dataset is None and args.version is None and args.source is None,
                    "validate takes no import arguments")
            for entry in entries:
                if entry["source_kind"] == "synthetic":
                    list(parse_rows(entry, source_bytes(entry, None)))
            print(f"Dataset registry passed: {len(entries)} entries; synthetic source verified.")
        else:
            matches = [entry for entry in entries if entry["dataset_id"] == args.dataset
                       and entry["version"] == args.version]
            require(len(matches) == 1, "select an exact registered dataset ID and version")
            manifest = import_dataset(matches[0], args.source)
            print(f"Imported {manifest['record_count']} records; training use: {manifest['training_use']}.")
        return 0
    except (InvalidDataset, OSError):
        # OS exception strings may contain private paths. Never print them.
        print("Dataset operation failed; verify registry, source integrity, columns and output collision.",
              file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
