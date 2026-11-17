import contextlib
import copy
from fractions import Fraction
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from tool import check_sync_pilot as q
from tool import verify_sync_pilot_apk as apk_check

BASE = 9_500_000_000_000_001
DIGEST = "a"*64


def fixture():
    rows = [{"sequence": i+1, "token": f"M{i+1:04}", "draw_before_ns": BASE+i*1_000_100_000,
             "draw_after_ns": BASE+i*1_000_100_000+1000} for i in range(8)]
    journal = {"version": "traelyx.sync-marker.v1", "clock": "elapsedRealtimeNanos",
               "session_alias": "00000000-0000-0000-0000-000000000001",
               "measurement": "software_canvas_draw_not_photon_presentation",
               "presentation_delay_bound_ns": None, "reference_alignment_verified": False,
               "stopped": True, "stop_reason": "user", "markers": rows}
    obs = {"version": "traelyx.sync-observations.v1", "journal_sha256": DIGEST,
           "reference_sha256": "b"*64, "reference_kind": "generated",
           "native_start_ns": rows[1]["draw_before_ns"]+100_000_000,
           "native_end_ns": rows[6]["draw_before_ns"]-100_000_000,
           "maximum_error_ns": 50_000_000, "maximum_rate_error_ppm": 200,
           "presentation_delay_bound_ns": 0, "presentation_evidence_sha256": "c"*64,
           "reference_latency_bound_ns": 0, "reference_latency_evidence_sha256": "d"*64,
           "same_boot_evidence_sha256": None,
           "anchors": [{"sequence": i+1, "role": "fit" if i in (0, 7) else "check",
                        "reference_before_ns": i*1_000_000_000,
                        "reference_after_ns": i*1_000_000_000} for i in (0, 1, 6, 7)]}
    return journal, obs


