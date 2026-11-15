"""Generated-only IntegrityNet comparison; no app, ranking or safety integration."""

from __future__ import annotations

import argparse
import copy
import csv
import io
import json
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

import torch
from torch import nn

from . import datasets as ds

SPEC_PATH = ds.ROOT / "ml/experiments/integritynet-v1.json"
SPEC = ds.load_json(SPEC_PATH)
VERSION = "integritynet-generated-ae-v1"
CONFIG = SPEC["config"]
FEATURES = SPEC["features"]
ds.require(SPEC["experiment_version"] == VERSION and SPEC["production_eligible"] is False and
           SPEC["source_kind"] == "generated_only" and len(FEATURES) == 8, "unsupported experimental manifest")
HEADER = ["case_id", "profile", "partition", "scenario", "category", "decoder",
          "corpus_version", "integrity_version", "baseline_state", "baseline_kinds", "baseline_rules"] + FEATURES


def load_source(path: Path, expected_sha256: str):
    ds.require(re.fullmatch(r"[a-f0-9]{64}", expected_sha256) is not None, "fixture digest required")
    ds.require(path.stat().st_size <= 1024 * 1024, "fixture too large")
    raw = path.read_bytes()
    ds.require(ds.sha256(raw) == expected_sha256, "fixture digest mismatch")
    reader = csv.DictReader(io.StringIO(raw.decode("utf-8"), newline=""))
    ds.require(reader.fieldnames == HEADER, "fixture columns mismatch")
    expected = {}
    for group, partition in SPEC["groups"].items():
        scenarios = SPEC["clean_scenarios"] + ([] if partition == "train" else list(SPEC["extra_categories"]))
        for scenario in scenarios:
            category = "clean" if scenario in SPEC["clean_scenarios"] else SPEC["extra_categories"][scenario]
            expected[f"{group}-{scenario.lower()}"] = (group, partition, scenario, category)
    rows = []
    for record in reader:
        ds.require(len(rows) < 104 and set(record) == set(HEADER) and None not in record.values(), "invalid fixture row")
        identity = record["case_id"]
        ds.require(identity in expected, "unexpected or duplicate fixture case")
        actual = tuple(record[key] for key in ("profile", "partition", "scenario", "category"))
        ds.require(actual == expected.pop(identity), "fixture split or label mismatch")
        ds.require(record["corpus_version"] == record["integrity_version"] == "1", "unsupported baseline version")
        rules = record["baseline_rules"].split("|") if record["baseline_rules"] else []
        kinds = record["baseline_kinds"].split("|") if record["baseline_kinds"] else []
        ds.require(rules == sorted(set(rules)) and all(rule in SPEC["rule_kinds"] for rule in rules), "invalid native rule IDs")
        ds.require(kinds == sorted({SPEC["rule_kinds"][rule] for rule in rules}), "native finding kinds mismatch")
        state = record["baseline_state"]
        ds.require(state in ("VERIFIED", "LIMITED_CONFIDENCE", "QUESTIONABLE", "UNRANKED") and
                   ((state == "VERIFIED") == (not rules)), "invalid native state")
        corrupt = record["category"] == "corruption"
        ds.require(record["decoder"] == ("rejected" if corrupt else "valid"), "decoder eligibility mismatch")
        if corrupt:
            ds.require(all(record[key] == "" for key in FEATURES) and kinds == ["DATA_CORRUPTION"] and state == "UNRANKED",
                       "decoder corruption must abstain with no fabricated features")
            features = None
        else:
            features = [float(record[key]) for key in FEATURES]
            ds.require(all(math.isfinite(value) and 0 <= value <= 1e6 for value in features), "invalid aggregate features")
            ds.require(record["category"] != "clean" or state == "VERIFIED", "generated clean baseline mismatch")
        rows.append({"id": identity, "group": record["profile"], "partition": record["partition"],
                     "scenario": record["scenario"], "category": record["category"], "features": features,
                     "native_state": state, "native_kinds": kinds, "native_rules": rules})
    ds.require(not expected and len(rows) == 104, "incomplete generated corpus")
    partitions = {name: [row for row in rows if row["partition"] == name] for name in ("train", "validation", "test")}
    ds.require([len(rows) for rows in partitions.values()] == [40, 32, 32], "partition count mismatch")
    return partitions


class IntegrityNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.layers = nn.Sequential(nn.Linear(8, 4), nn.ReLU(), nn.Linear(4, 2), nn.ReLU(),
                                    nn.Linear(2, 4), nn.ReLU(), nn.Linear(4, 8))

    def forward(self, value):
        return self.layers(value)


def tensor(rows):
    ds.require(0 < len(rows) <= 104 and all(isinstance(row["features"], list) and len(row["features"]) == 8 for row in rows),
               "bounded complete features required")
    ds.require(all(type(value) in (int, float) and math.isfinite(value) and abs(value) <= 1e6
                   for row in rows for value in row["features"]), "finite numeric features required")
    value = torch.tensor([row["features"] for row in rows], dtype=torch.float32, device="cpu")
    ds.require(value.shape == (len(rows), 8) and bool(torch.isfinite(value).all()) and bool((value.abs() <= 1e6).all()),
               "invalid feature tensor")
    return value


def normalize(value, normalizer):
    ds.require(type(normalizer) is dict and set(normalizer) == {"mean", "scale"} and
               all(type(normalizer[key]) is list and len(normalizer[key]) == 8 and
                   all(type(number) in (int, float) and math.isfinite(number) and abs(number) <= 1e6
                       for number in normalizer[key]) for key in ("mean", "scale")), "bounded normalizer required")
    mean = torch.tensor(normalizer["mean"], dtype=torch.float32, device="cpu")
    scale = torch.tensor(normalizer["scale"], dtype=torch.float32, device="cpu")
    ds.require(mean.shape == scale.shape == (8,) and bool(torch.isfinite(mean).all()) and
               bool(torch.isfinite(scale).all()) and bool((scale >= 1e-6).all()), "invalid normalization")
    result = (value - mean) / scale
    ds.require(bool(torch.isfinite(result).all()), "nonfinite normalized input")
    return result


def fit(training_clean):
    ds.require(all(row["partition"] == "train" and row["category"] == "clean" for row in training_clean),
               "training-clean partition only")
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    torch.manual_seed(CONFIG["seed"])
    value = tensor(training_clean)
    normalizer = {"mean": value.mean(dim=0).tolist(), "scale": value.std(dim=0, unbiased=False).clamp_min(1e-6).tolist()}
    value = normalize(value, normalizer)
    model = IntegrityNet().cpu()
    optimizer = torch.optim.Adam(model.parameters(), lr=CONFIG["learning_rate"])
    losses = []
    for _ in range(CONFIG["epochs"]):
        optimizer.zero_grad()
        loss = (model(value) - value).square().mean()
        ds.require(bool(torch.isfinite(loss)), "nonfinite training loss")
        loss.backward()
        optimizer.step()
        losses.append(float(loss.detach()))
    return model.eval(), normalizer, {"initial_loss": losses[0], "last_epoch_loss": losses[-1]}


def scores(model, normalizer, rows):
    with torch.inference_mode():
        value = normalize(tensor(rows), normalizer)
        errors = (model(value) - value).square().mean(dim=1)
    ds.require(bool(torch.isfinite(errors).all()) and bool((errors >= 0).all()), "invalid reconstruction errors")
    return errors.tolist()


def threshold_from_validation_clean(errors):
    ds.require(0 < len(errors) <= 104 and all(type(value) in (int, float) and math.isfinite(value) and value >= 0 for value in errors),
               "validation-clean errors required")
    index = math.ceil(len(errors) * CONFIG["validation_clean_quantile"]) - 1
    return sorted(errors)[index] + CONFIG["threshold_epsilon"]


