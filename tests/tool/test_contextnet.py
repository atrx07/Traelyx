"""Context experiment plumbing and locked-test discipline, not field acceptance."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import torch

from ml import contextnet as net, contextnet_corpus as corpus, datasets as ds


class ContextNetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = corpus.generate()
        cls.bundle = json.loads(cls.raw)
        cls.digest = ds.sha256(cls.raw)
        cls.training = [row for row in cls.bundle["cases"] if row["partition"] == "train"]
        # Short, mixed-length training subset tests packing/normalization without
        # performing the full experiment or selecting a model/configuration.
        cls.small = [row for row in cls.training if row["group"] == "ctx-profile-01" and row["variant"] == 1 and row["duration_seconds"] in (30, 60)]
        cls.model, cls.norm, cls.loss = net.fit(cls.small)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source.json"
        self.source.write_bytes(self.raw)

    def changed_source(self, mutate):
        value = copy.deepcopy(self.bundle)
        mutate(value)
        raw = (json.dumps(value, allow_nan=True) + "\n").encode()
        self.source.write_bytes(raw)
        return ds.sha256(raw)

    def test_generator_repeats_and_groups_are_disjoint(self):
        self.assertEqual(self.raw, corpus.generate())
        parts = net.load_source(self.source, self.digest)
        self.assertEqual([len(rows) for rows in parts.values()], [150, 84, 84])
        groups = [{row["group"] for row in rows} for rows in parts.values()]
        self.assertFalse(groups[0] & groups[1] or groups[0] & groups[2] or groups[1] & groups[2])
        self.assertTrue(all(row["category"] == "labelled" for row in parts["train"]))
        self.assertEqual(sum(row["duration_seconds"] for row in parts["train"]), 10500)

    def test_hash_metadata_time_and_numeric_corruption_fail_closed(self):
        with self.assertRaises(ValueError): net.load_source(self.source, "0"*64)
        mutations = [lambda data: data.update(source_kind="recorded"),
                     lambda data: data["cases"].pop(),
                     lambda data: data["cases"][0].update(partition="test"),
                     lambda data: data["cases"][0].update(variant=True),
                     lambda data: data["cases"][0]["times_ms"].__setitem__(0, 501),
                     lambda data: data["cases"][0]["features"][0].__setitem__(0, -1),
                     lambda data: data["cases"][0]["features"][0].__setitem__(1, float("nan")),
                     lambda data: data["cases"][0]["features"][0].__setitem__(1, True),
                     lambda data: data["cases"][0]["supported"].__setitem__(0, False)]
        for mutation in mutations:
            digest = self.changed_source(mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): net.load_source(self.source, digest)
        duplicate = self.raw.replace(b'{', b'{"format":"duplicate",', 1)
        self.source.write_bytes(duplicate)
        with self.assertRaises(ValueError): net.load_source(self.source, ds.sha256(duplicate))

    def test_missing_quality_cannot_be_repaired_or_inferred(self):
        rows = [row for row in self.bundle["cases"] if row["category"].startswith("quality_")]
        model = Mock(side_effect=AssertionError("quality must not reach GRU"))
        self.assertEqual(net.predictions(model, self.norm, rows), {})
        for row in rows: self.assertIsNone(net.rule_prediction(row))
        def repair(data):
            row = next(row for row in data["cases"] if row["category"] == "quality_missing")
            row["features"][20] = [0.]*4
        with self.assertRaises(ValueError): net.load_source(self.source, self.changed_source(repair))

    def test_rules_identify_pure_programs_and_abstain_on_open_cases(self):
        for row in self.bundle["cases"]:
            expected = row["label"] if row["category"] == "labelled" else None
            with self.subTest(case=row["id"]): self.assertEqual(net.rule_prediction(row), expected)
        # Opposite signed abrupt episodes count even without a sub-threshold bin.
        row = copy.deepcopy(self.small[0])
        row["features"] = [[10., 0., 0., 4. if index % 2 else -4.] for index in range(30)]
        self.assertEqual(net.rule_prediction(row), "repeated_abrupt_transitions")

    def test_training_normalizes_valid_frames_without_padding_or_heldout(self):
        values = torch.cat(net.sequences(self.small))
        self.assertEqual(self.norm["mean"], values.mean(dim=0).tolist())
        self.assertEqual(self.norm["scale"], values.std(dim=0, unbiased=False).clamp_min(1e-6).tolist())
        self.assertEqual(self.loss["valid_frames"], 450)
        self.assertEqual(sum(value.numel() for value in self.model.parameters()), 381)
        heldout = next(row for row in self.bundle["cases"] if row["partition"] == "test")
        with self.assertRaises(ValueError): net.fit([heldout])
        with self.assertRaises(ValueError): net.fit([])
        quality = next(row for row in self.bundle["cases"] if row["category"] == "quality_missing")
        with self.assertRaises(ValueError): net.fit([dict(quality, partition="train", category="labelled")])

    def test_packed_state_does_not_consume_padding(self):
        values, lengths = net.batch(self.small, self.norm)
        changed = values.clone()
        for index, length in enumerate(lengths): changed[index, length:] = 10000.
        with torch.inference_mode():
            self.assertTrue(torch.equal(self.model(values, lengths), self.model(changed, lengths)))
            single, single_length = net.batch([self.small[0]], self.norm)
            self.assertTrue(torch.allclose(self.model(single, single_length)[0], self.model(values, lengths)[0], atol=1e-6))

    def test_training_and_json_checkpoint_repeat_without_pickle(self):
        other, norm, loss = net.fit(self.small)
        saved = net.checkpoint(self.model, self.norm, self.digest)
        self.assertEqual(saved, net.checkpoint(other, norm, self.digest))
        self.assertEqual(loss, self.loss)
        restored, restored_norm = net.restore(json.loads(ds.canonical_json(saved)))
        self.assertEqual(net.predictions(self.model, self.norm, self.small), net.predictions(restored, restored_norm, self.small))
        saved["config"]["epochs"] = 999
        saved["normalizer"]["mean"][0] = 999
        self.assertEqual(net.CONFIG["epochs"], 80)
        self.assertEqual(self.norm, norm)

    def test_checkpoint_rejects_promotion_schema_and_invalid_weights(self):
        original = net.checkpoint(self.model, self.norm, self.digest)
        mutations = [lambda saved: saved.update(production_eligible=True),
                     lambda saved: saved.update(feature_schema="unknown"),
                     lambda saved: saved.update(state={}),
                     lambda saved: saved["normalizer"].update(scale=[0.]*4),
                     lambda saved: saved["state"]["head.bias"]["values"].__setitem__(0, float("nan")),
                     lambda saved: saved["state"]["head.bias"].update(shape=[99])]
        for mutation in mutations:
            saved = copy.deepcopy(original)
            mutation(saved)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): net.restore(saved)

    def comparison(self):
        per_class = {label: {"recall": .8} for label in net.CLASSES}
        model = {"macro_f1": .83, "coverage": .9, "per_class": copy.deepcopy(per_class)}
        rule = {"macro_f1": .8, "coverage": .9, "per_class": copy.deepcopy(per_class)}
        diagnostics = {key: {"abstentions": 10 if key.startswith("quality_") else 2, "non_abstained": 0}
                       for key in ("quality_missing", "quality_unsupported", "open_stationary", "open_mixed")}
        return dict(model_selective=model, temporal_rules=rule, model_diagnostics=copy.deepcopy(diagnostics),
                    rule_diagnostics=diagnostics, quality_cases_inferred=0)

    def test_material_gain_alone_cannot_waive_other_gates(self):
        self.assertTrue(net.value_gate(self.comparison())["passed"])
        mutations = [lambda result: result["model_selective"].update(macro_f1=.81),
                     lambda result: result["model_selective"].update(coverage=.89),
                     lambda result: result["model_selective"]["per_class"][net.CLASSES[0]].update(recall=.79),
                     lambda result: result["model_diagnostics"]["open_mixed"].update(non_abstained=1),
                     lambda result: result.update(quality_cases_inferred=1)]
        for mutation in mutations:
            result = self.comparison()
            mutation(result)
            self.assertFalse(net.value_gate(result)["passed"])

    def test_failed_validation_never_evaluates_test_and_artifacts_never_overwrite(self):
        calls = []
        def evaluate(model, norm, rows):
            calls.append({row["partition"] for row in rows})
            if calls[-1] != {"validation"}: self.fail("test predictions opened on validation failure")
            result = self.comparison()
            result["model_selective"]["macro_f1"] = .8
            return result
        with patch.object(ds, "ROOT", self.root), patch.object(net, "fit", return_value=(self.model, self.norm, self.loss)), \
             patch.object(net, "evaluate", side_effect=evaluate), patch.object(net, "provenance", return_value={}):
            first = net.run(self.source, self.digest, "unit-one")
            second = net.run(self.source, self.digest, "unit-two")
            self.assertFalse(first["test"]["predictions_computed"])
            self.assertIsNone(first["test"]["metrics"])
            self.assertEqual(first, second)
            for filename in ("checkpoint.json", "report.json"):
                self.assertEqual((self.root/"ml/checkpoints/unit-one"/filename).read_bytes(),
                                 (self.root/"ml/checkpoints/unit-two"/filename).read_bytes())
            with self.assertRaises(ValueError): net.run(self.source, self.digest, "unit-one")
        self.assertEqual(calls, [{"validation"}]*4)

    def test_generator_requires_explicit_ignored_destination_and_never_overwrites(self):
        with patch.object(ds, "ROOT", self.root):
            with self.assertRaises(ValueError): corpus.write_generated(self.root/"published.json")
            destination = self.root/".dart_tool/contextnet-fixtures-v1.json"
            self.assertEqual(corpus.write_generated(destination), self.digest)
            with self.assertRaises(ValueError): corpus.write_generated(destination)

    def test_passing_validation_opens_test_once_without_fitting_again(self):
        calls = []
        def evaluate(model, norm, rows):
            calls.append({row["partition"] for row in rows})
            return self.comparison()
        with patch.object(ds, "ROOT", self.root), patch.object(net, "fit", return_value=(self.model, self.norm, self.loss)) as fit, \
             patch.object(net, "evaluate", side_effect=evaluate), patch.object(net, "provenance", return_value={}):
            report = net.run(self.source, self.digest, "unit-passing-path")
            self.assertTrue(report["test"]["predictions_computed"])
            self.assertTrue(report["test"]["value_gate"]["passed"])
            fit.assert_called_once()
        self.assertEqual(calls, [{"validation"}, {"test"}, {"validation"}])


if __name__ == "__main__":
    unittest.main()
