import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from ml import qmotion_qualification as q


def annotations(extra=()):
    rows = [{"buttonId": "collecting-data", "event": "start", "time": "2025-01-01 12:00:00.000"}]
    rows.extend({"buttonId": name, "event": event, "time": f"2025-01-01 12:00:{seconds:06.3f}"}
                for name, event, seconds in extra)
    rows.append({"buttonId": "collecting-data", "event": "stop", "time": "2025-01-01 12:00:10.000"})
    return json.dumps(rows).encode()


def session(key, driver, smc="1", scenario="intended_aggressive"):
    return {"key": ("2025-01-01", key), "driver": driver, "smc": smc, "scenario": scenario, "occupants": 2}


def rotation(matrix="1 0 0 0 1 0 0 0 1", idle="0 0 9.8"):
    return ("Date,Vehicle,Sensor_source,Rotation_matrix,Idle_vector;;;;\n"
            f"01/01/2025,AMI,SMC,[{matrix}],[{idle}];;;;\n;;;;\n").encode()


class QMotionQualificationTest(unittest.TestCase):
    def test_annotation_serialization_order_is_not_sensor_clock_rollback(self):
        raw = annotations([("braking", "start", 2), ("curve", "start", 1),
                           ("braking", "stop", 3), ("curve", "stop", 4)])
        report = q.intervals(raw)
        self.assertEqual(report["counts"], {"braking": 1, "curve": 1})
        self.assertEqual(report["reverse_pairs"], 1)
        self.assertEqual(report["overlapping_class_pairs"], 1)
        self.assertEqual(report["control_seconds"], 10)

    def test_contiguous_same_button_intervals_remain_distinct(self):
        raw = annotations([("braking", "start", 1), ("braking", "stop", 2),
                           ("braking", "start", 2), ("braking", "stop", 3)])
        self.assertEqual(q.intervals(raw)["counts"]["braking"], 2)

    def test_edited_bounds_preserve_explicit_source_pairs_without_sorting_or_merging(self):
        raw = annotations([("braking", "start", 1), ("braking", "stop", 3),
                           ("braking", "start", 2), ("braking", "stop", 4)])
        result = q.intervals(raw)
        self.assertEqual(result["counts"]["braking"], 2)
        self.assertEqual(result["overlapping_same_class_pairs"], 1)
        self.assertEqual(result["reverse_pairs"], 1)

    def test_invalid_or_ambiguous_event_pairs_fail_closed(self):
        cases = [[("braking", "stop", 2)], [("braking", "start", 1)],
                 [("braking", "start", 1), ("braking", "start", 2), ("braking", "stop", 3)],
                 [("braking", "start", 1), ("braking", "stop", 1)],
                 [("inferred-normal", "start", 1), ("inferred-normal", "stop", 2)]]
        for case in cases:
            with self.subTest(case=case), self.assertRaises(q.InvalidSource):
                q.intervals(annotations(case))
        for raw in [b'[]', b'{}', b'[{"buttonId":"braking"}]', b'x'*32769]:
            with self.assertRaises(q.InvalidSource):
                q.intervals(raw)

    def test_baseline_and_unlabelled_control_time_do_not_become_verified_negatives(self):
        sessions = [session("a", "opaque-driver-A", scenario="intended_baseline"),
                    session("b", "opaque-driver-B")]
        report = q.audit_metadata(sessions, [(sessions[0]["key"], annotations()),
                    (sessions[1]["key"], annotations([("braking", "start", 1), ("braking", "stop", 2)]))])
        self.assertIsNone(report["verified_normal_driving_seconds"])
        self.assertEqual(report["auxiliary_only_annotation_files"], 1)
        self.assertEqual(report["smartphone_sources_shared_across_drivers"], 1)
        self.assertIn("zig-zag", report["groups"][1]["missing_manual_classes"])
        rendered = json.dumps(report)
        for private in ["opaque-driver", "12:00", '"key"', '"smc"']:
            self.assertNotIn(private, rendered)

    def test_duplicate_or_unmapped_session_does_not_get_a_driver_invented(self):
        row = session("a", "one")
        with self.assertRaises(q.InvalidSource):
            q.audit_metadata([row, row], [])
        with self.assertRaises(q.InvalidSource):
            q.audit_metadata([row], [(("2025-01-01", "other"), annotations())])
        with self.assertRaises(q.InvalidSource):
            q.audit_metadata([row], [(row["key"], annotations()), (row["key"], annotations())])

    def test_guideline_semantics_are_explicit_and_extra_columns_rejected(self):
        raw = b'Code,Rosbag,SMC,Driver_ID\nAMI_UC0_NO2-W1_Pr-normal,a,,person-A\n'
        row = q.guidelines(raw, "2025-01-01")[0]
        self.assertEqual(row["scenario"], "intended_baseline")
        self.assertEqual(row["smc"], "")
        for data in [raw.replace(b'UC0', b'UC9'), raw.replace(b'person-A', b''),
                     raw.replace(b'Driver_ID', b'Driver_ID,extra'), b'']:
            with self.assertRaises(q.InvalidSource):
                q.guidelines(data, "2025-01-01")

    def test_rotation_scaling_is_reported_and_never_silently_corrected(self):
        raw = rotation("0.9 0 0 0 1 0 0 0 1")
        report = q.rotation_summary(raw)
        self.assertAlmostEqual(report["maximum_gram_matrix_error"], 0.19)
        self.assertEqual(report["determinant_range"], [0.9, 0.9])
        self.assertFalse(report["correction_applied"])
        self.assertFalse(report["native_frame_equivalence_accepted"])
        self.assertEqual(report["ignored_spreadsheet_padding_rows"], 1)

    def test_invalid_rotation_metadata_and_duplicates_fail_closed(self):
        for raw in [rotation("NaN 0 0 0 1 0 0 0 1"), rotation("1 0 0"),
                    rotation().replace(b';;;;', b'')]:
            with self.assertRaises(q.InvalidSource):
                q.rotation_summary(raw)
        lines = rotation().decode().splitlines()
        with self.assertRaises(q.InvalidSource):
            q.rotation_summary(('\n'.join([lines[0], lines[1], lines[1]])+'\n').encode())

    def test_pin_read_preserves_input_and_rejects_escape_duplicate_or_changed_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); raw = b'public document'; path = root/'doc.txt'; path.write_bytes(raw)
            entry = {"path": "doc.txt", "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(), "role": "document"}
            profile = {"profile_version": 1, "files": [entry]}
            self.assertEqual(q.read_inputs(root, profile)[0][1], raw)
            self.assertEqual(path.read_bytes(), raw)
            for name in ['../private.txt', 'C:/private.txt', 'folder\\private.txt', './doc.txt']:
                with self.subTest(name=name), self.assertRaises(q.InvalidSource):
                    q.read_inputs(root, {**profile, "files": [{**entry, "path": name}]})
            with self.assertRaises(q.InvalidSource):
                q.read_inputs(root, {**profile, "files": [entry, entry]})
            path.write_bytes(b'PUBLIC document')
            with self.assertRaises(q.InvalidSource):
                q.read_inputs(root, profile)

    def test_cli_error_contains_no_private_path_or_source_values(self):
        captured = io.StringIO()
        with mock.patch('sys.argv', ['qmotion', '--root', 'private-home-route']), contextlib.redirect_stderr(captured):
            self.assertEqual(q.main(), 2)
        self.assertNotIn('private-home-route', captured.getvalue())
        self.assertNotIn('Traceback', captured.getvalue())


if __name__ == '__main__':
    unittest.main()