def evaluate(model, normalizer, rows, threshold):
    ds.require(math.isfinite(threshold) and threshold > 0, "positive frozen threshold required")
    available = [row for row in rows if row["features"] is not None]
    errors = dict(zip((row["id"] for row in available), scores(model, normalizer, available)))
    flagged = {key for key, value in errors.items() if value > threshold}
    native = {row["id"] for row in rows if "INCONSISTENCY" in row["native_kinds"]}
    clean = [row for row in rows if row["category"] == "clean"]
    positive = [row for row in rows if row["category"] == "numeric_inconsistency"]
    def metrics(identities):
        false_flags = sum(row["id"] in identities for row in clean)
        detections = sum(row["id"] in identities for row in positive)
        return {"synthetic_clean_cases": len(clean), "synthetic_clean_false_flags": false_flags,
                "synthetic_clean_false_flag_rate": false_flags / len(clean) if clean else None,
                "numeric_injection_cases": len(positive), "numeric_injection_detections": detections,
                "numeric_injection_detection_rate": detections / len(positive) if positive else None}
    def slice_summary(selected):
        return {"cases": len(selected), "model_evaluated": sum(row["id"] in errors for row in selected),
                "model_flagged": sum(row["id"] in flagged for row in selected),
                "native_findings_by_kind": {kind: sum(kind in row["native_kinds"] for row in selected)
                    for kind in sorted(set(SPEC["rule_kinds"].values()))},
                "native_states": {state: sum(row["native_state"] == state for row in selected)
                    for state in sorted({row["native_state"] for row in selected})}}
    return {"model": metrics(flagged), "native_inconsistency_baseline": metrics(native),
            "cases": len(rows), "model_evaluated": len(available), "decoder_abstentions": len(rows) - len(available),
            "by_category": {category: slice_summary([row for row in rows if row["category"] == category])
                for category in sorted({row["category"] for row in rows})},
            "by_family": {family: slice_summary([row for row in rows if row["scenario"] == family])
                for family in sorted({row["scenario"] for row in rows})}}


def generated_added_value(comparison):
    model, baseline = comparison["model"], comparison["native_inconsistency_baseline"]
    fp, recall = "synthetic_clean_false_flag_rate", "numeric_injection_detection_rate"
    ds.require(all(item[key] is not None for item in (model, baseline) for key in (fp, recall)), "comparison requires both categories")
    return (model[fp] <= baseline[fp] and model[recall] >= baseline[recall] and
            (model[fp] < baseline[fp] or model[recall] > baseline[recall]))


def checkpoint(model, normalizer, threshold, source_sha256):
    return {"format": VERSION, "production_eligible": False, "feature_schema": SPEC["feature_schema"],
            "source_fixture_sha256": source_sha256, "config": copy.deepcopy(CONFIG), "normalizer": copy.deepcopy(normalizer),
            "threshold": threshold, "state": {name: {"shape": list(value.shape), "values": value.flatten().tolist()}
                for name, value in model.state_dict().items()}}


def restore(value):
    ds.require(set(value) == {"format", "production_eligible", "feature_schema", "source_fixture_sha256", "config", "normalizer", "threshold", "state"} and
               value["format"] == VERSION and value["production_eligible"] is False and value["config"] == CONFIG and
               value["feature_schema"] == SPEC["feature_schema"], "unsupported checkpoint")
    ds.require(re.fullmatch(r"[a-f0-9]{64}", value["source_fixture_sha256"]) is not None, "invalid fixture provenance")
    ds.require(type(value["threshold"]) in (float, int) and math.isfinite(value["threshold"]) and value["threshold"] > 0, "invalid threshold")
    model = IntegrityNet().cpu()
    expected = model.state_dict()
    ds.require(set(value["state"]) == set(expected), "checkpoint parameter keys mismatch")
    state = {}
    for name, original in expected.items():
        saved = value["state"][name]
        ds.require(set(saved) == {"shape", "values"} and saved["shape"] == list(original.shape) and
                   type(saved["values"]) is list and len(saved["values"]) == original.numel() and
                   all(type(number) in (int, float) and math.isfinite(number) and abs(number) <= 1e6 for number in saved["values"]),
                   "invalid checkpoint parameter")
        state[name] = torch.tensor(saved["values"], dtype=torch.float32).reshape(original.shape)
    normalize(torch.zeros(1, 8), value["normalizer"])
    model.load_state_dict(state, strict=True)
    return model.eval(), value["normalizer"], value["threshold"]


