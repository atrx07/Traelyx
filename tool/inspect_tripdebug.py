#!/usr/bin/env python3
"""Strict, privacy-safe inspector for Traelyx .tripdebug archives."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import sys
import uuid
import zipfile
import zlib
from dataclasses import dataclass
from pathlib import Path

ARCHIVE_VERSION = 1
CHUNK_MAGIC = 0x54525843
COMPLETION_MAGIC = 0x434F4D50
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
MAX_CHUNK_BYTES = 4 * 1024 * 1024
MAX_PAYLOAD_BYTES = 16 * 1024 * 1024
MAX_CHUNKS = 10_000
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
KEY_RE = re.compile(r"^[a-z0-9_.]{1,64}$")
VALUE_RE = re.compile(r"^[A-Za-z0-9_./-]{1,256}$")


class TripDebugInvalid(ValueError):
    pass


class Reader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def take(self, size: int) -> bytes:
        if size < 0 or self.offset + size > len(self.data):
            raise TripDebugInvalid("truncated")
        value = self.data[self.offset : self.offset + size]
        self.offset += size
        return value

    def unpack(self, fmt: str):
        size = struct.calcsize(">" + fmt)
        return struct.unpack(">" + fmt, self.take(size))[0]

    def integer(self) -> int:
        return self.unpack("i")

    def long(self) -> int:
        return self.unpack("q")

    def byte(self) -> int:
        return self.unpack("B")

    def boolean(self) -> bool:
        value = self.byte()
        if value not in (0, 1):
            raise TripDebugInvalid("invalid_boolean")
        return value == 1

    def utf(self) -> str:
        length = self.unpack("H")
        raw = self.take(length)
        try:
            value = raw.decode("utf-8")
        except UnicodeDecodeError as error:
            raise TripDebugInvalid("invalid_utf") from error
        if "\x00" in value:
            raise TripDebugInvalid("invalid_utf")
        return value

    def finish(self) -> None:
        if self.offset != len(self.data):
            raise TripDebugInvalid("trailing_bytes")


@dataclass(frozen=True)
class ChunkDescriptor:
    sequence: int
    entry: str
    byte_length: int
    sha256: str


@dataclass(frozen=True)
class Manifest:
    trip_id: str
    telemetry_schema_version: int
    chunk_encoding_version: int
    chunk_count: int
    start_elapsed_nanos: int
    end_elapsed_nanos: int
    sample_counts: dict[str, int]
    chunks: list[ChunkDescriptor]


def _positive_int(values: dict[str, str], key: str, *, allow_zero: bool = False) -> int:
    raw = values.pop(key, None)
    if raw is None or not raw.isdigit():
        raise TripDebugInvalid("manifest_invalid_integer")
    value = int(raw)
    if value < 0 or (not allow_zero and value == 0):
        raise TripDebugInvalid("manifest_invalid_integer")
    return value


def parse_manifest(data: bytes) -> Manifest:
    if not data or len(data) > MAX_MANIFEST_BYTES:
        raise TripDebugInvalid("manifest_size_invalid")
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise TripDebugInvalid("manifest_utf_invalid") from error
    if not text.endswith("\n"):
        raise TripDebugInvalid("manifest_termination_invalid")
    values: dict[str, str] = {}
    for line in text[:-1].split("\n"):
        if "=" not in line:
            raise TripDebugInvalid("manifest_line_invalid")
        key, value = line.split("=", 1)
        if not KEY_RE.fullmatch(key) or not VALUE_RE.fullmatch(value) or key in values:
            raise TripDebugInvalid("manifest_field_invalid")
        values[key] = value

    if values.pop("format", None) != "traelyx.tripdebug":
        raise TripDebugInvalid("manifest_format_invalid")
    if _positive_int(values, "archive_version") != ARCHIVE_VERSION:
        raise TripDebugInvalid("manifest_version_invalid")
    if values.pop("privacy_class", None) != "precise_private":
        raise TripDebugInvalid("manifest_privacy_invalid")
    if values.pop("contains_precise_location", None) != "true":
        raise TripDebugInvalid("manifest_privacy_invalid")
    trip_id = values.pop("trip_id", "")
    try:
        uuid.UUID(trip_id)
    except ValueError as error:
        raise TripDebugInvalid("manifest_trip_id_invalid") from error
    telemetry_version = _positive_int(values, "telemetry_schema_version")
    encoding_version = _positive_int(values, "chunk_encoding_version")
    chunk_count = _positive_int(values, "chunk_count")
    if chunk_count > MAX_CHUNKS:
        raise TripDebugInvalid("manifest_chunk_limit")
    start = _positive_int(values, "start_elapsed_nanos", allow_zero=True)
    end = _positive_int(values, "end_elapsed_nanos", allow_zero=True)
    if end < start:
        raise TripDebugInvalid("manifest_time_invalid")
    sample_counts = {
        "gnss": _positive_int(values, "gnss_sample_count", allow_zero=True),
        "accelerometer": _positive_int(
            values, "accelerometer_sample_count", allow_zero=True
        ),
        "gyroscope": _positive_int(values, "gyroscope_sample_count", allow_zero=True),
    }
    chunks: list[ChunkDescriptor] = []
    for index in range(chunk_count):
        sequence = _positive_int(values, f"chunk.{index}.sequence", allow_zero=True)
        entry = values.pop(f"chunk.{index}.entry", "")
        byte_length = _positive_int(values, f"chunk.{index}.byte_length")
        digest = values.pop(f"chunk.{index}.sha256", "")
        expected_entry = f"chunks/{sequence:010d}.tlxc"
        if sequence != index or entry != expected_entry:
            raise TripDebugInvalid("manifest_sequence_invalid")
        if byte_length > MAX_CHUNK_BYTES or not SHA256_RE.fullmatch(digest):
            raise TripDebugInvalid("manifest_chunk_invalid")
        chunks.append(ChunkDescriptor(sequence, entry, byte_length, digest))
    if values:
        raise TripDebugInvalid("manifest_unknown_field")
    return Manifest(
        trip_id,
        telemetry_version,
        encoding_version,
        chunk_count,
        start,
        end,
        sample_counts,
        chunks,
    )


def _optional(reader: Reader, fmt: str) -> None:
    if reader.boolean():
        value = reader.unpack(fmt)
        if isinstance(value, float) and not math.isfinite(value):
            raise TripDebugInvalid("sample_non_finite")


def decode_chunk(data: bytes) -> dict[str, object]:
    reader = Reader(data)
    if reader.integer() != CHUNK_MAGIC:
        raise TripDebugInvalid("chunk_magic_invalid")
    encoding_version = reader.integer()
    telemetry_version = reader.integer()
    trip_id = reader.utf()
    sequence = reader.long()
    start = reader.long()
    end = reader.long()
    declared_counts = [reader.integer(), reader.integer(), reader.integer()]
    if sequence < 0 or start < 0 or end < start or any(value < 0 for value in declared_counts):
        raise TripDebugInvalid("chunk_metadata_invalid")
    if reader.utf() != "deflate" or reader.utf() != "sha256":
        raise TripDebugInvalid("chunk_codec_invalid")
    if reader.long() <= 0:
        raise TripDebugInvalid("chunk_created_time_invalid")
    payload_length = reader.integer()
    if payload_length <= 0 or payload_length > MAX_CHUNK_BYTES:
        raise TripDebugInvalid("chunk_payload_length_invalid")
    payload = reader.take(payload_length)
    if reader.integer() != 32:
        raise TripDebugInvalid("chunk_checksum_length_invalid")
    checksum = reader.take(32)
    if not hashlib.sha256(payload).digest() == checksum:
        raise TripDebugInvalid("chunk_checksum_invalid")
    if reader.integer() != COMPLETION_MAGIC:
        raise TripDebugInvalid("chunk_incomplete")
    reader.finish()
    try:
        raw = zlib.decompress(payload)
    except zlib.error as error:
        raise TripDebugInvalid("chunk_decompression_failed") from error
    if len(raw) > MAX_PAYLOAD_BYTES:
        raise TripDebugInvalid("chunk_payload_limit")

    records = Reader(raw)
    count = records.integer()
    if count <= 0 or count > 256 or count != sum(declared_counts):
        raise TripDebugInvalid("chunk_count_invalid")
    actual_counts = [0, 0, 0]
    elapsed_by_channel: dict[int, list[int]] = {1: [], 2: [], 3: []}
    ordered: list[tuple[int, int, int]] = []
    for _ in range(count):
        channel = records.byte()
        if channel not in (1, 2, 3):
            raise TripDebugInvalid("sample_channel_invalid")
        elapsed = records.long()
        source = records.long()
        if elapsed < 0 or source < 0:
            raise TripDebugInvalid("sample_time_invalid")
        ordered.append((elapsed, channel, source))
        elapsed_by_channel[channel].append(elapsed)
        actual_counts[channel - 1] += 1
        schema = records.integer()
        if schema != telemetry_version:
            raise TripDebugInvalid("sample_schema_invalid")
        if channel == 1:
            _optional(records, "q")
            latitude = records.unpack("d")
            longitude = records.unpack("d")
            accuracy = records.unpack("f")
            if (
                not math.isfinite(latitude)
                or not math.isfinite(longitude)
                or not math.isfinite(accuracy)
            ):
                raise TripDebugInvalid("sample_non_finite")
            _optional(records, "d")
            for _ in range(5):
                _optional(records, "f")
            if not records.utf():
                raise TripDebugInvalid("provider_invalid")
            records.boolean()
            records.integer()
        else:
            for _ in range(3):
                if not math.isfinite(records.unpack("f")):
                    raise TripDebugInvalid("sample_non_finite")
            records.integer()
            records.integer()
    records.finish()
    if actual_counts != declared_counts or ordered != sorted(ordered):
        raise TripDebugInvalid("chunk_record_order_invalid")
    if ordered[0][0] != start or ordered[-1][0] != end:
        raise TripDebugInvalid("chunk_bounds_invalid")
    return {
        "trip_id": trip_id,
        "sequence": sequence,
        "encoding_version": encoding_version,
        "telemetry_version": telemetry_version,
        "start": start,
        "end": end,
        "counts": actual_counts,
        "elapsed_by_channel": elapsed_by_channel,
    }


def inspect_archive(path: Path) -> dict[str, object]:
    archive_size = path.stat().st_size
    if archive_size <= 0 or archive_size > MAX_ARCHIVE_BYTES:
        raise TripDebugInvalid("archive_size_invalid")
    with zipfile.ZipFile(path, "r") as archive:
        infos = archive.infolist()
        if not infos or len(infos) > MAX_CHUNKS + 1:
            raise TripDebugInvalid("archive_entry_count_invalid")
        if len({info.filename for info in infos}) != len(infos):
            raise TripDebugInvalid("archive_duplicate_entry")
        if infos[0].filename != "manifest.txt" or infos[0].is_dir():
            raise TripDebugInvalid("manifest_not_first")
        if infos[0].file_size > MAX_MANIFEST_BYTES:
            raise TripDebugInvalid("manifest_size_invalid")
        manifest = parse_manifest(archive.read(infos[0]))
        expected_names = ["manifest.txt", *[chunk.entry for chunk in manifest.chunks]]
        if [info.filename for info in infos] != expected_names:
            raise TripDebugInvalid("archive_entry_order_invalid")
        if any(info.compress_type != zipfile.ZIP_STORED for info in infos):
            raise TripDebugInvalid("archive_compression_invalid")

        totals = [0, 0, 0]
        previous_end: int | None = None
        max_chunk_gap = 0
        last_by_channel: dict[int, int] = {}
        max_gap_by_channel = {1: 0, 2: 0, 3: 0}
        for descriptor, info in zip(manifest.chunks, infos[1:]):
            if info.file_size != descriptor.byte_length or info.file_size > MAX_CHUNK_BYTES:
                raise TripDebugInvalid("archive_chunk_size_invalid")
            data = archive.read(info)
            if hashlib.sha256(data).hexdigest() != descriptor.sha256:
                raise TripDebugInvalid("archive_chunk_sha_invalid")
            decoded = decode_chunk(data)
            if (
                decoded["trip_id"] != manifest.trip_id
                or decoded["sequence"] != descriptor.sequence
                or decoded["encoding_version"] != manifest.chunk_encoding_version
                or decoded["telemetry_version"] != manifest.telemetry_schema_version
            ):
                raise TripDebugInvalid("archive_chunk_metadata_invalid")
            start = int(decoded["start"])
            end = int(decoded["end"])
            if previous_end is not None:
                if start < previous_end:
                    raise TripDebugInvalid("archive_chunk_order_invalid")
                max_chunk_gap = max(max_chunk_gap, start - previous_end)
            previous_end = end
            counts = decoded["counts"]
            assert isinstance(counts, list)
            totals = [left + right for left, right in zip(totals, counts)]
            elapsed_by_channel = decoded["elapsed_by_channel"]
            assert isinstance(elapsed_by_channel, dict)
            for channel, samples in elapsed_by_channel.items():
                for elapsed in samples:
                    previous = last_by_channel.get(channel)
                    if previous is not None:
                        if elapsed < previous:
                            raise TripDebugInvalid("archive_channel_order_invalid")
                        max_gap_by_channel[channel] = max(
                            max_gap_by_channel[channel], elapsed - previous
                        )
                    last_by_channel[channel] = elapsed
        expected_totals = [
            manifest.sample_counts["gnss"],
            manifest.sample_counts["accelerometer"],
            manifest.sample_counts["gyroscope"],
        ]
        if totals != expected_totals:
            raise TripDebugInvalid("archive_sample_count_invalid")
        return {
            "format": "traelyx.tripdebug",
            "archive_version": ARCHIVE_VERSION,
            "privacy_class": "precise_private",
            "contains_precise_location": True,
            "trip_id": manifest.trip_id,
            "archive_byte_length": archive_size,
            "chunk_count": manifest.chunk_count,
            "duration_nanos": manifest.end_elapsed_nanos - manifest.start_elapsed_nanos,
            "sample_counts": manifest.sample_counts,
            "max_gap_nanos": {
                "chunks": max_chunk_gap,
                "gnss": max_gap_by_channel[1],
                "accelerometer": max_gap_by_channel[2],
                "gyroscope": max_gap_by_channel[3],
            },
            "verified": True,
        }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify a private Traelyx .tripdebug archive without printing raw samples."
    )
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    try:
        result = inspect_archive(args.archive)
    except (OSError, TripDebugInvalid, zipfile.BadZipFile) as error:
        code = str(error) if str(error) else "archive_invalid"
        print(f"tripdebug_invalid: {code}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
