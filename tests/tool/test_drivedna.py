"""Embedding experiment contracts; generated values are not field style acceptance."""

import copy
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import torch

from ml import datasets as ds, drivedna as net, drivedna_corpus as corpus


class DriveDnaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = corpus.generate()
        cls.digest = ds.sha256(cls.raw)
        cls.bundle = json.loads(cls.raw)
        cls.training = [row for row in cls.bundle["cases"] if row["partition"] == "train"]
        cls.small = [row for row in cls.training if row["group"] in ("style-profile-01", "style-profile-03") and
                     row["vehicle_scope"] == net.SPEC["vehicle_scopes"][0] and row["driving_context"] == net.SPEC["driving_contexts"][0]]
        # Train only a small subset for numeric plumbing; no full experiment or
        # validation model selection is performed by these regression tests.
        cls.model, cls.norm, cls.loss = net.fit(cls.small)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root/"source.json"
        self.source.write_bytes(self.raw)

    def test_source_generation_repeats_with_group_isolation_and_no_identity_features(self):
        self.assertEqual(self.raw, corpus.generate())
        parts = net.load_source(self.source, self.digest)
        self.assertEqual([len(rows) for rows in parts.values()], [200, 104, 104])
        groups = [{row["group"] for row in rows} for rows in parts.values()]
        self.assertFalse(groups[0] & groups[1] or groups[0] & groups[2] or groups[1] & groups[2])
        self.assertTrue(all(net.eligible(row) and row["category"] == "supported" for row in parts["train"]))
        self.assertEqual(len(net.SPEC["features"]), 8)
        self.assertFalse(any(word in name for name in net.SPEC["features"] for word in ("id", "maximum_speed", "latitude", "score")))
        self.assertEqual(len(net.paired_rows(parts["train"])), 100)

    def test_source_hash_contract_duplicate_scope_split_and_numbers_fail_closed(self):
        with self.assertRaises(ValueError): net.load_source(self.source, "0"*64)
        mutations = [lambda value: value.update(source_kind="recorded"),
                     lambda value: value["cases"].pop(),
                     lambda value: value["cases"][0].update(partition="test"),
                     lambda value: value["cases"][0].update(variant=True),
                     lambda value: value["cases"][0].update(vehicle_scope="private-car"),
                     lambda value: value["cases"][0].update(supported=False),
                     lambda value: value["cases"][0]["features"].__setitem__(0, -1),
                     lambda value: value["cases"][0]["features"].__setitem__(7, float("nan")),
                     lambda value: value["cases"][0]["features"].__setitem__(6, 1.01),
                     lambda value: value["cases"][0]["features"].__setitem__(1, True)]
        for mutation in mutations:
            value = copy.deepcopy(self.bundle)
            mutation(value)
            raw = json.dumps(value).encode()
            self.source.write_bytes(raw)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): net.load_source(self.source, ds.sha256(raw))
        raw = self.raw.replace(b'{', b'{"format":"duplicate",', 1)
        self.source.write_bytes(raw)
        with self.assertRaises(ValueError): net.load_source(self.source, ds.sha256(raw))

    def test_missing_unsupported_and_stationary_abstain_before_encoding(self):
        rows = [row for row in self.bundle["cases"] if row["category"] != "supported"]
        model = Mock(side_effect=AssertionError("ineligible input reached model"))
        self.assertEqual(net.representations(model, self.norm, rows, self.digest), {})
        self.assertEqual(net.representations(None, self.norm, rows, self.digest), {})
        model.encoder.assert_not_called()
        self.assertEqual(len(rows), 48)
        with self.assertRaises(ValueError): net.tensor(rows)
        boundary = copy.deepcopy(self.small[0])
        boundary["features"][6] = .9
        self.assertTrue(net.eligible(boundary))
        boundary["features"][6] = .900001
        self.assertFalse(net.eligible(boundary))

    def test_training_is_self_supervised_and_normalization_is_train_only(self):
        values = net.tensor(self.small)
        self.assertEqual(self.norm["mean"], values.mean(dim=0).tolist())
        self.assertEqual(self.norm["scale"], values.std(dim=0, unbiased=False).clamp_min(1e-6).tolist())
        self.assertEqual(sum(parameter.numel() for parameter in self.model.parameters()), 155)
        renamed = copy.deepcopy(self.small)
        for row in renamed:
            row.update(program="not-a-target", group="not-a-feature", id="not-a-feature", vehicle_scope="not-a-feature", driving_context="not-a-feature")
        other, norm, loss = net.fit(renamed)
        self.assertEqual(net.checkpoint(self.model, self.norm, self.digest), net.checkpoint(other, norm, self.digest))
        self.assertEqual(self.loss, loss)
        heldout = next(row for row in self.bundle["cases"] if row["partition"] == "validation")
        with self.assertRaises(ValueError): net.fit([heldout])
        with self.assertRaises(ValueError): net.fit([])

    def test_safe_checkpoint_repeats_and_replays_without_mutating_config(self):
        saved = net.checkpoint(self.model, self.norm, self.digest)
        restored, norm = net.restore(json.loads(ds.canonical_json(saved)))
        self.assertEqual(net.representations(self.model, self.norm, self.small, self.digest), net.representations(restored, norm, self.small, self.digest))
        saved["config"]["epochs"] = 999
        saved["normalizer"]["mean"][0] = 999
        self.assertEqual(net.CONFIG["epochs"], 200)
        self.assertEqual(self.norm, norm)
        with self.assertRaises(ValueError): net.restore(saved)

    def test_checkpoint_rejects_promotion_unknown_schema_and_nonfinite_weights(self):
        original = net.checkpoint(self.model, self.norm, self.digest)
        mutations = [lambda saved: saved.update(production_eligible=True),
                     lambda saved: saved.update(feature_schema="unknown"),
                     lambda saved: saved.update(manifest_sha256="0"*64),
                     lambda saved: saved["normalizer"].update(scale=[0.]*8),
                     lambda saved: saved["state"]["encoder.0.bias"]["values"].__setitem__(0, float("nan")),
                     lambda saved: saved["state"]["encoder.0.bias"].update(shape=[99])]
        for mutation in mutations:
            saved = copy.deepcopy(original)
            mutation(saved)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): net.restore(saved)

    def test_comparison_rejects_incompatible_weights_normalization_and_scopes(self):
        records = net.representations(self.model, self.norm, self.small, self.digest)
        left = records[self.small[0]["id"]]
        self.assertEqual(net.distance(left, left), 0)
        changes = dict(identity="0"*64, representation=net.SPEC["baseline_version"], feature_schema="unknown",
                       dataset_id="unknown", vehicle_scope=net.SPEC["vehicle_scopes"][1], driving_context=net.SPEC["driving_contexts"][1],
                       sensor_scope="different-sensors", mount_scope="different-mount", vector=[float("nan")]*3)
        for field, value in changes.items():
            with self.subTest(field=field), self.assertRaises(ValueError): net.distance(left, dict(left, **{field: value}))
        baseline = net.representations(None, self.norm, self.small, "1"*64)[self.small[0]["id"]]
        with self.assertRaises(ValueError): net.distance(left, baseline)
        changed_norm = copy.deepcopy(self.norm)
        changed_norm["mean"][0] += .1
        changed = net.representations(self.model, changed_norm, self.small, self.digest)[self.small[0]["id"]]
        with self.assertRaises(ValueError): net.distance(left, changed)
        changed_model = copy.deepcopy(self.model)
        with torch.no_grad(): changed_model.encoder[0].bias[0] += .1
        changed = net.representations(changed_model, self.norm, self.small, self.digest)[self.small[0]["id"]]
        with self.assertRaises(ValueError): net.distance(left, changed)

    def test_cutoff_uses_only_training_correspondence_and_nearest_rank(self):
        records = net.representations(None, self.norm, self.training, self.digest)
        cutoff = net.training_cutoff(self.training, records)
        distances = sorted(net.distance(records[a["id"]], records[b["id"]]) for a, b, _ in net.paired_rows(self.training))
        self.assertEqual(cutoff["pairs"], 100)
        self.assertEqual(cutoff["value"], distances[math.ceil(.95*100)-1]+1e-12)
        with self.assertRaises(ValueError): net.training_cutoff([dict(row, partition="test") for row in self.training], records)
        with self.assertRaises(ValueError): net.paired_rows(self.training[1:])
        with self.assertRaises(ValueError): net.paired_rows([row for row in self.training if row["variant"] == 2])

    def test_retrieval_ties_are_deterministic_and_heldout_anchors_are_rejected(self):
        anchors = copy.deepcopy(self.small)
        for row in anchors: row["features"] = [0.]*8
        records = net.representations(None, self.norm, anchors, self.digest)
        queries = [dict(row, partition="validation") for row in anchors]
        metric = net.retrieval(queries, anchors, records, records)
        self.assertEqual(metric, net.retrieval(list(reversed(queries)), list(reversed(anchors)), records, records))
        self.assertEqual(metric["top_1_hit_rate"], .2)
        with self.assertRaises(ValueError): net.retrieval(queries, queries, records, records)

    def comparison(self):
        def method(f1):
            rates = dict(stable_false_flag_rate=.05, changed_detection_rate=.8)
            return dict(retrieval=dict(macro_f1=f1, mean_reciprocal_rank=.9, per_program={label: {"recall": .8} for label in net.PROGRAMS}),
                        deviation=dict(overall=copy.deepcopy(rates), by_cohort={"cohort": copy.deepcopy(rates)}),
                        diagnostics={key: {"cases": 8, "abstentions": 8} for key in ("missing", "unsupported", "stationary")}, ineligible_inferred=0)
        return dict(embedding=method(.83), summary=method(.8))

    def test_material_gain_cannot_waive_retrieval_cohort_or_quality_regression(self):
        self.assertTrue(net.value_gate(self.comparison())["passed"])
        mutations = [lambda value: value["embedding"]["retrieval"].update(macro_f1=.81),
                     lambda value: value["embedding"]["retrieval"].update(mean_reciprocal_rank=.89),
                     lambda value: value["embedding"]["retrieval"]["per_program"][net.PROGRAMS[0]].update(recall=.79),
                     lambda value: value["embedding"]["deviation"]["by_cohort"]["cohort"].update(stable_false_flag_rate=.06),
                     lambda value: value["embedding"]["deviation"]["overall"].update(changed_detection_rate=.79),
                     lambda value: value["embedding"].update(ineligible_inferred=1)]
        for mutation in mutations:
            value = self.comparison()
            mutation(value)
            self.assertFalse(net.value_gate(value)["passed"])

    def test_failed_validation_never_predicts_test_and_results_never_overwrite(self):
        calls = []
        def evaluate(model, norm, training, rows, identities, cutoffs):
            calls.append({row["partition"] for row in rows})
            if calls[-1] != {"validation"}: self.fail("test opened after failed validation")
            result = self.comparison()
            result["embedding"]["retrieval"]["macro_f1"] = .8
            return result
        with patch.object(ds, "ROOT", self.root), patch.object(net, "fit", return_value=(self.model, self.norm, self.loss)), \
             patch.object(net, "evaluate", side_effect=evaluate), patch.object(net, "provenance", return_value={}):
            first = net.run(self.source, self.digest, "unit-one")
            second = net.run(self.source, self.digest, "unit-two")
            self.assertFalse(first["test"]["predictions_computed"])
            self.assertIsNone(first["test"]["metrics"])
            self.assertEqual(first, second)
            for name in ("checkpoint.json", "report.json"):
                self.assertEqual((self.root/"ml/checkpoints/unit-one"/name).read_bytes(), (self.root/"ml/checkpoints/unit-two"/name).read_bytes())
            with self.assertRaises(ValueError): net.run(self.source, self.digest, "unit-one")
        self.assertEqual(calls, [{"validation"}]*4)

    def test_passing_validation_opens_test_once_without_refit(self):
        calls = []
        def evaluate(model, norm, training, rows, identities, cutoffs):
            calls.append({row["partition"] for row in rows})
            return self.comparison()
        with patch.object(ds, "ROOT", self.root), patch.object(net, "fit", return_value=(self.model, self.norm, self.loss)) as fit, \
             patch.object(net, "evaluate", side_effect=evaluate), patch.object(net, "provenance", return_value={}):
            report = net.run(self.source, self.digest, "unit-passing")
            self.assertTrue(report["test"]["predictions_computed"])
            fit.assert_called_once()
        self.assertEqual(calls, [{"validation"}, {"test"}, {"validation"}])

    def test_generator_requires_explicit_destination_and_never_overwrites(self):
        with patch.object(ds, "ROOT", self.root):
            with self.assertRaises(ValueError): corpus.write_generated(self.root/"published.json")
            destination = self.root/".dart_tool/drivedna-fixtures-v1.json"
            self.assertEqual(corpus.write_generated(destination), self.digest)
            with self.assertRaises(ValueError): corpus.write_generated(destination)


if __name__ == "__main__":
    unittest.main()
