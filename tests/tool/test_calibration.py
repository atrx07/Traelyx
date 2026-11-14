"""Synthetic-only retrospective calibration audit tests; no field input in CI."""

import copy
import inspect
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import torch

from ml import calibration as cal
from ml import datasets as ds
from ml import eventnet as net
from tests.tool.test_eventnet import generated_source


class TemperatureTests(unittest.TestCase):
    def setUp(self):
        torch.set_num_threads(1)
        self.logits = torch.tensor([[8., 0, 0, 0], [0, 8., 0, 0], [0, 0, 8., 0], [0, 0, 0, 8.]] * 4)
        self.labels = torch.tensor([0, 0, 2, 1] * 4)

    def test_validation_fit_improves_objective_without_test_input(self):
        result = cal.fit_temperature(self.logits, self.labels)
        self.assertGreater(result["temperature"], 1)
        self.assertLess(result["validation_nll_after"], result["validation_nll_before"])
        self.assertEqual(list(inspect.signature(cal.fit_temperature).parameters),
                         ["validation_logits", "validation_labels"])

    def test_fixed_fit_and_input_tensors_are_unchanged(self):
        before = self.logits.clone()
        first = cal.fit_temperature(self.logits, self.labels)
        second = cal.fit_temperature(self.logits, self.labels)
        self.assertEqual(ds.canonical_json(first), ds.canonical_json(second))
        self.assertTrue(torch.equal(before, self.logits))

    def test_flat_logits_prefer_identity_and_cold_solution_is_bounded(self):
        flat = cal.fit_temperature(torch.zeros(16, 4), self.labels)
        self.assertEqual(flat["temperature"], 1)
        confident_correct = cal.fit_temperature(self.logits, torch.tensor([0, 1, 2, 3] * 4))
        self.assertGreaterEqual(confident_correct["temperature"], 0.1)
        self.assertLessEqual(confident_correct["temperature"], 100)
        self.assertLessEqual(confident_correct["validation_nll_after"], confident_correct["validation_nll_before"] + 1e-12)

    def test_invalid_temperature_and_nonfinite_or_bad_labels_rejected(self):
        for temperature in [0, -1, float("nan"), float("inf"), 10 ** 400, 0.001, True]:
            with self.subTest(temperature=temperature), self.assertRaises(ds.InvalidDataset):
                cal.nll(self.logits, self.labels, temperature)
        for logits, labels in [(torch.zeros(0, 4), torch.tensor([], dtype=torch.long)),
                               (torch.zeros(2, 3), torch.tensor([0, 1])),
                               (self.logits, self.labels.float()),
                               (self.logits, torch.tensor([4] * 16)),
                               (self.logits * float("nan"), self.labels)]:
            with self.assertRaises(ds.InvalidDataset):
                cal.fit_temperature(logits, labels)

    def test_stable_nll_does_not_clip_small_probabilities(self):
        logits = torch.tensor([[1000., -1000., 0, 0]])
        self.assertAlmostEqual(cal.nll(logits, torch.tensor([1]), 1), 2000.0)

    def test_scaling_keeps_confusion_and_f1_and_reports_disagreements(self):
        before = cal.evaluate(self.logits, self.labels, 1)
        after = cal.evaluate(self.logits, self.labels, 4)
        for field in ["confusion_matrix_true_rows", "per_class", "macro_f1", "source_label_errors"]:
            self.assertEqual(before[field], after[field])
        self.assertEqual(sum(row["disagreements"] for row in after["source_label_errors"].values()), 8)
        self.assertIsNone(after["false_severe_events_per_hour"])

    def test_reliability_boundaries_empty_bins_and_hand_calculated_ece(self):
        result = cal.reliability([0., 0.1, 0.5, 1.0], [0, 1, 1, 1])
        self.assertEqual([row["count"] for row in result["bins"]], [1, 1, 0, 0, 0, 1, 0, 0, 0, 1])
        self.assertAlmostEqual(result["ece"], (0 + 0.9 + 0.5 + 0) / 4)
        self.assertIsNone(result["bins"][2]["absolute_gap"])
        self.assertEqual(result["bins"][9]["mean_probability"], 1)

    def test_invalid_reliability_inputs_rejected(self):
        for probabilities, outcomes in [([], []), ([0.5], []), ([float("nan")], [1]),
                                       ([10 ** 400], [1]), ([-0.1], [0]), ([0.5], [True])]:
            with self.assertRaises(ds.InvalidDataset):
                cal.reliability(probabilities, outcomes)


class AuditPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.entry = copy.deepcopy(next(entry for entry in ds.registry_entries() if entry["version"] == "3"))
        data = generated_source()
        self.entry.update(source_sha256=ds.sha256(data), source_bytes=len(data))
        source = self.root / "source.csv"
        source.write_bytes(data)
        ds.import_dataset(self.entry, source, self.root / "imports")
        self.imported = next((self.root / "imports").iterdir())
        manifest = ds.load_json(self.imported / "manifest.json")
        self.checkpoint = self.root / "baseline"
        self.checkpoint.mkdir()
        torch.manual_seed(123)
        self.model = net.EventNet()
        normalizer = {"mean": [[[0.0]] * 6], "scale": [[[1.0]] * 6]}
        self.weights = ds.canonical_json(net.checkpoint(self.model, normalizer))
        (self.checkpoint / "checkpoint.json").write_bytes(self.weights)
        (self.root / "frozen-source.txt").write_text("synthetic fixture source\n")
        baseline = {"model_version": net.MODEL_VERSION, "model_status": "experiment",
                    "production_eligible": False, "model_sha256": ds.sha256(self.weights),
                    "source_files_sha256": {"frozen-source.txt": ds.sha256((self.root / "frozen-source.txt").read_bytes())},
                    "training_code_commit": "synthetic-test", "import_manifest_sha256": ds.sha256(ds.canonical_json(manifest)),
                    "dataset_id": "generated-test", "dataset_version": "test-v1",
                    "dataset_source_sha256": ds.sha256(data), "dataset_license": "CC0-1.0",
                    "attribution": "Original generated test data; not field evidence.",
                    "class_names": self.entry["source_labels"],
                    "majority_baseline": {"class": "1"}, "limitations": ["Synthetic pipeline test only."]}
        path = self.root / "baseline.json"
        path.write_bytes(ds.canonical_json(baseline))
        for context in [patch.object(ds, "registry_entries", return_value=[self.entry]),
                        patch.object(ds, "ROOT", self.root), patch.object(cal, "BASELINE", path),
                        patch.object(cal, "provenance", return_value={"analysis_code_commit": "synthetic-test"})]:
            context.start()
            self.addCleanup(context.stop)

    def test_pipeline_preserves_weights_and_repeats_report_and_calibrator(self):
        first = cal.run(self.checkpoint, self.imported, "audit-one")
        second = cal.run(self.checkpoint, self.imported, "audit-two")
        self.assertEqual(first, second)
        for filename in ["report.json", "calibrator.json"]:
            self.assertEqual((self.root / "ml/checkpoints/audit-one" / filename).read_bytes(),
                             (self.root / "ml/checkpoints/audit-two" / filename).read_bytes())
        self.assertEqual((self.checkpoint / "checkpoint.json").read_bytes(), self.weights)
        self.assertFalse(first["production_eligible"])
        self.assertFalse(first["data_reuse"]["fresh_blinded_validation"])
        self.assertNotIn(str(self.root), ds.canonical_json(first).decode())

    def test_forged_checkpoint_or_source_and_changed_import_are_rejected(self):
        path = self.checkpoint / "checkpoint.json"
        path.write_bytes(self.weights + b"\n")
        with self.assertRaisesRegex(ds.InvalidDataset, "digest"):
            cal.run(self.checkpoint, self.imported, "corrupt")
        path.write_bytes(self.weights)
        source = self.root / "frozen-source.txt"
        source.write_text("modified")
        with self.assertRaisesRegex(ds.InvalidDataset, "source changed"):
            cal.run(self.checkpoint, self.imported, "source-change")
        source.write_text("synthetic fixture source\n")
        path = self.imported / "manifest.json"
        value = ds.load_json(path)
        value["additional_metadata"] = "changed"
        path.write_bytes(ds.canonical_json(value))
        with self.assertRaisesRegex(ds.InvalidDataset, "import manifest"):
            cal.run(self.checkpoint, self.imported, "import-change")

    def test_collision_rejected_before_fitting(self):
        cal.run(self.checkpoint, self.imported, "existing")
        with patch.object(cal, "fit_temperature") as fit:
            with self.assertRaisesRegex(ds.InvalidDataset, "already exists"):
                cal.run(self.checkpoint, self.imported, "existing")
            fit.assert_not_called()

    def test_test_logits_do_not_enter_fitting(self):
        original_fit = cal.fit_temperature
        examples = []
        partitions, _ = net.imported_windows(self.imported)
        validation_x, validation_y = net.tensors(partitions["validation"])
        with torch.no_grad():
            expected_logits = self.model(validation_x)
        def capture(logits, labels):
            examples.append(len(labels))
            self.assertTrue(torch.equal(logits, expected_logits))
            self.assertTrue(torch.equal(labels, validation_y))
            return original_fit(logits, labels)
        with patch.object(cal, "fit_temperature", side_effect=capture):
            report = cal.run(self.checkpoint, self.imported, "fit-observation")
        self.assertEqual(examples, [report["results"]["validation"]["before"]["examples"]])
        self.assertEqual(report["calibration"]["protocol"]["fit_partition"], "validation")


if __name__ == "__main__":
    unittest.main()
