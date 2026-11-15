"""Generated ContextNet value gate. Production inference and promotion stay disabled."""

import argparse
import copy
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
from torch.nn.utils.rnn import pack_padded_sequence, pad_sequence

from . import contextnet_corpus as corpus, datasets as ds

SPEC = corpus.SPEC
CONFIG = SPEC["config"]
CLASSES = tuple(SPEC["classes"])
VERSION = "contextnet-generated-gru-v1"
ds.require(SPEC["experiment_version"] == VERSION and SPEC["production_eligible"] is False and
           len(CLASSES) == 5 and len(SPEC["features"]) == 4, "unsupported ContextNet manifest")


def _pairs(items):
    result = {}
    for key, value in items:
        ds.require(key not in result, "duplicate JSON field")
        result[key] = value
    return result


def eligible(row):
    duration = row["duration_seconds"]
    return (duration in SPEC["durations_seconds"] and row["times_ms"] == [500+1000*i for i in range(duration)] and
            len(row["features"]) == len(row["supported"]) == duration and
            all(value is True for value in row["supported"]) and all(
                type(frame) is list and len(frame) == 4 and
                all(type(value) in (int, float) and math.isfinite(value) and abs(value) <= 1000 for value in frame) and frame[0] >= 0
                for frame in row["features"]))


def load_source(path, digest):
    ds.require(isinstance(digest, str) and re.fullmatch(r"[a-f0-9]{64}", digest), "fixture digest required")
    ds.require(path.stat().st_size <= 16*1024*1024, "fixture size limit")
    with path.open("rb") as stream:
        raw = stream.read(16*1024*1024+1)
    ds.require(len(raw) <= 16*1024*1024, "fixture size limit")
    ds.require(ds.sha256(raw) == digest, "fixture digest mismatch")
    value = json.loads(raw, object_pairs_hook=_pairs)
    ds.require(type(value) is dict and set(value) == {"format", "source_kind", "feature_schema", "sample_interval_ms", "manifest_sha256", "cases"} and
               value["format"] == corpus.VERSION and value["source_kind"] == "generated_only" and
               value["feature_schema"] == SPEC["feature_schema"] and value["sample_interval_ms"] == 1000 and
               value["manifest_sha256"] == ds.sha256(ds.canonical_json(SPEC)), "fixture contract mismatch")
    ds.require(type(value["cases"]) is list and len(value["cases"]) == 318, "fixture case count mismatch")
    expected = {row["id"]: row for row in corpus.case_specs()}
    for row in value["cases"]:
        ds.require(type(row) is dict and set(row) == {"id", "group", "partition", "category", "label", "duration_seconds", "variant", "times_ms", "features", "supported"}, "invalid case fields")
        identity = row["id"]
        ds.require(type(identity) is str and identity in expected, "duplicate or unknown case")
        descriptor = expected.pop(identity)
        ds.require(all(type(row[key]) is type(item) and row[key] == item for key, item in descriptor.items()), "fixture group, label or split mismatch")
        duration = row["duration_seconds"]
        ds.require(type(row["times_ms"]) is list and all(type(time) is int for time in row["times_ms"]) and
                   row["times_ms"] == [500+1000*i for i in range(duration)] and
                   type(row["features"]) is list and type(row["supported"]) is list and
                   len(row["features"]) == len(row["supported"]) == duration, "time/shape mismatch")
        for index, (frame, support) in enumerate(zip(row["features"], row["supported"])):
            unavailable = row["category"].startswith("quality_") and 20 <= index < 25
            ds.require(type(support) is bool and support == (not unavailable), "unsupported quality mask")
            if unavailable and row["category"] == "quality_missing":
                ds.require(frame is None, "missing evidence must remain missing")
            else:
                ds.require(type(frame) is list and len(frame) == 4 and all(
                    type(number) in (int, float) and math.isfinite(number) and abs(number) <= 1000 for number in frame) and
                    frame[0] >= 0, "invalid physical features")
        ds.require(eligible(row) == (not row["category"].startswith("quality_")), "eligibility mismatch")
    ds.require(not expected, "incomplete corpus")
    partitions = {part: [row for row in value["cases"] if row["partition"] == part] for part in ("train", "validation", "test")}
    ds.require([len(rows) for rows in partitions.values()] == [150, 84, 84], "partition counts mismatch")
    return partitions


