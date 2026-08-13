import hashlib
import importlib.util
import struct
import sys
import tempfile
import unittest
import uuid
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "inspect_tripdebug", ROOT / "tool" / "inspect_tripdebug.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def _utf(value: str) -> bytes:
    encoded = value.encode("utf-8")
    return struct.pack(">H", len(encoded)) + encoded


def _chunk(trip_id: str) -> bytes:
    record = b"".join(
        [
            struct.pack(">i", 1),
            struct.pack(">Bqqi", 2, 100_000_000, 1_100_000_000, 1),
            struct.pack(">fffii", 1.25, -2.5, 9.75, 3, 0),
        ]
    )
    payload = zlib.compress(record, 1)
    checksum = hashlib.sha256(payload).digest()
    return b"".join(
        [
            struct.pack(">iii", 0x54525843, 1, 1),
            _utf(trip_id),
            struct.pack(">qqqiii", 0, 100_000_000, 100_000_000, 0, 1, 0),
            _utf("deflate"),
            _utf("sha256"),
            struct.pack(">qi", 1_777_777_777_000, len(payload)),
            payload,
            struct.pack(">i", 32),
            checksum,
            struct.pack(">i", 0x434F4D50),
        ]
    )


def _archive(path: Path, *, extra_entry: bool = False) -> None:
    trip_id = str(uuid.UUID("123e4567-e89b-12d3-a456-426614174000"))
    chunk = _chunk(trip_id)
    digest = hashlib.sha256(chunk).hexdigest()
    manifest = "\n".join(
        [
            "format=traelyx.tripdebug",
            "archive_version=1",
            "privacy_class=precise_private",
            "contains_precise_location=true",
            f"trip_id={trip_id}",
            "telemetry_schema_version=1",
            "chunk_encoding_version=1",
            "chunk_count=1",
            "start_elapsed_nanos=100000000",
            "end_elapsed_nanos=100000000",
            "gnss_sample_count=0",
            "accelerometer_sample_count=1",
            "gyroscope_sample_count=0",
            "chunk.0.sequence=0",
            "chunk.0.entry=chunks/0000000000.tlxc",
            f"chunk.0.byte_length={len(chunk)}",
            f"chunk.0.sha256={digest}",
            "",
        ]
    ).encode()
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
        archive.writestr("manifest.txt", manifest)
        archive.writestr("chunks/0000000000.tlxc", chunk)
        if extra_entry:
            archive.writestr("../unexpected", b"unsafe")


class InspectTripDebugTest(unittest.TestCase):
    def test_coverage_gaps_include_edges_and_fully_missing_channels(self):
        result = MODULE._coverage_gaps(
            100,
            900,
            {1: 500, 2: 100},
            {1: 500, 2: 900},
            {1: 0, 2: 250, 3: 0},
        )

        self.assertEqual(result, {1: 400, 2: 250, 3: 800})

    def test_verifies_archive_without_raw_sample_output(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.tripdebug"
            _archive(path)
            result = MODULE.inspect_archive(path)

        self.assertTrue(result["verified"])
        self.assertEqual(result["chunk_count"], 1)
        self.assertEqual(result["sample_counts"]["accelerometer"], 1)
        self.assertEqual(result["max_gap_nanos"]["gnss"], 0)
        self.assertNotIn("latitude", result)
        self.assertNotIn("vectors", result)

    def test_rejects_unexpected_or_traversal_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "unsafe.tripdebug"
            _archive(path, extra_entry=True)
            with self.assertRaises(MODULE.TripDebugInvalid):
                MODULE.inspect_archive(path)


if __name__ == "__main__":
    unittest.main()
