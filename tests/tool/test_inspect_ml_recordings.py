import hashlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import tarfile
import tempfile
import unittest
from unittest import mock
import uuid
import zlib

from tool import inspect_ml_recordings as intake
from tool import inspect_tripdebug as codec

TRIP = str(uuid.UUID("123e4567-e89b-12d3-a456-426614174000"))
OTHER = str(uuid.UUID("223e4567-e89b-12d3-a456-426614174000"))


def utf(value):
    raw = value.encode()
    return struct.pack(">H", len(raw))+raw


def chunk(trip=TRIP, sequence=0, time=100_000_000, accuracy=0, flags=8, mock=False, raw_override=None):
    prefix = lambda channel: struct.pack(">Bqqi", channel, time, time+1_000_000_000, 1)
    gnss = prefix(1)+b"\x00"+struct.pack(">ddf", 12.1234567, 76.7654321, 5)+b"\x00"*6+utf("gps")+struct.pack(">?i", mock, 0)
    accel = prefix(2)+struct.pack(">fffii", 1.25, -2.5, 9.75, accuracy, flags)
    gyro = prefix(3)+struct.pack(">fffii", 0.1, 0.2, 0.3, 3, 0)
    raw = struct.pack(">i", 3)+gnss+accel+gyro if raw_override is None else raw_override
    payload = zlib.compress(raw, 1)
    return (struct.pack(">iii", codec.CHUNK_MAGIC, 1, 1)+utf(trip)+
            struct.pack(">qqqiii", sequence, time, time, 1, 1, 1)+utf("deflate")+utf("sha256")+
            struct.pack(">qi", 1_777_777_777_000, len(payload))+payload+struct.pack(">i", 32)+
            hashlib.sha256(payload).digest()+struct.pack(">i", codec.COMPLETION_MAGIC))


def entry(trip=TRIP, sequence=0):
    return f"no_backup/recorder/trips/{trip}/chunks/{sequence:010d}.tlxc"