def rule_prediction(row):
    if not eligible(row): return None
    rule = SPEC["baseline"]
    speed, acceleration, lateral, jerk = zip(*row["features"])
    stopped = [value <= rule["stopped_speed_mps"] for value in speed]
    stopped_fraction = sum(stopped) / len(stopped)
    transitions = sum(a != b for a, b in zip(stopped, stopped[1:]))
    signed_jerk = [1 if value >= rule["jerk_mps3"] else -1 if value <= -rule["jerk_mps3"] else 0 for value in jerk]
    episodes = sum(value != 0 and (index == 0 or value != signed_jerk[index-1]) for index, value in enumerate(signed_jerk))
    dynamic = []
    if rule["stop_fraction_min"] <= stopped_fraction <= rule["stop_fraction_max"] and transitions >= rule["minimum_stop_transitions"]:
        dynamic.append("stop_and_go")
    if sum(abs(value) >= rule["lateral_load_mps2"] for value in lateral) / len(lateral) >= rule["lateral_occupancy_min"]:
        dynamic.append("high_dynamic_load")
    if episodes >= rule["minimum_jerk_episodes"]: dynamic.append("repeated_abrupt_transitions")
    if dynamic: return dynamic[0] if len(dynamic) == 1 else None
    if 1-stopped_fraction < rule["moving_fraction_min"]: return None
    span, maximum_acceleration = max(speed)-min(speed), max(map(abs, acceleration))
    if span <= rule["cruise_speed_span_mps"] and maximum_acceleration <= rule["cruise_acceleration_max_mps2"]: return "steady_cruise"
    if span > rule["cruise_speed_span_mps"] and maximum_acceleration <= rule["smooth_acceleration_max_mps2"]: return "smooth_variable"
    return None


class ContextNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.gru = nn.GRU(4, CONFIG["hidden"], batch_first=True)
        self.head = nn.Linear(CONFIG["hidden"], len(CLASSES))

    def forward(self, value, lengths):
        packed = pack_padded_sequence(value, lengths, batch_first=True, enforce_sorted=False)
        _, state = self.gru(packed)
        return self.head(state[-1])


def sequences(rows):
    ds.require(0 < len(rows) <= 318 and all(eligible(row) for row in rows), "complete supported sequences required")
    return [torch.tensor(row["features"], dtype=torch.float32, device="cpu") for row in rows]


def checked_normalizer(normalizer):
    ds.require(type(normalizer) is dict and set(normalizer) == {"mean", "scale"} and all(
        type(normalizer[key]) is list and len(normalizer[key]) == 4 and all(type(value) in (int, float) and
        math.isfinite(value) and abs(value) <= 1000 for value in normalizer[key]) for key in ("mean", "scale")), "invalid normalization")
    mean, scale = (torch.tensor(normalizer[key], dtype=torch.float32) for key in ("mean", "scale"))
    ds.require(bool((scale >= 1e-6).all()), "invalid normalization scale")
    return mean, scale


def batch(rows, normalizer):
    mean, scale = checked_normalizer(normalizer)
    values = [(value-mean)/scale for value in sequences(rows)]
    ds.require(all(bool(torch.isfinite(value).all()) for value in values), "nonfinite normalized input")
    return pad_sequence(values, batch_first=True), torch.tensor([len(value) for value in values], dtype=torch.long)


def fit(training):
    ds.require(all(row["partition"] == "train" and row["category"] == "labelled" and row["label"] in CLASSES for row in training), "training-labelled cases only")
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    torch.manual_seed(CONFIG["seed"])
    frames = torch.cat(sequences(training))
    normalizer = {"mean": frames.mean(dim=0).tolist(), "scale": frames.std(dim=0, unbiased=False).clamp_min(1e-6).tolist()}
    value, lengths = batch(training, normalizer)
    labels = torch.tensor([CLASSES.index(row["label"]) for row in training], dtype=torch.long)
    model = ContextNet().cpu()
    optimizer = torch.optim.Adam(model.parameters(), lr=CONFIG["learning_rate"])
    losses = []
    for _ in range(CONFIG["epochs"]):
        optimizer.zero_grad()
        loss = nn.functional.cross_entropy(model(value, lengths), labels)
        ds.require(bool(torch.isfinite(loss)), "nonfinite training loss")
        loss.backward()
        optimizer.step()
        losses.append(float(loss.detach()))
    return model.eval(), normalizer, {"cases": len(training), "valid_frames": len(frames),
                                    "initial_loss": losses[0], "last_epoch_loss": losses[-1]}


def predictions(model, normalizer, rows):
    complete = [row for row in rows if eligible(row)]
    if not complete: return {}
    value, lengths = batch(complete, normalizer)
    with torch.inference_mode(): probabilities = model(value, lengths).softmax(dim=1)
    ds.require(probabilities.shape == (len(complete), 5) and bool(torch.isfinite(probabilities).all()), "invalid probability output")
    return dict(zip((row["id"] for row in complete), probabilities.tolist()))