class SyncPilotTest(unittest.TestCase):
    def test_exact_large_boot_clock_and_one_hundred_ppm(self):
        journal, obs = fixture()
        summary, private = q.audit(journal, obs, DIGEST)
        self.assertEqual(private["native_ns_per_reference_ns"], q.ratio(Fraction(10001, 10000)))
        self.assertEqual(private["native_offset_ns"], q.ratio(Fraction(BASE+500)))
        self.assertEqual(summary["maximum_software_check_residual_ns"], 0)
        self.assertEqual(summary["maximum_checked_error_under_declared_bounds_ns"], 500)
        self.assertEqual(summary["rate_error_ppm_ceiling"], 100)
        self.assertTrue(summary["declared_check_budget_satisfied"])
        for field in ["physical_alignment_verified", "recording_binding_verified", "between_anchor_error_bound_verified",
                      "reference_artifact_verified", "training_admitted", "model_accepted"]:
            self.assertFalse(summary[field])
        self.assertNotIn(str(BASE), json.dumps(summary))
        self.assertNotIn(journal["session_alias"], json.dumps(summary))

    def test_check_anchors_do_not_fit_and_error_budget_can_fail(self):
        journal, obs = fixture()
        obs["anchors"][1]["reference_before_ns"] += 100_000_000
        obs["anchors"][1]["reference_after_ns"] += 100_000_000
        summary, private = q.audit(journal, obs, DIGEST)
        self.assertEqual(private["native_ns_per_reference_ns"], q.ratio(Fraction(10001, 10000)))
        self.assertFalse(summary["declared_check_budget_satisfied"])
        self.assertIn("declared_check_error_exceeds_budget", summary["blockers"])

    def test_unknown_physical_and_camera_delay_stays_unknown(self):
        journal, obs = fixture()
        for key in ["presentation_delay_bound_ns", "presentation_evidence_sha256",
                    "reference_latency_bound_ns", "reference_latency_evidence_sha256"]:
            obs[key] = None
        summary, _ = q.audit(journal, obs, DIGEST)
        self.assertIsNone(summary["maximum_checked_error_under_declared_bounds_ns"])
        self.assertFalse(summary["declared_check_budget_satisfied"])
        self.assertEqual(len(summary["blockers"]), 3)

    def test_uncertainty_includes_video_bracket_draw_and_declared_delays(self):
        journal, obs = fixture()
        obs.update(reference_kind="video_pts", presentation_delay_bound_ns=2_000_000,
                   reference_latency_bound_ns=3_000_000)
        for row in obs["anchors"]:
            row["reference_after_ns"] += 1_000_000
        summary, _ = q.audit(journal, obs, DIGEST)
        self.assertEqual(summary["maximum_checked_error_under_declared_bounds_ns"], 4_500_850)
        self.assertFalse(summary["physical_alignment_verified"])

    def test_clock_reset_incomplete_journal_and_forged_precision_rejected(self):
        for edit in [lambda j: j.update(stopped=False), lambda j: j.update(reference_alignment_verified=True),
                     lambda j: j.update(presentation_delay_bound_ns=0), lambda j: j.update(clock="wall_time"),
                     lambda j: j["markers"][1].update(draw_before_ns=BASE-1),
                     lambda j: j["markers"][0].update(sequence=True),
                     lambda j: j["markers"][0].update(draw_after_ns=BASE-1),
                     lambda j: j["markers"][0].update(draw_before_ns=1.0),
                     lambda j: j["markers"][0].update(token="M0099")]:
            journal, obs = fixture()
            edit(journal)
            with self.subTest(edit=edit), self.assertRaises(q.SyncInvalid): q.audit(journal, obs, DIGEST)

    def test_invalid_observation_structure_and_unknowns_fail_closed(self):
        for key, value in [("maximum_error_ns", 0), ("maximum_rate_error_ppm", True),
                           ("native_end_ns", -1), ("reference_kind", "guessed_wall_clock"),
                           ("reference_sha256", "private path"), ("presentation_evidence_sha256", None),
                           ("presentation_delay_bound_ns", -1), ("same_boot_evidence_sha256", "x")]:
            journal, obs = fixture(); obs[key] = value
            with self.subTest(key=key), self.assertRaises(q.SyncInvalid): q.audit(journal, obs, DIGEST)
        for edit in [lambda o: o["anchors"][0].update(role=[]),
                     lambda o: o["anchors"][1].update(sequence=1),
                     lambda o: o["anchors"][1].update(role="fit"),
                     lambda o: o["anchors"][0].update(reference_before_ns=True),
                     lambda o: o["anchors"][1].update(reference_after_ns=1),
                     lambda o: o["anchors"].reverse()]:
            journal, obs = fixture(); edit(obs)
            with self.subTest(edit=edit), self.assertRaises(q.SyncInvalid): q.audit(journal, obs, DIGEST)

    def test_no_extrapolation_and_clock_drift_bound(self):
        for key, value in [("native_start_ns", BASE), ("native_end_ns", BASE+9_000_000_000),
                           ("maximum_rate_error_ppm", 99)]:
            journal, obs = fixture(); obs[key] = value
            with self.subTest(key=key), self.assertRaises(q.SyncInvalid): q.audit(journal, obs, DIGEST)

    def test_inputs_are_not_mutated(self):
        journal, obs = fixture(); original = copy.deepcopy((journal, obs))
        q.audit(journal, obs, DIGEST)
        self.assertEqual((journal, obs), original)

    def test_bounded_pinned_json_rejects_corruption_duplicate_keys_and_nonfinite(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"input.json"
            for raw in [b'{"x":1,"x":2}', b'{"x":NaN}', b'{"x":Infinity}', b'\xff', b'{',
                        b'x'*(q.MAX_BYTES+1), b'{"x":'+b'9'*4500+b'}']:
                path.write_bytes(raw)
                with self.subTest(raw=raw[:20]), self.assertRaises(q.SyncInvalid):
                    q.read_pinned(path, hashlib.sha256(raw).hexdigest())
            path.write_text("{}")
            with self.assertRaisesRegex(q.SyncInvalid, "input_hash"): q.read_pinned(path, DIGEST)

    def test_private_map_is_opt_in_no_overwrite_and_errors_hide_paths(self):
        journal, obs = fixture()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); j = root/"private_journal.json"; o = root/"private_observations.json"
            j.write_text(json.dumps(journal)); obs["journal_sha256"] = hashlib.sha256(j.read_bytes()).hexdigest()
            o.write_text(json.dumps(obs)); private = root/"private_map.json"
            args = ["--journal", str(j), "--expected-journal-sha256", obs["journal_sha256"],
                    "--observations", str(o), "--expected-observations-sha256", hashlib.sha256(o.read_bytes()).hexdigest()]
            output = io.StringIO()
            with contextlib.redirect_stdout(output): self.assertEqual(q.main(args), 0)
            self.assertFalse(private.exists()); self.assertNotIn("private_journal", output.getvalue())
            with contextlib.redirect_stdout(io.StringIO()): self.assertEqual(q.main(args+["--private-map", str(private)]), 0)
            saved = private.read_bytes(); error = io.StringIO()
            with contextlib.redirect_stderr(error): self.assertEqual(q.main(args+["--private-map", str(private)]), 1)
            self.assertEqual(saved, private.read_bytes()); self.assertNotIn(folder, error.getvalue())
            self.assertNotIn(str(BASE), error.getvalue())


def manifest(extra=""):
    return f'''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{apk_check.PACKAGE}">
    <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/>{extra}
    <application android:allowBackup="false" android:usesCleartextTraffic="false">
    <activity android:name="{apk_check.PACKAGE}.PilotActivity" android:exported="true">
    <intent-filter><action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.LAUNCHER"/></intent-filter></activity>
    </application></manifest>'''


class PilotApkBoundaryTest(unittest.TestCase):
    def test_permissionless_packaged_boundary_and_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); apk = root/"generated.apk"; xml = root/"manifest.xml"
            with zipfile.ZipFile(apk, "w") as archive: archive.writestr("classes.dex", b"generated-not-an-installable-apk")
            xml.write_text(manifest())
            self.assertEqual(apk_check.verify(apk, xml)["permissions"], [])
            for source in [manifest('<uses-permission android:name="android.permission.INTERNET"/>'),
                           manifest().replace('</application>', '<service android:name="evil"/></application>'),
                           manifest().replace('allowBackup="false"', 'allowBackup="true"'),
                           manifest().replace('<application ', '<application android:name="UnexpectedApplication" '),
                           manifest().replace('android.intent.action.MAIN', 'android.intent.action.VIEW'),
                           manifest().replace('minSdkVersion="24"', 'minSdkVersion="23"')]:
                xml.write_text(source)
                with self.assertRaises(ValueError): apk_check.verify(apk, xml)
            xml.write_text(manifest())
            with zipfile.ZipFile(apk, "a") as archive: archive.writestr("lib/arm64-v8a/runtime.so", b"x")
            with self.assertRaises(ValueError): apk_check.verify(apk, xml)


if __name__ == "__main__":
    unittest.main()
