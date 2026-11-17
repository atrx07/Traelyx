import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

from tool import inspect_field_recording as cli
from tool import inspect_tripdebug as codec
from tests.tool.test_inspect_ml_recordings import TRIP, chunk
from tests.tool.test_inspect_tripdebug import _archive


def archive(path, *, accuracy=3, flags=0, mock_gnss=False, extra=False):
    chunks = [chunk(sequence=i, time=100_000_000+i*1_000_000_000,
                    accuracy=accuracy, flags=flags, mock=mock_gnss) for i in range(2)]
    rows = ["format=traelyx.tripdebug", "archive_version=1", "privacy_class=precise_private",
            "contains_precise_location=true", f"trip_id={TRIP}", "telemetry_schema_version=1",
            "chunk_encoding_version=1", "chunk_count=2", "start_elapsed_nanos=100000000",
            "end_elapsed_nanos=1100000000", "gnss_sample_count=2",
            "accelerometer_sample_count=2", "gyroscope_sample_count=2"]
    for i, data in enumerate(chunks):
        rows += [f"chunk.{i}.sequence={i}", f"chunk.{i}.entry=chunks/{i:010d}.tlxc",
                 f"chunk.{i}.byte_length={len(data)}",
                 f"chunk.{i}.sha256={hashlib.sha256(data).hexdigest()}"]
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as out:
        out.writestr("manifest.txt", ("\n".join(rows)+"\n").encode())
        for i, data in enumerate(chunks):
            out.writestr(f"chunks/{i:010d}.tlxc", data)
        if extra:
            out.writestr("../private-extra", b"private")
    return hashlib.sha256(path.read_bytes()).hexdigest()


class FieldRecordingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="field-intake-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)/"private.tripdebug"

    def test_clean_export_quality_privacy_and_no_admission(self):
        digest = archive(self.path)
        original = self.path.read_bytes()
        result = codec.inspect_pinned_archive(self.path, digest)
        quality = result["quality"]
        self.assertEqual(quality["chunks"], 2)
        self.assertEqual(quality["duration_seconds"], 1.0)
        self.assertEqual(quality["samples"], {"gnss": 2, "accelerometer": 2, "gyroscope": 2})
        self.assertEqual(quality["imu_accuracy_status_counts"]["accelerometer"]["3"], 2)
        self.assertEqual(quality["maximum_channel_coverage_gap_seconds"],
                         {"gnss": 1.0, "accelerometer": 1.0, "gyroscope": 1.0})
        self.assertEqual(len(quality["blocking_evidence"]), 4)
        for key in ["training_admitted", "evaluation_admitted", "independent_labels_verified",
                    "cross_device_alignment_verified", "sensor_calibration_verified",
                    "training_consent_verified"]:
            self.assertFalse(result[key])
        self.assertFalse(quality["model_training_eligible"])
        self.assertFalse(quality["model_evaluation_eligible"])
        text = json.dumps(result)
        for private in [TRIP, digest, str(self.path), "12.1234567", "76.7654321", "1.25",
                        "1777777777000", "1100000000"]:
            self.assertNotIn(private, text)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(list(self.path.parent.iterdir()), [self.path])

    def test_tecno_unreliable_flags_preserved_without_correction(self):
        result = codec.inspect_pinned_archive(self.path, archive(self.path, accuracy=0, flags=8))
        quality = result["quality"]
        self.assertEqual(quality["imu_accuracy_status_counts"]["accelerometer"]["0"], 2)
        self.assertEqual(quality["flagged_samples"]["accelerometer"], 2)
        self.assertIn("accelerometer_unreliable_or_unknown", quality["blocking_evidence"])

    def test_unknown_status_and_mock_gnss_preserved(self):
        result = codec.inspect_pinned_archive(self.path, archive(self.path, accuracy=72, mock_gnss=True))
        self.assertEqual(result["quality"]["imu_accuracy_status_counts"]["accelerometer"]["-1"], 2)
        self.assertEqual(result["quality"]["gnss_mock_samples"], 2)
        self.assertIn("mock_gnss_present", result["quality"]["blocking_evidence"])

    def test_missing_sensors_stay_missing(self):
        _archive(self.path)
        digest = hashlib.sha256(self.path.read_bytes()).hexdigest()
        result = codec.inspect_pinned_archive(self.path, digest)
        self.assertEqual(result["quality"]["samples"]["gyroscope"], 0)
        self.assertIn("gyroscope_missing", result["quality"]["blocking_evidence"])
        self.assertIn("gnss_missing", result["quality"]["blocking_evidence"])

    def test_wrong_digest_rejected_before_decode(self):
        archive(self.path)
        with mock.patch.object(codec, "_inspect_archive") as decode:
            with self.assertRaisesRegex(codec.TripDebugInvalid, "digest_mismatch"):
                codec.inspect_pinned_archive(self.path, "0"*64)
            decode.assert_not_called()

    def test_digest_format_rejected_without_opening(self):
        for digest in [None, True, "A"*64, "0"*63, "0"*64+"\n"]:
            with self.subTest(digest=digest):
                with self.assertRaisesRegex(codec.TripDebugInvalid, "digest_format"):
                    codec.inspect_pinned_archive(self.path, digest)

    def test_unexpected_entry_rejected_despite_valid_outer_hash(self):
        digest = archive(self.path, extra=True)
        with self.assertRaisesRegex(codec.TripDebugInvalid, "archive_entry_order"):
            codec.inspect_pinned_archive(self.path, digest)

    def test_size_limit_applies_before_hashing(self):
        digest = archive(self.path)
        with mock.patch.object(codec, "MAX_ARCHIVE_BYTES", 1), mock.patch.object(codec.hashlib, "file_digest") as hash_file:
            with self.assertRaisesRegex(codec.TripDebugInvalid, "archive_size"):
                codec.inspect_pinned_archive(self.path, digest)
            hash_file.assert_not_called()

    def test_changed_source_metadata_rejected(self):
        digest = archive(self.path)
        original = codec._inspect_archive

        def mutate(*args, **kwargs):
            result = original(*args, **kwargs)
            with self.path.open("ab") as out:
                out.write(b"changed")
            return result

        with mock.patch.object(codec, "_inspect_archive", side_effect=mutate):
            with self.assertRaisesRegex(codec.TripDebugInvalid, "source_changed"):
                codec.inspect_pinned_archive(self.path, digest)

    def test_same_size_mutation_with_restored_mtime_still_rejected(self):
        digest = archive(self.path)
        before = self.path.stat()
        original = codec._inspect_archive

        def mutate(*args, **kwargs):
            result = original(*args, **kwargs)
            with self.path.open("r+b") as out:
                out.seek(-1, 2)
                out.write(b"x")
            os.utime(self.path, ns=(before.st_atime_ns, before.st_mtime_ns))
            return result

        with mock.patch.object(codec, "_inspect_archive", side_effect=mutate):
            with self.assertRaisesRegex(codec.TripDebugInvalid, "source_changed"):
                codec.inspect_pinned_archive(self.path, digest)

    def test_parser_uses_original_descriptor_without_reopening_path(self):
        digest = archive(self.path)
        # A second open could resolve to replaced pathname bytes. Make such an
        # open fail; hashing, parsing and final verification must share one handle.
        with self.path.open("rb", buffering=0) as stream:
            path = mock.Mock()
            path.open.side_effect = [stream, AssertionError("path reopened")]
            result = codec.inspect_pinned_archive(path, digest)
            self.assertTrue(result["archive_integrity_verified"])
            path.open.assert_called_once_with("rb", buffering=0)

    def test_legacy_output_unchanged(self):
        archive(self.path)
        result = codec.inspect_archive(self.path)
        self.assertEqual(result["trip_id"], TRIP)
        self.assertEqual(result["sample_counts"]["gnss"], 2)
        self.assertNotIn("quality", result)
        self.assertEqual(result["max_gap_nanos"]["accelerometer"], 1_000_000_000)

    def test_cli_success_only_aggregates_and_failure_only_generic_code(self):
        digest = archive(self.path)
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = cli.main([str(self.path), "--expected-sha256", digest])
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(stdout.getvalue())["input_sha256_verified"])
        self.assertEqual(stderr.getvalue(), "")
        for private in [TRIP, str(self.path), digest]:
            self.assertNotIn(private, stdout.getvalue())
        for path, pinned in [(self.path, "0"*64), (self.path.parent/"private-missing", digest)]:
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = cli.main([str(path), "--expected-sha256", pinned])
            self.assertEqual(code, 1)
            self.assertEqual(stdout.getvalue(), "")
            self.assertEqual(stderr.getvalue(), "field_recording_invalid\n")
        for error in [ValueError("private ZIP metadata"), UnicodeDecodeError("utf-8", b"\xff", 0, 1, "private")]:
            stdout, stderr = io.StringIO(), io.StringIO()
            with mock.patch.object(cli, "inspect_pinned_archive", side_effect=error), contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = cli.main([str(self.path), "--expected-sha256", digest])
            self.assertEqual(code, 1)
            self.assertEqual(stdout.getvalue(), "")
            self.assertEqual(stderr.getvalue(), "field_recording_invalid\n")


if __name__ == "__main__":
    unittest.main()