def metrics(rows, choices):
    ds.require(rows and all(row["label"] in CLASSES for row in rows), "labelled metrics required")
    matrix = [[0]*6 for _ in CLASSES]
    for row in rows:
        choice = choices.get(row["id"])
        matrix[CLASSES.index(row["label"])][CLASSES.index(choice) if choice is not None else 5] += 1
    per_class = {}
    for index, label in enumerate(CLASSES):
        tp, support, predicted = matrix[index][index], sum(matrix[index]), sum(row[index] for row in matrix)
        precision, recall = tp/predicted if predicted else 0., tp/support if support else 0.
        per_class[label] = {"precision": precision, "recall": recall, "f1": 2*precision*recall/(precision+recall) if precision+recall else 0., "support": support}
    return {"cases": len(rows), "macro_f1": sum(value["f1"] for value in per_class.values())/5,
            "per_class": per_class, "confusion_true_rows_abstention_last_column": matrix,
            "coverage": sum(sum(row[:5]) for row in matrix)/len(rows), "abstentions": sum(row[5] for row in matrix)}


def evaluate(model, normalizer, rows):
    probability = predictions(model, normalizer, rows)
    rules = {row["id"]: rule_prediction(row) for row in rows}
    argmax = {identity: CLASSES[max(range(5), key=lambda index: values[index])] for identity, values in probability.items()}
    selected = {identity: argmax[identity] if max(values) >= CONFIG["selective_probability_cutoff"] else None for identity, values in probability.items()}
    labelled = [row for row in rows if row["category"] == "labelled"]
    def diagnostics(choices):
        return {category: {"cases": sum(row["category"] == category for row in rows),
                           "abstentions": sum(row["category"] == category and choices.get(row["id"]) is None for row in rows),
                           "non_abstained": sum(row["category"] == category and choices.get(row["id"]) is not None for row in rows)}
                for category in ("quality_missing", "quality_unsupported", "open_stationary", "open_mixed")}
    brier = sum(sum((value-int(index == CLASSES.index(row["label"])))**2 for index, value in enumerate(probability[row["id"]])) for row in labelled)/len(labelled)
    nll = -sum(math.log(max(probability[row["id"]][CLASSES.index(row["label"])], 1e-12)) for row in labelled)/len(labelled)
    return {"model_argmax": metrics(labelled, argmax), "model_selective": metrics(labelled, selected),
            "temporal_rules": metrics(labelled, rules), "model_diagnostics": diagnostics(selected), "rule_diagnostics": diagnostics(rules),
            "raw_probability_diagnostics": {"status": "uncalibrated_generated_only", "brier_multiclass_sum": brier, "negative_log_likelihood": nll},
            "model_evaluated": len(probability), "quality_cases_inferred": sum(row["id"] in probability for row in rows if row["category"].startswith("quality_"))}


def value_gate(comparison):
    model, rule = comparison["model_selective"], comparison["temporal_rules"]
    checks = {"material_macro_f1_gain": model["macro_f1"] >= rule["macro_f1"]+CONFIG["minimum_macro_f1_gain"],
              "no_class_recall_regression": all(model["per_class"][label]["recall"] >= rule["per_class"][label]["recall"] for label in CLASSES),
              "no_labelled_coverage_regression": model["coverage"] >= rule["coverage"],
              "no_additional_open_claims": all(comparison["model_diagnostics"][category]["non_abstained"] <= comparison["rule_diagnostics"][category]["non_abstained"] for category in ("open_stationary", "open_mixed")),
              "quality_abstention_preserved": comparison["quality_cases_inferred"] == 0 and all(comparison["model_diagnostics"][category]["abstentions"] == comparison["rule_diagnostics"][category]["abstentions"] for category in ("quality_missing", "quality_unsupported"))}
    return {"passed": all(checks.values()), "checks": checks}


def checkpoint(model, normalizer, digest):
    return {"format": VERSION, "production_eligible": False, "source_sha256": digest, "config": copy.deepcopy(CONFIG),
            "feature_schema": SPEC["feature_schema"], "classes": list(CLASSES), "normalizer": copy.deepcopy(normalizer),
            "state": {key: {"shape": list(value.shape), "values": value.flatten().tolist()} for key, value in model.state_dict().items()}}


