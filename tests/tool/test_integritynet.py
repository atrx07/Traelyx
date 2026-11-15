"""Generated numeric plumbing tests; native-export comparison is a separate CI gate."""

import copy
import csv
import io
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import torch

from ml import datasets as ds, integritynet as net


def generated_source():
    """Generated unit values; never field data or the native comparison's performance evidence."""
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=net.HEADER, lineterminator="\n")
    writer.writeheader()
    for group, partition in net.SPEC["groups"].items():
        scenarios = net.SPEC["clean_scenarios"] + ([] if partition == "train" else list(net.SPEC["extra_categories"]))
        for index, scenario in enumerate(scenarios):
            category = "clean" if scenario in net.SPEC["clean_scenarios"] else net.SPEC["extra_categories"][scenario]
            corrupt = category == "corruption"
            rules = ["INT_RAW_TRIP_INVALID"] if corrupt else ["INT_GNSS_SOURCE_SPEED_IMPLAUSIBLE"] if category == "numeric_inconsistency" else []
            kinds = sorted({net.SPEC["rule_kinds"][rule] for rule in rules})
            row = dict(case_id=f"{group}-{scenario.lower()}", profile=group, partition=partition,
                       scenario=scenario, category=category, decoder="rejected" if corrupt else "valid",
                       corpus_version="1", integrity_version="1", baseline_state="UNRANKED" if corrupt else "QUESTIONABLE" if rules else "VERIFIED",
                       baseline_kinds="|".join(kinds), baseline_rules="|".join(rules))
            row.update({name: "" if corrupt else (index + 1) * (feature + 1) * .01 + int(group[-2:]) * .0001
                        for feature, name in enumerate(net.FEATURES)})
            writer.writerow(row)
    return stream.getvalue().encode()


class IntegrityNetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.raw = generated_source()
        self.source = self.root / "unit.csv"
        self.source.write_bytes(self.raw)
        self.digest = ds.sha256(self.raw)
        self.parts = net.load_source(self.source, self.digest)

    def test_native_shape_contract_and_fictional_group_isolation(self):
        self.assertEqual([len(rows) for rows in self.parts.values()], [40, 32, 32])
        groups = [{row["group"] for row in rows} for rows in self.parts.values()]
        self.assertFalse(groups[0] & groups[1] or groups[0] & groups[2] or groups[1] & groups[2])
        self.assertTrue(all(row["category"] == "clean" for row in self.parts["train"]))
        self.assertEqual(sum(row["features"] is None for row in self.parts["test"]), 4)

    def test_digest_duplicate_count_split_and_label_corruption_fail_closed(self):
        for changed in [self.raw + b"\n", self.raw.replace(b",test,", b",train,", 1),
                        self.raw.replace(b",clean,valid,", b",numeric_inconsistency,valid,", 1),
                        self.raw.rsplit(b"\n", 2)[0] + b"\n"]:
            self.source.write_bytes(changed)
            with self.assertRaises(ValueError): net.load_source(self.source, self.digest)
            if changed != self.raw + b"\n":
                with self.assertRaises(ValueError): net.load_source(self.source, ds.sha256(changed))

    def test_numeric_and_baseline_semantics_cannot_be_reinterpreted(self):
        rows = list(csv.DictReader(io.StringIO(self.raw.decode())))
        for key, value in [(net.FEATURES[0], "nan"), (net.FEATURES[0], "-1"),
                           ("baseline_state", "UNRANKED"), ("baseline_rules", "unknown-rule")]:
            changed = copy.deepcopy(rows)
            changed[0][key] = value
            stream = io.StringIO(newline="")
            writer = csv.DictWriter(stream, fieldnames=net.HEADER, lineterminator="\n")
            writer.writeheader()
            writer.writerows(changed)
            raw = stream.getvalue().encode()
            self.source.write_bytes(raw)
            with self.subTest(key=key), self.assertRaises(ValueError): net.load_source(self.source, ds.sha256(raw))

    def test_training_admission_and_train_only_normalization(self):
        model, normalizer, _ = net.fit(self.parts["train"])
        values = net.tensor(self.parts["train"])
        self.assertEqual(normalizer["mean"], values.mean(dim=0).tolist())
        self.assertEqual(normalizer["scale"], values.std(dim=0, unbiased=False).clamp_min(1e-6).tolist())
        self.assertEqual(sum(parameter.numel() for parameter in model.parameters()), 98)
        with self.assertRaises(ds.InvalidDataset): net.fit(self.parts["test"])
        bad = copy.deepcopy(self.parts["train"])
        bad[0]["features"][0] = True
        with self.assertRaises(ds.InvalidDataset): net.fit(bad)

    def test_fixed_training_and_safe_checkpoint_roundtrip_are_reproducible(self):
        model, normalizer, first = net.fit(self.parts["train"])
        second, other_norm, other_loss = net.fit(self.parts["train"])
        threshold = net.threshold_from_validation_clean([1., 2., 3., 4.])
        saved = net.checkpoint(model, normalizer, threshold, self.digest)
        self.assertEqual(ds.canonical_json(saved), ds.canonical_json(net.checkpoint(second, other_norm, threshold, self.digest)))
        self.assertEqual(first, other_loss)
        restored, norm, limit = net.restore(json.loads(ds.canonical_json(saved)))
        self.assertEqual(net.scores(model, normalizer, self.parts["train"]), net.scores(restored, norm, self.parts["train"]))
        self.assertEqual(threshold, limit)
        for malformed in [dict(saved, production_eligible=True), dict(saved, threshold=float("nan")),
                          dict(saved, normalizer={"mean": [0]*8, "scale": [0]*8}), dict(saved, state={})]:
            with self.assertRaises((ValueError, TypeError)): net.restore(malformed)

    def test_threshold_is_frozen_clean_quantile_and_invalid_scores_fail(self):
        self.assertAlmostEqual(net.threshold_from_validation_clean([4, 1, 3, 2]), 4 + 1e-12)
        for scores in [[], [math.nan], [math.inf], [-1], [True]]:
            with self.assertRaises(ds.InvalidDataset): net.threshold_from_validation_clean(scores)

    def test_checkpoint_metadata_cannot_mutate_frozen_configuration(self):
        norm = {"mean": [0.] * 8, "scale": [1.] * 8}
        saved = net.checkpoint(net.IntegrityNet(), norm, 1., self.digest)
        saved["config"]["epochs"] = 999
        saved["normalizer"]["mean"][0] = 999
        self.assertEqual(net.CONFIG["epochs"], 200)
        self.assertEqual(norm["mean"][0], 0.)
        with self.assertRaises(ds.InvalidDataset): net.restore(saved)

    def test_decoder_corruption_abstains_and_finding_kinds_remain_separate(self):
        model, norm, _ = net.fit(self.parts["train"])
        compared = net.evaluate(model, norm, self.parts["test"], 1.0)
        self.assertEqual(compared["decoder_abstentions"], 4)
        corrupt = compared["by_category"]["corruption"]
        self.assertEqual(corrupt["model_evaluated"], 0)
        self.assertEqual(corrupt["native_findings_by_kind"]["DATA_CORRUPTION"], 4)
        self.assertEqual(compared["native_inconsistency_baseline"]["numeric_injection_detections"], 6)

    def test_added_value_requires_strict_gain_without_regression(self):
        comparison = {"model": {"synthetic_clean_false_flag_rate": 0., "numeric_injection_detection_rate": 1.},
                      "native_inconsistency_baseline": {"synthetic_clean_false_flag_rate": 0., "numeric_injection_detection_rate": .5}}
        self.assertTrue(net.generated_added_value(comparison))
        comparison["model"]["synthetic_clean_false_flag_rate"] = .01
        self.assertFalse(net.generated_added_value(comparison))
        comparison["model"] = comparison["native_inconsistency_baseline"].copy()
        self.assertFalse(net.generated_added_value(comparison))

    def test_heldout_changes_cannot_change_weights_normalization_or_threshold(self):
        model, norm, _ = net.fit(self.parts["train"])
        clean = [row for row in self.parts["validation"] if row["category"] == "clean"]
        threshold = net.threshold_from_validation_clean(net.scores(model, norm, clean))
        weights = ds.canonical_json(net.checkpoint(model, norm, threshold, self.digest))
        for row in self.parts["test"]:
            if row["features"] is not None: row["features"] = [999.] * 8
        for row in self.parts["validation"]:
            if row["category"] != "clean" and row["features"] is not None: row["features"] = [999.] * 8
        repeated, repeated_norm, _ = net.fit(self.parts["train"])
        repeated_threshold = net.threshold_from_validation_clean(net.scores(repeated, repeated_norm, clean))
        self.assertEqual(weights, ds.canonical_json(net.checkpoint(repeated, repeated_norm, repeated_threshold, self.digest)))

    def test_atomic_runs_refuse_overwrite_and_reports_keep_acceptance_unavailable(self):
        (self.root / "ml/checkpoints").mkdir(parents=True)
        with patch.object(ds, "ROOT", self.root), patch.object(net, "provenance", return_value={"training_source_dirty": False}):
            first = net.run(self.source, self.digest, "unit-one")
            second = net.run(self.source, self.digest, "unit-two")
            self.assertEqual(first, second)
            self.assertFalse(first["production_eligible"])
            self.assertIsNone(first["real_legitimate_drive_false_positive_rate"])
            self.assertIsNone(first["calibrated_anomaly_probability"])
            self.assertIsNone(first["mobile_runtime_metrics"])
            for name in ["checkpoint.json", "report.json"]:
                self.assertEqual((self.root/"ml/checkpoints/unit-one"/name).read_bytes(), (self.root/"ml/checkpoints/unit-two"/name).read_bytes())
            with self.assertRaises(ds.InvalidDataset): net.run(self.source, self.digest, "unit-one")


if __name__ == "__main__":
    unittest.main()