def backup(path, entries):
    with tarfile.open(path, "w:") as archive:
        for name, value in entries:
            info = tarfile.TarInfo(name)
            if isinstance(value, tarfile.TarInfo):
                archive.addfile(value)
            else:
                info.size = len(value)
                archive.addfile(info, io.BytesIO(value))
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RecordingIntakeTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="traelyx-intake-")
        self.root = Path(self.temporary.name)
        self.path = self.root/"private.tar"

    def tearDown(self):
        self.temporary.cleanup()

    def inspect(self, entries, excluded=None):
        digest = backup(self.path, entries)
        return intake.inspect_backup(self.path, digest, excluded)

    def test_aggregate_quality_privacy_and_no_training_admission(self):
        result = self.inspect([(entry(), chunk(mock=True)), ("app_flutter/traelyx.sqlite", b"private account database")])
        row = result["recordings"][0]
        self.assertEqual(row["samples"], {"gnss": 1, "accelerometer": 1, "gyroscope": 1})
        self.assertEqual(row["imu_accuracy_status_counts"]["accelerometer"]["0"], 1)
        self.assertEqual(row["flagged_samples"]["accelerometer"], 1)
        self.assertEqual(row["gnss_mock_samples"], 1)
        self.assertFalse(row["model_training_eligible"])
        self.assertFalse(row["model_evaluation_eligible"])
        self.assertIn("accelerometer_unreliable_or_unknown", row["blocking_evidence"])
        self.assertEqual(result["non_recorder_files_ignored"], 1)
        public = json.dumps(result)
        for private in [TRIP, "12.1234567", "76.7654321", "private account database", str(self.root), "1.25"]:
            self.assertNotIn(private, public)
        self.assertEqual(list(self.root.iterdir()), [self.path])

    def test_even_clean_status_cannot_infer_labels_mounting_driver_or_holdout(self):
        result = self.inspect([(entry(), chunk(accuracy=3, flags=0))])
        row = result["recordings"][0]
        self.assertEqual(len(row["blocking_evidence"]), 4)
        self.assertFalse(result["training_admitted"])
        self.assertFalse(result["evaluation_admitted"])

    def test_unknown_accuracy_is_preserved_as_unknown(self):
        row = self.inspect([(entry(), chunk(accuracy=71))])["recordings"][0]
        self.assertEqual(row["imu_accuracy_status_counts"]["accelerometer"]["-1"], 1)
        self.assertEqual(row["imu_accuracy_status_counts"]["accelerometer"]["0"], 0)

    def test_known_state_metadata_is_ignored_without_claiming_finalization(self):
        result = self.inspect([(entry(), chunk()), (f"no_backup/recorder/finalizations/{TRIP}.trxf", b"private metadata"),
                               ("no_backup/recorder/active_trip_v1.bin", b"private state")])
        self.assertEqual(result["recorder_state_metadata_ignored"], 2)
        self.assertEqual(result["finalization_state"], "not_assessed")
        self.assertNotIn("private metadata", json.dumps(result))

    def test_archive_order_does_not_change_sorted_sequence_coverage(self):
        result = self.inspect([(entry(sequence=1), chunk(sequence=1, time=300_000_000)), (entry(), chunk())])
        row = result["recordings"][0]
        self.assertEqual(row["chunks"], 2)
        self.assertEqual(row["duration_seconds"], 0.2)
        self.assertEqual(row["maximum_channel_coverage_gap_seconds"], {c: 0.2 for c in ["gnss", "accelerometer", "gyroscope"]})

    def test_excluded_recording_never_enters_selected_report(self):
        result = self.inspect([(entry(), chunk()), (entry(OTHER), chunk(trip=OTHER))], {OTHER})
        self.assertEqual(len(result["recordings"]), 1)
        self.assertEqual(result["excluded_recordings"], 1)
        self.assertEqual(result["excluded_chunks"], 1)

    def test_source_and_exclusion_ledger_are_unchanged(self):
        digest = backup(self.path, [(entry(), chunk())])
        ledger = self.root/"exclusions.json"
        ledger.write_text(json.dumps({"version": 1, "entries": [{"trip_id": TRIP, "preserve": True, "reason": "private"}]}))
        before = ledger.read_bytes()
        result = intake.inspect_backup(self.path, digest, intake.exclusions(ledger))
        self.assertEqual(result["recordings"], [])
        self.assertEqual(ledger.read_bytes(), before)
        self.assertEqual(hashlib.sha256(self.path.read_bytes()).hexdigest(), digest)

    def test_changed_source_is_rejected_even_if_length_and_timestamp_are_restored(self):
        digest = backup(self.path, [(entry(), chunk()), ("app_flutter/traelyx.sqlite", b"private-old-value")])
        before = self.path.stat()
        original = intake.compact
        def mutate(decoded):
            raw = self.path.read_bytes()
            self.path.write_bytes(raw.replace(b"private-old-value", b"private-new-value"))
            os.utime(self.path, ns=(before.st_atime_ns, before.st_mtime_ns))
            return original(decoded)
        with mock.patch.object(intake, "compact", side_effect=mutate):
            with self.assertRaisesRegex(intake.IntakeInvalid, "source_changed"):
                intake.inspect_backup(self.path, digest)

    def test_missing_channels_are_not_fabricated_and_exclusion_does_not_hide_corruption(self):
        from tests.tool.test_inspect_tripdebug import _chunk as accelerometer_only
        row = self.inspect([(entry(), accelerometer_only(TRIP))])["recordings"][0]
        self.assertEqual(row["samples"]["gnss"], 0)
        self.assertEqual(row["samples"]["gyroscope"], 0)
        self.assertIn("gnss_missing", row["blocking_evidence"])
        self.assertIn("gyroscope_missing", row["blocking_evidence"])
        damaged = bytearray(chunk()); damaged[-8] ^= 1
        with self.assertRaises(codec.TripDebugInvalid):
            self.inspect([(entry(), bytes(damaged))], {TRIP})

    def test_bad_hash_and_empty_input_fail_before_decode(self):
        digest = backup(self.path, [(entry(), chunk())])
        for invalid in ["0"*64, "not a digest"]:
            with self.assertRaises(intake.IntakeInvalid):
                intake.inspect_backup(self.path, invalid)
        self.path.write_bytes(b"")
        with self.assertRaises(intake.IntakeInvalid):
            intake.inspect_backup(self.path, digest)

    def test_duplicate_gap_path_and_identity_mismatch_fail_closed(self):
        for entries in [
            [(entry(), chunk()), (entry(), chunk())],
            [(entry(sequence=1), chunk(sequence=1))],
            [(entry().replace("/chunks/", "/../chunks/"), chunk())],
            [(entry(), chunk(trip=OTHER))],
            [(entry(), chunk(sequence=1))],
            [(entry(), chunk()), (entry(sequence=1), chunk(sequence=1, time=1))],
        ]:
            with self.subTest(case=len(entries)):
                with self.assertRaises(intake.IntakeInvalid):
                    self.inspect(entries)

    def test_recorder_links_are_rejected_without_opening_target(self):
        link = tarfile.TarInfo(entry())
        link.type = tarfile.SYMTYPE
        link.linkname = "app_flutter/traelyx.sqlite"
        with self.assertRaises(intake.IntakeInvalid):
            self.inspect([(entry(), link)])

    def test_checksum_corruption_and_decompression_bomb_are_rejected(self):
        damaged = bytearray(chunk()); damaged[-8] ^= 1
        with self.assertRaises(codec.TripDebugInvalid):
            self.inspect([(entry(), bytes(damaged))])
        payload = b"x"*(codec.MAX_PAYLOAD_BYTES+1)
        with self.assertRaisesRegex(codec.TripDebugInvalid, "chunk_payload_limit"):
            codec.decode_chunk(chunk(raw_override=payload), include_quality=True)

    def test_limits_and_unsafe_exclusion_ledger(self):
        for value in [{"version": True, "entries": []}, {"version": 1, "entries": [{"trip_id": "../secret", "preserve": True}]}, {"version": 1, "entries": [{"trip_id": TRIP, "preserve": False}]}]:
            path = self.root/"ledger.json"; path.write_text(json.dumps(value))
            with self.assertRaises(intake.IntakeInvalid):
                intake.exclusions(path)
        with self.assertRaises(intake.IntakeInvalid):
            self.inspect([(entry(), chunk())], {"../private"})

    def test_cli_failure_never_prints_private_source_or_error_details(self):
        import subprocess
        script = Path(__file__).resolve().parents[2]/"tool/inspect_ml_recordings.py"
        result = subprocess.run([sys.executable, str(script), "--backup", str(self.root/"private-home-route.tar"), "--expected-sha256", "0"*64], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, "")
        self.assertNotIn("private-home-route", result.stderr)
        self.assertNotIn(str(self.root), result.stderr)


if __name__ == "__main__":
    unittest.main()