def restore(saved):
    ds.require(type(saved) is dict and set(saved) == {"format", "production_eligible", "source_sha256", "config", "feature_schema", "classes", "normalizer", "state"} and
               saved["format"] == VERSION and saved["production_eligible"] is False and saved["config"] == CONFIG and
               saved["classes"] == list(CLASSES) and saved["feature_schema"] == SPEC["feature_schema"] and
               isinstance(saved["source_sha256"], str) and re.fullmatch(r"[a-f0-9]{64}", saved["source_sha256"]), "unsupported checkpoint")
    checked_normalizer(saved["normalizer"])
    model = ContextNet().cpu()
    expected = model.state_dict()
    ds.require(type(saved["state"]) is dict and set(saved["state"]) == set(expected), "invalid parameter keys")
    state = {}
    for key, original in expected.items():
        item = saved["state"][key]
        ds.require(type(item) is dict and set(item) == {"shape", "values"} and item["shape"] == list(original.shape) and
                   type(item["values"]) is list and len(item["values"]) == original.numel() and all(type(value) in (int, float) and math.isfinite(value) and abs(value) <= 1e6 for value in item["values"]), "invalid model parameter")
        state[key] = torch.tensor(item["values"], dtype=torch.float32).reshape(original.shape)
    model.load_state_dict(state, strict=True)
    return model.eval(), copy.deepcopy(saved["normalizer"])


def provenance():
    files = ["ml/contextnet.py", "ml/contextnet_corpus.py", "ml/experiments/contextnet-v1.json",
             "ml/experiments/CONTEXTNET_DATA_LICENSE.md", "ml/requirements-eventnet.txt", "docs/reference/CONTEXTNET_EXPERIMENT_V1.md"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, capture_output=True, text=True, check=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT, capture_output=True, text=True, check=True).stdout)
    return {"source_commit": commit, "source_dirty": dirty, "source_files_sha256": {name: ds.sha256((ds.ROOT/name).read_bytes()) for name in files}}


def run(source: Path, digest: str, name: str):
    ds.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", name), "invalid run name")
    ds.require(torch.__version__ == "2.15.0+cpu", "use pinned CPU environment")
    parts = load_source(source, digest)
    root = ds.ROOT/"ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output links denied")
    root.mkdir(parents=True, exist_ok=True)
    target = root/name
    ds.require(not target.exists() and not target.is_symlink() and not target.is_junction(), "never overwrite experiment")
    model, normalizer, training = fit(parts["train"])
    validation = evaluate(model, normalizer, parts["validation"])
    gate = value_gate(validation)
    # No held-out prediction call is reachable on a failed validation value gate.
    test = evaluate(model, normalizer, parts["test"]) if gate["passed"] else None
    test_gate = value_gate(test) if test is not None else None
    state = ds.canonical_json(checkpoint(model, normalizer, digest))
    restored, norm = restore(json.loads(state))
    ds.require(evaluate(restored, norm, parts["validation"]) == validation, "checkpoint replay mismatch")
    report = {"experiment_version": VERSION, "model_status": "experiment", "production_eligible": False,
              "source_sha256": digest, "source_kind": "generated_only", "manifest_sha256": ds.sha256(ds.canonical_json(SPEC)),
              "license": SPEC["license"], "attribution": SPEC["attribution"], "feature_schema": SPEC["feature_schema"],
              "classes": list(CLASSES), "groups": SPEC["groups"], "config": CONFIG, "baseline_config": SPEC["baseline"],
              "parameters": sum(value.numel() for value in model.parameters()), "model_sha256": ds.sha256(state), "model_bytes": len(state),
              "normalizer": normalizer, "normalizer_fit_partition": "training_valid_frames", "training": training,
              "validation": validation, "validation_value_gate": gate,
              "test": {"predictions_computed": test is not None, "metadata_validated": True, "cases_available": len(parts["test"]), "metrics": test, "value_gate": test_gate},
              "decision": "generated_value_only_keep_production_rules" if test_gate and test_gate["passed"] else "no_validated_added_value_keep_rules",
              "real_context_accuracy": None, "calibrated_confidence": None, "mobile_runtime_metrics": None,
              "runtime": {"python": platform.python_version(), "torch": torch.__version__, "device": "cpu"},
              "limitations": SPEC["limitations"], **provenance()}
    with tempfile.TemporaryDirectory(prefix=".contextnet-", dir=root) as temporary:
        staging = Path(temporary)/"result"
        staging.mkdir()
        (staging/"checkpoint.json").write_bytes(state)
        (staging/"report.json").write_bytes(ds.canonical_json(report))
        ds.require(not target.exists(), "experiment appeared concurrently")
        staging.rename(target)
    return copy.deepcopy(report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    try: report = run(args.source, args.expected_sha256, args.run_name)
    except (OSError, ValueError, RuntimeError) as failure:
        print(f"ContextNet experiment failed ({type(failure).__name__}); no production result published.", file=sys.stderr)
        return 2
    print(f"ContextNet comparison complete: {report['decision']}; test predictions computed: {report['test']['predictions_computed']}; production eligible: false.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
