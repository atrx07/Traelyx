"""Strict private quarantine receipt with generated categorical labels only."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from ml import contributions as receipt, datasets as ds


def payload():
    return dict(receipt.HEADER, labels=[dict(detectedEvent=event, reportedLabel=choice, eventEngineVersion=1, telemetrySchemaVersion=1)
                                      for event in sorted(receipt.EVENTS) for choice in sorted(receipt.CHOICES)])


class ContributionTests(unittest.TestCase):
    def test_all_canonical_reports_are_unverified_and_quarantine_only(self):
        self.assertEqual(len(receipt.validate(ds.canonical_json(payload()))["labels"]), 50)
        self.assertEqual(payload()["trainingUse"], "quarantine_only")

    def test_identity_locations_times_raw_features_and_unknown_fields_fail(self):
        for key in ["tripId", "userId", "eventId", "latitude", "timestamp", "rawTelemetry", "features", "note"]:
            value = payload()
            value[key] = "private"
            with self.subTest(key=key), self.assertRaises(ValueError): receipt.validate(ds.canonical_json(value))
            value = payload()
            value["labels"][0][key] = "private"
            with self.assertRaises(ValueError): receipt.validate(ds.canonical_json(value))

    def test_false_consent_unsafe_promotion_and_numeric_type_coercion_fail(self):
        mutations = [lambda value: value.update(consentDeclared=False), lambda value: value.update(consentVersion=2),
                     lambda value: value.update(consentPurpose="account_signup"), lambda value: value.update(trainingUse="eligible"),
                     lambda value: value.update(containsPreciseLocation=True), lambda value: value.update(containsRawTelemetry=True),
                     lambda value: value.update(formatVersion=True), lambda value: value["labels"][0].update(eventEngineVersion=True),
                     lambda value: value["labels"][0].update(reportedLabel="crash_confirmed"),
                     lambda value: value["labels"][0].update(detectedEvent="unknown")]
        for mutate in mutations:
            value = payload()
            mutate(value)
            with self.subTest(mutate=mutate), self.assertRaises(ValueError): receipt.validate(ds.canonical_json(value))

    def test_empty_oversize_duplicate_and_malformed_sources_fail(self):
        for raw in [b"", b" "*65537, b"{", ds.canonical_json(dict(receipt.HEADER, labels=[])),
                    ds.canonical_json(dict(receipt.HEADER, labels=payload()["labels"]*3)),
                    ds.canonical_json(payload()).replace(b"{", b'{"formatVersion":1,', 1)]:
            with self.assertRaises(ValueError): receipt.validate(raw)

    def test_explicit_receipt_preserves_source_and_blocks_training_without_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root/"generated.json"
            raw = ds.canonical_json(payload())
            source.write_bytes(raw)
            digest = ds.sha256(raw)
            with patch.object(ds, "ROOT", root):
                with self.assertRaises(ValueError): receipt.receive(source, digest)
                self.assertFalse((root/"ml").exists())
                with self.assertRaises(ValueError): receipt.receive(source, "0"*64, True)
                manifest = receipt.receive(source, digest, True)
                target = root/"ml/data/private/contributions"/digest
                self.assertEqual((target/"contribution.json").read_bytes(), raw)
                self.assertEqual(json.loads((target/"manifest.json").read_bytes()), manifest)
                self.assertFalse(manifest["model_training_eligible"])
                self.assertEqual(manifest["training_use"], "blocked")
                self.assertEqual(manifest["identity_grouping"], "unavailable")
                self.assertNotIn(str(root), json.dumps(manifest))
                with self.assertRaises(ValueError): receipt.receive(source, digest, True)

    def test_receipts_repeat_byte_identically_in_separate_private_roots(self):
        outputs = []
        for _ in range(2):
            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                source = root/"fixture.json"
                raw = ds.canonical_json(copy.deepcopy(payload()))
                source.write_bytes(raw)
                with patch.object(ds, "ROOT", root):
                    receipt.receive(source, ds.sha256(raw), True)
                target = root/"ml/data/private/contributions"/ds.sha256(raw)
                outputs.append([(target/name).read_bytes() for name in ("contribution.json", "manifest.json")])
        self.assertEqual(*outputs)


if __name__ == "__main__":
    unittest.main()
