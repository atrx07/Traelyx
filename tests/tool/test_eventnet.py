"""CPU-only synthetic plumbing tests; no public download or field metrics in CI."""

import copy
import csv
import io
import inspect
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import torch

from ml import datasets as ds
from ml import eventnet as net


def generated_source():
    """Match source shape with entirely generated values, not recorded data."""
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(["Class", "DriverID", "TaskID", "Hour", "Minute", "Second",
                     "GyroX", "GyroY", "GyroZ", "AccX", "AccY", "AccZ"])
    for task in range(1, 110):
        label, driver = (task - 1) % 4 + 1, (task - 1) % 3 + 1
        for index in range(10 if task < 109 else 34):
            writer.writerow([label, f"Driver-{driver}", task, 12, 34, index,
                             "0.0", "0.0", 2 if label == 2 else -2 if label == 3 else 0,
                             2 if label == 1 else -2 if label == 4 else 0, "0.0", "1.0"])
    return output.getvalue().encode()


class GroupedSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.entry = copy.deepcopy(next(entry for entry in ds.registry_entries() if entry["version"] == "3"))
        self.raw = generated_source()
        self.entry.update(source_sha256=ds.sha256(self.raw), source_bytes=len(self.raw))
        self.source = self.root / "source.csv"
        self.source.write_bytes(self.raw)
        self.registry = patch.object(ds, "registry_entries", return_value=[self.entry])
        self.registry.start()
        self.addCleanup(self.registry.stop)

    def imported(self):
        ds.import_dataset(self.entry, self.source, self.root / "out")
        return next((self.root / "out").iterdir())

    def test_v3_import_strips_clock_preserves_groups_and_coarse_elapsed(self):
        directory = self.imported()
        with (directory / "samples.csv").open() as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 1114)
        self.assertEqual(rows[0]["elapsed_ms"], "0")
        self.assertEqual(rows[1]["elapsed_ms"], "1000")
        self.assertEqual(rows[0]["ax"], "2")
        self.assertNotIn("Hour", rows[0])
        self.assertNotIn("DriverID", rows[0])
        self.assertEqual(len({row["trip_group"] for row in rows}), 109)
        self.assertEqual(ds.load_json(directory / "manifest.json")["training_use"], "experiment_only")

    def test_split_is_verified_before_one_window_per_task(self):
        partitions, _ = net.imported_windows(self.imported())
        self.assertEqual(sum(map(len, partitions.values())), 109)
        self.assertEqual({item["driver"] for item in partitions["test"]}, {"source-driver-3"})
        self.assertEqual({item["driver"] for item in partitions["train"]}, {"source-driver-1"})
        self.assertTrue(all(len(item["values"]) == 7 for rows in partitions.values() for item in rows))
        self.assertEqual({item["task"] for item in partitions["train"]} &
                         {item["task"] for item in partitions["test"]}, set())

    def test_source_v3_rejects_bad_clock_driver_label_and_population(self):
        for old, new in [(b"12,34,1,", b"12,34,99,"), (b"Driver-1", b"Driver-9"),
                         (b"1,Driver-1,1,", b"9,Driver-1,1,"),
                         (b"12,34,1,", b"12,34,0,")]:
            changed = self.raw.replace(old, new, 1)
            if old == b"12,34,1," and new == b"12,34,0,":
                # Duplicate seconds are supported, not invented as subsecond time.
                self.assertEqual(len(list(ds.parse_rows(self.entry, changed))), 1114)
            else:
                with self.assertRaises(ds.InvalidDataset):
                    list(ds.parse_rows(self.entry, changed))
        with self.assertRaises(ds.InvalidDataset):
            list(ds.parse_rows(self.entry, self.raw.rsplit(b"\n", 2)[0] + b"\n"))
        changed = self.raw.replace(b"12,34,2,", b"12,34,0,", 1)
        with self.assertRaisesRegex(ds.InvalidDataset, "reversal"):
            list(ds.parse_rows(self.entry, changed))

    def test_experiment_permission_cannot_become_production_permission(self):
        for key, value in [("training_use", "production"), ("training_use", "synthetic_only"),
                           ("groups", {**self.entry["groups"], "source-driver-3": "train"}),
                           ("unit_status", "verified"), ("window_policy", "random_rows")]:
            entry = copy.deepcopy(self.entry)
            entry[key] = value
            with self.subTest(key=key), self.assertRaises(ds.InvalidDataset):
                ds.validate_entry(entry)

    def test_corruption_is_rejected_before_training(self):
        directory = self.imported()
        samples = directory / "samples.csv"
        samples.write_bytes(samples.read_bytes() + b"\n")
        with self.assertRaisesRegex(ds.InvalidDataset, "digest"):
            net.imported_windows(directory)

    def test_forged_partition_rejected_even_with_updated_samples_hash(self):
        directory = self.imported()
        samples = directory / "samples.csv"
        data = samples.read_bytes().replace(b",test,", b",train,", 1)
        samples.write_bytes(data)
        manifest_path = directory / "manifest.json"
        manifest = ds.load_json(manifest_path)
        manifest["samples_sha256"] = ds.sha256(data)
        manifest_path.write_bytes(ds.canonical_json(manifest))
        with self.assertRaisesRegex(ds.InvalidDataset, "leakage"):
            net.imported_windows(directory)

    def test_v1_quarantine_and_synthetic_sources_are_not_accepted(self):
        directory = self.imported()
        path = directory / "manifest.json"
        manifest = ds.load_json(path)
        manifest["registry_entry"]["version"] = "2"
        path.write_bytes(ds.canonical_json(manifest))
        with self.assertRaisesRegex(ds.InvalidDataset, "registry"):
            net.imported_windows(directory)

    def test_end_to_end_report_hashes_and_refuses_repeat_before_training(self):
        directory = self.imported()
        with patch.object(ds, "ROOT", self.root), patch.object(net, "code_provenance", return_value={
                "training_code_commit": "synthetic-test", "training_source_dirty": False}):
            report = net.run(directory, "generated-smoke")
            result = self.root / "ml/checkpoints/generated-smoke"
            weights = (result / "checkpoint.json").read_bytes()
            before = (result / "report.json").read_bytes()
            self.assertEqual(report["model_sha256"], ds.sha256(weights))
            self.assertFalse(report["production_eligible"])
            self.assertNotIn(str(self.root), before.decode())
            self.assertEqual(sum(report["partition_examples"].values()), 109)
            net.restore(json.loads(weights))
            with patch.object(net, "fit") as training:
                with self.assertRaisesRegex(ds.InvalidDataset, "already exists"):
                    net.run(directory, "generated-smoke")
                training.assert_not_called()
            self.assertEqual((result / "report.json").read_bytes(), before)


