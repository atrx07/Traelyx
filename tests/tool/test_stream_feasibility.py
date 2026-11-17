import contextlib
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from ml import stream_feasibility as f


def stream(kind="acceleration", times=None):
    if times is None:
        times = [i/100 for i in range(801)]
    out = io.StringIO(newline="")
    import csv
    writer = csv.writer(out)
    writer.writerow(f.HEADERS[kind])
    writer.writerows((str(t), "1", "-2", "3") for t in times)
    return out.getvalue().encode()


def labels():
    return b'start,end,event,target,timesync,sample\n0,6,non-aggressive event,0,0,0\n'


def notebook(extra=""):
    markers = ["landscape orientation", "audio recorder",
               "accel2_x[i] = acc_eventsgt2[i]['Linear Acceleration y (m/s^2)']",
               "accel2_y[i] = acc_eventsgt2[i]['Linear Acceleration x (m/s^2)']*-1",
               "accel2_z[i] = acc_eventsgt2[i]['Linear Acceleration z (m/s^2)']*-1", extra]
    return json.dumps({"cells": [{"source": markers, "cell_type": "code"}]}).encode()


class StreamFeasibilityTest(unittest.TestCase):
    def test_measured_seconds_preserve_cadence_and_only_emit_aggregates(self):
        times, summary = f.inspect_stream(stream(), "acceleration")
        self.assertEqual(801, len(times))
        self.assertEqual(100, summary["observed_mean_rate_hz"])
        self.assertEqual(.01, summary["maximum_gap_seconds"])
        self.assertFalse(summary["android_accuracy_or_flags_present"])
        self.assertNotIn("times", summary)
        self.assertNotIn("values", summary)
        _, even_summary = f.inspect_stream(stream(times=[0, .01, .03]), "acceleration")
        self.assertEqual(.015, even_summary["median_gap_seconds"])

    def test_time_rounding_is_explicit_and_not_clock_reconstruction(self):
        self.assertEqual((0, .5), f.time_nanos("0.0000000005"))
        self.assertEqual((2, .5), f.time_nanos("0.0000000015"))
        for invalid in ["NaN", "Infinity", "-1", "14401", "1e999999", "invalid"]:
            with self.subTest(invalid=invalid), self.assertRaises(f.InvalidSource):
                f.time_nanos(invalid)

    def test_bad_schema_nonfinite_truncated_and_ambiguous_clock_rejected(self):
        cases = [stream(times=[0, 0]), stream(times=[1, 0]), stream(times=[0]),
                 stream().replace(b"Time (s)", b"Milliseconds"),
                 stream().replace(b",1,", b",nan,", 1),
                 stream()+b"9,1,2\n"]
        for case in cases:
            with self.subTest(case=case[:50]), self.assertRaises(f.InvalidSource):
                f.inspect_stream(case, "acceleration")

    def test_brackets_enforce_gap_bound_and_record_actual_lookahead(self):
        self.assertEqual((True, 0, True), f.supported_target([0, 10, 20], 10))
        self.assertEqual((True, 5, False), f.supported_target([0, 10, 20], 15))
        self.assertEqual((False, 0, False), f.supported_target([0, 50_000_001], 10))
        self.assertEqual((False, 0, False), f.supported_target([1, 2], 3))

    def test_timing_feasibility_never_fabricates_native_quality_or_normal_labels(self):
        times, _ = f.inspect_stream(stream(), "acceleration")
        summary = f.inspect_timing_and_labels(times, times, labels())
        self.assertEqual(3, summary["timing_only_supported_windows"])
        self.assertEqual({"0": 1}, summary["fully_label_contained_timing_windows_by_publisher_target"])
        self.assertEqual(0, summary["native_admitted_windows"])
        self.assertEqual("not_assessed_missing_source_semantics", summary["native_eligibility"])
        self.assertEqual(6, summary["label_summary"]["annotated_nonaggressive_seconds"])
        self.assertFalse(summary["label_clock_alignment_independently_verified"])
        self.assertNotIn("normal", summary)

    def test_oversized_dropout_and_short_labels_remain_visible(self):
        times, _ = f.inspect_stream(stream(times=[i/100 for i in range(801) if not 390 <= i <= 410]), "acceleration")
        short = b'start,end,event,target,timesync,sample\n1,2,aggressive braking,4,0,0\n'
        summary = f.inspect_timing_and_labels(times, times, short)
        self.assertEqual(0, summary["timing_only_supported_windows"])
        self.assertEqual(3, summary["windows_crossing_oversized_gap"])
        self.assertEqual(1, summary["label_intervals_shorter_than_six_seconds"])

    def test_notebook_source_is_never_executed_and_plot_reflection_is_not_a_mount(self):
        data = notebook("raise RuntimeError('private-identifier')")
        result = f.inspect_notebook(data)
        self.assertFalse(result["executed"])
        self.assertEqual(-1, result["plot_mapping_determinant"])
        self.assertFalse(result["plot_mapping_applied"])
        self.assertNotIn("private-identifier", json.dumps(result))
        with self.assertRaises(f.InvalidSource):
            f.inspect_notebook(notebook().replace(b"accel2_z", b"different"))

    def test_offline_pins_preservation_admission_and_cli_privacy(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sources = {"Linear_Acceleration_2.csv": stream(), "Gyroscope_2.csv": stream("gyroscope"),
                       "Events_Extract_and_Visualization.ipynb": notebook()}
            profile = {"protocol_version": f.VERSION, "source": "generated fixture", "license": "fixture",
                       "files": [{"name": n, "bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()} for n, b in sources.items()]}
            for name, data in sources.items():
                (root/name).write_bytes(data)
            label = labels()
            (root/"Labeled_events_2.csv").write_bytes(label)
            profile_path = root/"profile.json"
            profile_path.write_text(json.dumps(profile))
            pins = {"Labeled_events_2.csv": (len(label), hashlib.sha256(label).hexdigest())}
            with mock.patch.object(f, "PROFILE", profile_path), mock.patch.object(f, "ZENODO", pins):
                result = f.qualify(root)
                self.assertFalse(result["production_admitted"])
                self.assertFalse(result["training_or_predictions"])
                self.assertFalse(result["native_tensor_created_from_public_data"])
                self.assertNotIn(str(root), json.dumps(result))
                for name, data in sources.items():
                    self.assertEqual(data, (root/name).read_bytes())
                (root/"Gyroscope_2.csv").write_bytes(b"changed")
                with self.assertRaises(f.InvalidSource):
                    f.qualify(root)
            captured = io.StringIO()
            with mock.patch("sys.argv", ["probe", "--root", str(root/"private-home")]), contextlib.redirect_stderr(captured):
                self.assertEqual(2, f.main())
                self.assertNotIn("private-home", captured.getvalue())


if __name__ == "__main__":
    unittest.main()
