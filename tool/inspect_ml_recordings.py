#!/usr/bin/env python3
"""Bounded, local-only quality intake of a precise-private recorder TAR backup.

Never extracts files, decodes databases, emits identifiers/vectors/routes, assigns
labels or admits training/evaluation data. A matching checksum proves bytes,
not consent, mounting, event truth or an unseen driver holdout.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tarfile
import uuid

try:
    from . import inspect_tripdebug as codec
except ImportError:
    import inspect_tripdebug as codec

VERSION = "eventnet-recording-intake-v1"
MAX_BACKUP_BYTES = 512 * 1024 * 1024
MAX_RECORDINGS = 64
MAX_MEMBERS = 100_000
CHANNELS = {1: "gnss", 2: "accelerometer", 3: "gyroscope"}
ENTRY = re.compile(r"no_backup/recorder/trips/([a-f0-9-]{36})/chunks/([0-9]{10})\.tlxc")
FINALIZATION = re.compile(r"no_backup/recorder/finalizations/([a-f0-9-]{36})\.trxf")


class IntakeInvalid(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise IntakeInvalid(code)


def canonical_id(value):
    try:
        return isinstance(value, str) and str(uuid.UUID(value)) == value
    except ValueError:
        return False


def exclusions(path: Path | None) -> set[str]:
    if path is None:
        return set()
    with path.open("rb") as stream:
        raw = stream.read(65537)
    require(0 < len(raw) <= 65536, "exclusion_size")
    value = json.loads(raw)
    require(type(value) is dict and set(value) == {"version", "entries"} and
            type(value["version"]) is int and value["version"] == 1 and type(value["entries"]) is list and
            len(value["entries"]) <= 256, "exclusion_contract")
    result = set()
    for row in value["entries"]:
        require(type(row) is dict and canonical_id(row.get("trip_id")) and row.get("preserve") is True,
                "exclusion_entry")
        result.add(row["trip_id"])
    return result


def compact(decoded):
    channels = {}
    for channel, times in decoded["elapsed_by_channel"].items():
        channels[channel] = None if not times else (
            times[0], times[-1], max((b-a for a, b in zip(times, times[1:])), default=0)
        )
    return {"start": decoded["start"], "end": decoded["end"], "counts": decoded["counts"],
            "channels": channels, "quality": decoded["quality"]}


def summarize(chunks):
    require(sorted(chunks) == list(range(len(chunks))), "sequence_gap")
    first = chunks[0]["start"]
    last = chunks[len(chunks)-1]["end"]
    counts = {name: 0 for name in CHANNELS.values()}
    flagged = {name: 0 for name in CHANNELS.values()}
    accuracy = {CHANNELS[c]: {str(i): 0 for i in range(-1, 4)} for c in (2, 3)}
    start_by_channel, end_by_channel, gaps = {}, {}, {c: 0 for c in CHANNELS}
    previous_end = None
    max_chunk_gap = 0
    mock = 0
    for sequence in range(len(chunks)):
        chunk = chunks[sequence]
        if previous_end is not None:
            require(chunk["start"] >= previous_end, "chunk_time_order")
            max_chunk_gap = max(max_chunk_gap, chunk["start"]-previous_end)
        previous_end = chunk["end"]
        for channel, name in CHANNELS.items():
            counts[name] += chunk["counts"][channel-1]
            flagged[name] += chunk["quality"]["flagged_samples"][channel]
            times = chunk["channels"][channel]
            if times is not None:
                start, end, gap = times
                start_by_channel.setdefault(channel, start)
                if channel in end_by_channel:
                    require(start >= end_by_channel[channel], "channel_time_order")
                    gap = max(gap, start-end_by_channel[channel])
                gaps[channel] = max(gaps[channel], gap)
                end_by_channel[channel] = end
        mock += chunk["quality"]["gnss_mock_samples"]
        for channel in (2, 3):
            for status, count in chunk["quality"]["imu_accuracy"][channel].items():
                accuracy[CHANNELS[channel]][status] += count
    coverage = codec._coverage_gaps(first, last, start_by_channel, end_by_channel, gaps)
    reasons = ["no_governed_event_label_review", "vehicle_frame_not_established",
               "driver_holdout_not_established", "unseen_evaluation_status_not_established"]
    if not counts["gnss"]:
        reasons.append("gnss_missing")
    for name in ("accelerometer", "gyroscope"):
        if not counts[name]:
            reasons.append(name+"_missing")
        elif accuracy[name]["0"] or accuracy[name]["-1"]:
            reasons.append(name+"_unreliable_or_unknown")
    if mock:
        reasons.append("mock_gnss_present")
    return {"chunks": len(chunks), "duration_seconds": round((last-first)/1e9, 6),
            "samples": counts, "flagged_samples": flagged, "imu_accuracy_status_counts": accuracy,
            "gnss_mock_samples": mock, "maximum_chunk_gap_seconds": round(max_chunk_gap/1e9, 6),
            "maximum_channel_coverage_gap_seconds": {CHANNELS[c]: round(gap/1e9, 6) for c, gap in coverage.items()},
            "model_training_eligible": False, "model_evaluation_eligible": False,
            "disposition": "diagnostic_only", "blocking_evidence": reasons}


def inspect_backup(path: Path, expected_sha256: str, excluded: set[str] | None = None):
    require(type(expected_sha256) is str and re.fullmatch(r"[a-f0-9]{64}", expected_sha256), "digest_format")
    excluded = set() if excluded is None else excluded
    require(type(excluded) is set and len(excluded) <= 256 and all(canonical_id(v) for v in excluded), "exclusion_contract")
    groups, seen = {}, set()
    ignored_members = 0
    ignored_metadata = 0
    # Hash and decode the same open descriptor, avoiding a pathname replacement
    # between verification and use. Source is read-only and never extracted.
    with path.open("rb", buffering=0) as stream:
        before = os.fstat(stream.fileno())
        require(0 < before.st_size <= MAX_BACKUP_BYTES, "backup_size")
        require(hashlib.file_digest(stream, "sha256").hexdigest() == expected_sha256, "digest_mismatch")
        stream.seek(0)
        with tarfile.open(fileobj=stream, mode="r:") as archive:
            for index, member in enumerate(archive):
                require(index < MAX_MEMBERS, "member_limit")
                name = member.name.removeprefix("./")
                if not name.startswith("no_backup/recorder/"):
                    ignored_members += int(member.isfile())
                    continue
                require(not member.issym() and not member.islnk(), "recorder_link")
                if member.isdir():
                    require(not any(p in ("", ".", "..") for p in name.rstrip("/").split("/")), "directory_path")
                    continue
                finalization = FINALIZATION.fullmatch(name)
                if finalization is not None or name == "no_backup/recorder/active_trip_v1.bin":
                    require(member.isfile() and 0 < member.size <= 65536 and
                            (finalization is None or canonical_id(finalization[1])), "recorder_metadata")
                    ignored_metadata += 1
                    continue
                match = ENTRY.fullmatch(name)
                require(member.isfile() and match is not None, "recorder_entry")
                trip, sequence = match[1], int(match[2])
                require(canonical_id(trip) and (trip, sequence) not in seen, "entry_identity")
                seen.add((trip, sequence))
                require(0 < member.size <= codec.MAX_CHUNK_BYTES and sequence < codec.MAX_CHUNKS, "chunk_size_or_sequence")
                require(trip in groups or len(groups) < MAX_RECORDINGS, "recording_limit")
                with archive.extractfile(member) as source:
                    data = source.read(codec.MAX_CHUNK_BYTES+1)
                decoded = codec.decode_chunk(data, include_quality=True)
                require(decoded["trip_id"] == trip and decoded["sequence"] == sequence and
                        decoded["encoding_version"] == 1 and decoded["telemetry_version"] == 1, "chunk_identity_or_version")
                groups.setdefault(trip, {})[sequence] = compact(decoded)
        after = os.fstat(stream.fileno())
        require(before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns, "source_changed")
        stream.seek(0)
        require(hashlib.file_digest(stream, "sha256").hexdigest() == expected_sha256, "source_changed")
    require(groups, "no_recordings")
    reports, excluded_count, excluded_chunks = [], 0, 0
    for trip in sorted(groups):
        # Excluded recordings are validated for structural integrity, but their
        # quality/content is not selected for acceptance, labels or evaluation.
        summary = summarize(groups[trip])
        if trip in excluded:
            excluded_count += 1
            excluded_chunks += summary["chunks"]
        else:
            reports.append({"recording": len(reports)+1, **summary})
    return {"inspection_version": VERSION, "privacy_class": "aggregate_private_diagnostic",
            "source_contains_precise_location": True, "input_sha256_verified": True,
            "recordings": reports, "excluded_recordings": excluded_count, "excluded_chunks": excluded_chunks,
            "non_recorder_entries_decoded": False, "non_recorder_files_ignored": ignored_members,
            "recorder_state_metadata_ignored": ignored_metadata, "finalization_state": "not_assessed",
            "training_admitted": False, "evaluation_admitted": False,
            "interpretation": "Integrity/coverage/quality evidence only. No labels, mounting, driver split or unseen-test status inferred."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--excluded-trips", type=Path)
    args = parser.parse_args()
    try:
        result = inspect_backup(args.backup, args.expected_sha256, exclusions(args.excluded_trips))
    except (OSError, ValueError, tarfile.TarError):
        print("Recording intake failed: invalid, changed or unavailable private input. No model data admitted.", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
