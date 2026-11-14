"""Offline dataset provenance, hostile-input and reproducibility regression tests."""

import contextlib
import copy
import csv
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from ml import datasets as ds
from ml import synthetic_corpus


class DatasetTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.entries = {entry["source_kind"]: entry for entry in ds.registry_entries()
                        if entry["schema_version"] == 1}

    def public_source(self, data=None):
        # Generated values only; never read a downloaded or private fixture in CI.
        if data is None:
            data = (",".join(ds.PUBLIC_HEADER) + "\n1,180,0,-90,1.25,0,-0.98\n"
                    "4,0,2,0,-2.5,0,1.0\n").encode()
        path = self.root / "source.csv"
        path.write_bytes(data)
        entry = copy.deepcopy(self.entries["public"])
        entry["source_sha256"] = ds.sha256(data)
        entry["source_bytes"] = len(data)
        return entry, path

    def assert_rejected(self, entry, data, message):
        with self.assertRaisesRegex(ds.InvalidDataset, message):
            list(ds.parse_rows(entry, data))

    def test_registry_and_generated_source_are_pinned(self):
        self.assertEqual({(entry["dataset_id"], entry["version"]) for entry in ds.registry_entries()},
                         {("traelyx-smoke", "1"), ("mendeley-driving-behavior", "2"),
                          ("mendeley-driving-behavior", "3")})
        entry = self.entries["synthetic"]
        data = ds.source_bytes(entry, None)
        self.assertEqual(len(list(ds.parse_rows(entry, data))), 558)
        self.assertEqual(ds.sha256(data), entry["source_sha256"])

    def test_synthetic_import_is_byte_reproducible_and_group_separated(self):
        entry = self.entries["synthetic"]
        left, right = self.root / "left", self.root / "right"
        first = ds.import_dataset(entry, None, left)
        second = ds.import_dataset(entry, None, right)
        self.assertEqual(first, second)
        result_name = "traelyx-smoke--1--import-v1"
        for filename in ("samples.csv", "manifest.json"):
            self.assertEqual((left / result_name / filename).read_bytes(),
                             (right / result_name / filename).read_bytes())
        self.assertEqual(first["partition_counts"], {"train": 186, "validation": 186, "test": 186})
        with (left / result_name / "samples.csv").open(encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        partitions = {}
        for row in rows:
            partitions.setdefault(row["driver_group"], set()).add(row["partition"])
        self.assertEqual(partitions, {group: {partition} for group, partition in entry["groups"].items()})
        self.assertEqual(first["registry_entry_sha256"], ds.sha256(ds.canonical_json(entry)))
        self.assertEqual(first["samples_sha256"], ds.sha256((left / result_name / "samples.csv").read_bytes()))

    def test_public_import_preserves_units_labels_and_quarantines_every_row(self):
        entry, source = self.public_source()
        manifest = ds.import_dataset(entry, source, self.root / "out")
        self.assertEqual(manifest["training_use"], "blocked")
        self.assertEqual(manifest["partition_counts"], {"quarantine": 2})
        self.assertEqual(manifest["registry_entry"], entry)
        self.assertEqual(manifest["channels"]["gx"], "deg/s")
        result = next((self.root / "out").iterdir())
        with (result / "samples.csv").open(encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual([row["source_label"] for row in rows], ["1", "4"])
        self.assertEqual(rows[0]["gx"], "180")
        self.assertEqual(rows[0]["az"], "-0.98")
        self.assertTrue(all(row["driver_group"] == row["trip_group"] == row["elapsed_ms"] == "" for row in rows))
        self.assertNotIn(str(self.root), (result / "manifest.json").read_text())

    def test_hash_mismatch_never_publishes_output(self):
        entry, source = self.public_source()
        source.write_bytes(source.read_bytes().replace(b"180", b"181"))
        with self.assertRaisesRegex(ds.InvalidDataset, "SHA-256"):
            ds.import_dataset(entry, source, self.root / "out")
        self.assertFalse((self.root / "out").exists())

    def test_source_length_and_size_caps(self):
        entry, source = self.public_source()
        source.write_bytes(source.read_bytes() + b"\n")
        with self.assertRaisesRegex(ds.InvalidDataset, "length"):
            ds.source_bytes(entry, source)
        with patch.object(ds, "MAX_SOURCE_BYTES", 2):
            with self.assertRaisesRegex(ds.InvalidDataset, "size limit"):
                ds.source_bytes(entry, source)

    def test_damaged_last_row_cleans_staging(self):
        entry, source = self.public_source((",".join(ds.PUBLIC_HEADER) +
                                          "\n1,1,2,3,4,5,6\n4,broken\n").encode())
        with self.assertRaises(ds.InvalidDataset):
            ds.import_dataset(entry, source, self.root / "out")
        self.assertEqual(list((self.root / "out").iterdir()), [])

    def test_existing_import_is_never_overwritten(self):
        entry = self.entries["synthetic"]
        output = self.root / "out"
        ds.import_dataset(entry, None, output)
        before = {path.name: path.read_bytes() for path in next(output.iterdir()).iterdir()}
        with self.assertRaisesRegex(ds.InvalidDataset, "already exists"):
            ds.import_dataset(entry, None, output)
        self.assertEqual(before, {path.name: path.read_bytes() for path in next(output.iterdir()).iterdir()})

    def test_failure_to_publish_cleans_staging(self):
        with patch.object(ds.os, "rename", side_effect=OSError("private-path-must-not-print")):
            with self.assertRaises(OSError):
                ds.import_dataset(self.entries["synthetic"], None, self.root / "out")
        self.assertEqual(list((self.root / "out").iterdir()), [])

    def test_missing_and_wrong_source_kind(self):
        with self.assertRaisesRegex(ds.InvalidDataset, "explicit local"):
            ds.source_bytes(self.entries["public"], None)
        with self.assertRaisesRegex(ds.InvalidDataset, "not supplied"):
            ds.source_bytes(self.entries["synthetic"], self.root / "irrelevant")

    def test_headers_are_exact_privacy_allowlist(self):
        entry = self.entries["public"]
        for header in (ds.PUBLIC_HEADER + ["latitude"], ds.PUBLIC_HEADER[::-1],
                       ds.PUBLIC_HEADER[:-1] + ["device_id"], ds.PUBLIC_HEADER + ["AccX"]):
            with self.subTest(header=header):
                self.assert_rejected(entry, (",".join(header) + "\n").encode(), "columns")

    def test_numeric_labels_and_csv_fail_closed(self):
        entry = self.entries["public"]
        header = ",".join(ds.PUBLIC_HEADER) + "\n"
        for row in ("1,NaN,0,0,0,0,0", "1,inf,0,0,0,0,0", "1,1e999,0,0,0,0,0",
                    "1,=1+2,0,0,0,0,0", "5,0,0,0,0,0,0", "1,0,0,0,0,0",
                    "1,0,0,0,0,0,0,extra", '1,"unterminated', "1,0,0,0,0,0,\x00"):
            with self.subTest(row=row):
                self.assert_rejected(entry, (header + row + "\n").encode(), ".")
        self.assert_rejected(entry, b"\xff", "UTF-8")
        self.assert_rejected(entry, header.encode(), "empty")

    def test_row_and_field_limits(self):
        entry, source = self.public_source()
        with patch.object(ds, "MAX_ROWS", 1):
            self.assert_rejected(entry, source.read_bytes(), "row limit")
        self.assert_rejected(entry, (",".join(ds.PUBLIC_HEADER) + "\n1," + "0" * 129 +
                                     ",0,0,0,0,0\n").encode(), "field too long")

    def test_schema_rejects_bad_paths_types_privacy_and_promotion(self):
        entry = self.entries["synthetic"]
        changes = [("dataset_id", "../escape"), ("version", "../../outside"),
                   ("source_bytes", True), ("source_sha256", "not-a-hash"),
                   ("training_use", "production"), ("reported_rate_hz", float("inf")),
                   ("reported_rate_hz", 10 ** 400), ("source_bytes", 10 ** 400),
                   ("license", "unknown"), ("source_kind", "user_contribution"),
                   ("channels", {"ax": "m/s2"}),
                   ("channels", {**entry["channels"], "gx": "m/s2"}),
                   ("label_confidence", "unverified"),
                   ("label_provenance", "publisher_annotations"), ("unknown", "ignored?")]
        for key, value in changes:
            with self.subTest(field=key):
                changed = copy.deepcopy(entry)
                changed[key] = value
                with self.assertRaises(ds.InvalidDataset):
                    ds.validate_entry(changed)
        for key in entry["privacy"]:
            changed = copy.deepcopy(entry)
            changed["privacy"][key] = True
            with self.assertRaises(ds.InvalidDataset):
                ds.validate_entry(changed)

    def test_schema_missing_metadata_and_unsupported_constraint(self):
        for key in self.entries["public"]:
            changed = copy.deepcopy(self.entries["public"])
            del changed[key]
            with self.subTest(missing=key), self.assertRaises(ds.InvalidDataset):
                ds.validate_entry(changed)
        with self.assertRaisesRegex(ds.InvalidDataset, "unsupported"):
            ds.validate_schema("x", {"type": "string", "format": "uri"})

    def test_public_cannot_invent_groups_time_or_verified_units(self):
        for key, value in (("groups", {"anonymous": "train"}),
                           ("time_basis", "synthetic_elapsed_ms"),
                           ("unit_status", "synthetic_defined"),
                           ("training_use", "synthetic_only")):
            entry = copy.deepcopy(self.entries["public"])
            entry[key] = value
            with self.subTest(field=key), self.assertRaises(ds.InvalidDataset):
                ds.validate_entry(entry)

    def test_group_leakage_and_nonmonotonic_time_rejected(self):
        data = synthetic_corpus.generate().decode()
        for replacement in (
            data.replace("synthetic-a,synthetic-a-stationary,train,20", "synthetic-a,synthetic-a-stationary,test,20", 1),
            data.replace("train,20,stationary", "train,0,stationary", 1),
            data.replace("train,20,stationary", "train,20,braking", 1),
            data.replace("synthetic-a,synthetic-a-stationary,train,20", "unknown,synthetic-a-stationary,train,20", 1),
        ):
            self.assert_rejected(self.entries["synthetic"], replacement.encode(), ".")

    def test_reopened_trip_and_trip_driver_change_rejected(self):
        rows = list(csv.reader(io.StringIO(synthetic_corpus.generate().decode())))
        for selection in ([rows[0], rows[1], rows[32], rows[2]],
                          [rows[0], rows[1], ["synthetic-b", rows[2][1], "validation", *rows[2][3:]]]):
            output = io.StringIO(newline="")
            csv.writer(output).writerows(selection)
            self.assert_rejected(self.entries["synthetic"], output.getvalue().encode(), ".")

    def test_duplicate_json_keys_and_nonfinite_json_rejected(self):
        path = self.root / "entry.json"
        for raw in ('{"license":"CC0-1.0","license":"other"}', '{"x":NaN}', '[]', 'broken'):
            path.write_text(raw)
            with self.assertRaises(ds.InvalidDataset):
                ds.load_json(path)

    def test_duplicate_registry_identity_rejected(self):
        registry = self.root / "registry"
        registry.mkdir()
        for name in ("one.json", "two.json"):
            (registry / name).write_bytes(ds.canonical_json(self.entries["synthetic"]))
        with patch.object(ds, "REGISTRY", registry):
            with self.assertRaisesRegex(ds.InvalidDataset, "duplicate dataset"):
                ds.registry_entries()

    def test_cli_errors_do_not_echo_paths_or_untrusted_values(self):
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            code = ds.main(["import", "--dataset", "private-input-do-not-echo", "--version", "1",
                            "--source", str(self.root / "private-route")])
        self.assertEqual(code, 1)
        self.assertNotIn("private-input", output.getvalue())
        self.assertNotIn(str(self.root), output.getvalue())

    def test_cli_validate_runs_offline(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(ds.main(["validate"]), 0)
        self.assertIn("3 entries", output.getvalue())

    def test_symbolic_output_ancestor_is_rejected(self):
        destination = self.root / "actual"
        destination.mkdir()
        link = self.root / "link"
        # Windows symlink creation requires an OS privilege. Model detection
        # without requiring that privilege; assert no destination writes occur.
        original = Path.is_symlink
        with patch.object(Path, "is_symlink", lambda path: path == link or original(path)):
            with self.assertRaisesRegex(ds.InvalidDataset, "ancestors"):
                ds.import_dataset(self.entries["synthetic"], None, link / "out")
        self.assertEqual(list(destination.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