def provenance():
    files = ["ml/integritynet.py", "ml/experiments/integritynet-v1.json", "ml/requirements-eventnet.txt", "ml/DATA_LICENSE.md",
             "docs/reference/INTEGRITYNET_BASELINE_V1.md",
             "android/app/src/test/kotlin/io/github/atrx07/traelyx/intelligence/IntegrityExperimentFixtureTest.kt",
             "android/app/src/test/kotlin/io/github/atrx07/traelyx/intelligence/IntelligencePipelineTestHarness.kt",
             "android/app/src/test/kotlin/io/github/atrx07/traelyx/telemetry/TelemetryRegressionFixtureCorpus.kt",
             "android/app/src/main/kotlin/io/github/atrx07/traelyx/intelligence/IntegrityPipeline.kt",
             "android/app/src/main/kotlin/io/github/atrx07/traelyx/intelligence/IntegrityModels.kt"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, capture_output=True, text=True, check=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT, capture_output=True, text=True, check=True).stdout)
    return {"training_code_commit": commit, "training_source_dirty": dirty,
            "source_files_sha256": {name: ds.sha256((ds.ROOT / name).read_bytes()) for name in files}}


def run(source: Path, expected_sha256: str, run_name: str):
    ds.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", run_name) is not None, "invalid run name")
    ds.require(torch.__version__ == "2.15.0+cpu", "use pinned CPU environment")
    partitions = load_source(source, expected_sha256)
    root = ds.ROOT / "ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output link denied")
    root.mkdir(parents=True, exist_ok=True)
    target = root / run_name
    ds.require(not target.exists() and not target.is_symlink(), "never overwrite prior experiment")
    model, normalizer, training = fit(partitions["train"])
    validation_clean = [row for row in partitions["validation"] if row["category"] == "clean"]
    threshold = threshold_from_validation_clean(scores(model, normalizer, validation_clean))
    # Fitting is finished before any validation-injection or held-out test score is evaluated.
    comparisons = {name: evaluate(model, normalizer, rows, threshold) for name, rows in partitions.items()}
    added_value = generated_added_value(comparisons["test"])
    state = ds.canonical_json(checkpoint(model, normalizer, threshold, expected_sha256))
    restored, restored_norm, restored_threshold = restore(json.loads(state))
    ds.require(evaluate(restored, restored_norm, partitions["test"], restored_threshold) == comparisons["test"], "checkpoint replay mismatch")
    report = {"experiment_version": VERSION, "model_status": "experiment", "production_eligible": False,
              "dataset_id": SPEC["dataset_id"], "source_kind": SPEC["source_kind"], "license": SPEC["license"],
              "attribution": SPEC["attribution"], "source_fixture_sha256": expected_sha256,
              "experiment_manifest_sha256": ds.sha256(ds.canonical_json(SPEC)), "feature_schema": SPEC["feature_schema"],
              "feature_names": FEATURES, "groups": SPEC["groups"], "config": CONFIG, "parameters": sum(p.numel() for p in model.parameters()),
              "model_sha256": ds.sha256(state), "model_bytes": len(state), "normalizer": normalizer,
              "training": training, "normalizer_fit_partition": "train_clean", "normalizer_fit_cases": len(partitions["train"]),
              "threshold": threshold, "threshold_fit_partition": "validation_clean", "threshold_fit_cases": len(validation_clean),
              "threshold_method": "nearest_rank_97_5_percentile_plus_1e_12", "comparisons": comparisons,
              "sensitivity_test": {str(multiplier): evaluate(model, normalizer, partitions["test"], threshold * multiplier)
                                   for multiplier in CONFIG["sensitivity_multipliers"]},
              "generated_added_value": added_value, "decision": "generated_signal_only_keep_rules" if added_value else "no_generated_added_value_keep_rules",
              "real_legitimate_drive_false_positive_rate": None, "calibrated_anomaly_probability": None, "mobile_runtime_metrics": None,
              "runtime": {"python": platform.python_version(), "torch": torch.__version__, "device": "cpu"},
              "limitations": SPEC["limitations"], **provenance()}
    with tempfile.TemporaryDirectory(prefix=".integritynet-", dir=root) as temporary:
        staging = Path(temporary) / "result"
        staging.mkdir()
        (staging / "checkpoint.json").write_bytes(state)
        (staging / "report.json").write_bytes(ds.canonical_json(report))
        ds.require(not target.exists(), "experiment appeared concurrently")
        staging.rename(target)
    return copy.deepcopy(report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    try:
        result = run(args.source, args.expected_sha256, args.run_name)
    except (OSError, ValueError, RuntimeError) as failure:
        print(f"IntegrityNet experiment failed ({type(failure).__name__}); no production result published.", file=sys.stderr)
        return 2
    print(f"Generated IntegrityNet comparison complete: {result['decision']}; production eligible: false.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