class ModelTests(unittest.TestCase):
    def setUp(self):
        torch.set_num_threads(1)
        torch.manual_seed(123)

    def rows(self):
        rows = []
        for label in range(4):
            for variant in range(3):
                value = [0.0] * 6
                value[label] = 2 + variant / 10
                rows.append({"label": label, "values": [value[:] for _ in range(7)]})
        return rows

    def test_tcn_shape_and_causal_prefix(self):
        model = net.EventNet().eval()
        original = torch.randn(2, 6, 7)
        changed = original.clone()
        changed[:, :, 4:] += 100
        with torch.no_grad():
            self.assertTrue(torch.equal(model.encode(original)[:, :, :4], model.encode(changed)[:, :, :4]))
            probabilities = model(original).softmax(dim=1)
        self.assertEqual(probabilities.shape, (2, 4))
        self.assertTrue(torch.allclose(probabilities.sum(dim=1), torch.ones(2)))

    def test_normalizer_uses_train_and_handles_constant_channel(self):
        train = torch.zeros(2, 6, 7)
        train[:, 0, :] = 3
        normalizer = net.fit_normalizer(train)
        self.assertEqual(normalizer["mean"][0][0], [3.0])
        self.assertTrue(bool(torch.isfinite(net.normalize(train, normalizer)).all()))
        net.normalize(torch.full((2, 6, 7), 999.0), normalizer)
        self.assertEqual(normalizer, net.fit_normalizer(train))
        self.assertNotIn("test", inspect.signature(net.fit).parameters)

    def test_training_learns_and_checkpoint_selection_is_validation_only(self):
        model, normalizer, selection = net.fit(self.rows(), self.rows())
        history = selection["history"]
        self.assertLess(history[-1]["train_loss"], history[0]["train_loss"] - 0.1)
        expected = min(history, key=lambda row: row["validation_loss"])["epoch"]
        self.assertEqual(selection["selected_epoch"], expected)
        self.assertEqual(len(history), net.CONFIG["epochs"])
        self.assertIsInstance(net.checkpoint(model, normalizer), dict)

    def test_fixed_environment_training_is_byte_reproducible(self):
        first = net.fit(self.rows(), self.rows())
        second = net.fit(self.rows(), self.rows())
        self.assertEqual(ds.canonical_json(net.checkpoint(*first[:2])),
                         ds.canonical_json(net.checkpoint(*second[:2])))
        self.assertEqual(first[2], second[2])

    def test_safe_json_checkpoint_roundtrip_preserves_predictions(self):
        model, normalizer, _ = net.fit(self.rows(), self.rows())
        serialized = ds.canonical_json(net.checkpoint(model, normalizer))
        restored, reloaded_normalizer = net.restore(json.loads(serialized))
        inputs, _ = net.tensors(self.rows())
        with torch.no_grad():
            self.assertTrue(torch.equal(model(net.normalize(inputs, normalizer)),
                                        restored(net.normalize(inputs, reloaded_normalizer))))

    def test_checkpoint_rejects_contract_shape_nan_and_scale_changes(self):
        value = net.checkpoint(net.EventNet(), net.fit_normalizer(torch.ones(2, 6, 7)))
        for change in ("version", "shape", "nan", "scale", "parameter"):
            candidate = copy.deepcopy(value)
            if change == "version":
                candidate["feature_schema"] = "unknown"
            elif change == "shape":
                candidate["state"]["project.weight"] = [1.0]
            elif change == "nan":
                candidate["state"]["project.weight"][0][0][0] = float("nan")
            elif change == "scale":
                candidate["normalizer"]["scale"][0][0][0] = 0.0
            else:
                del candidate["state"]["project.weight"]
            with self.subTest(change=change), self.assertRaises(ds.InvalidDataset):
                net.restore(candidate)

    def test_multiclass_metrics_match_hand_computed_confusion(self):
        values = [[0.8, 0.1, 0.05, 0.05], [0.7, 0.2, 0.05, 0.05],
                  [0.05, 0.05, 0.8, 0.1], [0.05, 0.05, 0.1, 0.8]]
        result = net.metrics([0, 1, 2, 3], values)
        self.assertEqual(result["confusion_matrix_true_rows"], [[1, 0, 0, 0], [1, 0, 0, 0],
                                                               [0, 0, 1, 0], [0, 0, 0, 1]])
        self.assertAlmostEqual(result["macro_f1"], (2 / 3 + 0 + 1 + 1) / 4)
        self.assertIsNone(result["false_severe_events_per_hour"])
        self.assertIsNone(result["detection_latency_ms"])
        self.assertEqual(result["probability_status"], "uncalibrated")

    def test_metrics_reject_invalid_probabilities(self):
        for values in ([], [[float("nan"), 0, 0, 1]], [[1, 1, 1, 1]], [[-1, 0, 1, 1]]):
            with self.assertRaises(ds.InvalidDataset):
                net.metrics([0], values)


if __name__ == "__main__":
    unittest.main()
