"""Frozen M7.3 retrospective temperature-scaling audit; never production promotion."""

from __future__ import annotations

import argparse
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

import torch

from . import datasets as ds
from . import eventnet as net

VERSION = "eventnet-temperature-audit-v1"
PROTOCOL = {"temperature_min": 0.1, "temperature_max": 100.0,
            "iterations": 80, "reliability_bins": 10, "fit_partition": "validation",
            "objective": "mean_negative_log_likelihood", "tie_tolerance": 1e-12}
BASELINE = ds.ROOT / "docs/reference/eventnet-baseline-v1-result.json"


def checked(logits, labels):
    ds.require(isinstance(logits, torch.Tensor) and isinstance(labels, torch.Tensor), "tensors required")
    ds.require(logits.device.type == labels.device.type == "cpu", "CPU audit required")
    ds.require(logits.ndim == 2 and logits.shape[1] == 4 and logits.shape[0] > 0 and
               labels.ndim == 1 and len(labels) == len(logits), "invalid logit/label shape")
    ds.require(logits.is_floating_point() and bool(torch.isfinite(logits).all()) and
               bool((logits.abs() <= 1e9).all()), "invalid/unbounded logits")
    ds.require(labels.dtype == torch.long and bool(((labels >= 0) & (labels < 4)).all()),
               "invalid label dtype/range")
    return logits.detach().to(torch.float64), labels.detach()


def nll(logits, labels, temperature: float) -> float:
    ds.require(type(temperature) in (int, float) and
               PROTOCOL["temperature_min"] <= temperature <= PROTOCOL["temperature_max"] and
               math.isfinite(temperature), "temperature outside frozen finite positive bounds")
    scores, labels = checked(logits, labels)
    scores = scores / temperature
    result = (torch.logsumexp(scores, dim=1) - scores.gather(1, labels[:, None]).squeeze(1)).mean()
    ds.require(bool(torch.isfinite(result)), "non-finite calibration loss")
    return float(result)


def fit_temperature(validation_logits, validation_labels) -> dict:
    """Only validation tensors enter fitting; no test argument or method search."""
    scores, labels = checked(validation_logits, validation_labels)
    left, right = 1 / PROTOCOL["temperature_max"], 1 / PROTOCOL["temperature_min"]
    ratio = (math.sqrt(5) - 1) / 2
    a, b = right - ratio * (right - left), left + ratio * (right - left)
    fa, fb = nll(scores, labels, 1 / a), nll(scores, labels, 1 / b)
    for _ in range(PROTOCOL["iterations"]):
        if fa <= fb:
            right, b, fb = b, a, fa
            a = right - ratio * (right - left)
            fa = nll(scores, labels, 1 / a)
        else:
            left, a, fa = a, b, fb
            b = left + ratio * (right - left)
            fb = nll(scores, labels, 1 / b)
    candidates = [1.0, PROTOCOL["temperature_min"], PROTOCOL["temperature_max"], 2 / (left + right)]
    losses = [nll(scores, labels, value) for value in candidates]
    minimum = min(losses)
    # Identity is first, so ties do not introduce an unsupported transformation.
    chosen = next(i for i, loss in enumerate(losses) if loss <= minimum + PROTOCOL["tie_tolerance"])
    return {"calibration_version": VERSION, "protocol": PROTOCOL,
            "temperature": candidates[chosen], "validation_examples": len(labels),
            "validation_nll_before": losses[0], "validation_nll_after": losses[chosen],
            "boundary_solution": candidates[chosen] in candidates[1:3],
            "production_eligible": False}


def reliability(confidences: list[float], outcomes: list[int]) -> dict:
    ds.require(len(confidences) == len(outcomes) > 0, "empty/mismatched reliability input")
    bins = [{"count": 0, "confidence_sum": 0.0, "outcome_sum": 0} for _ in range(10)]
    for confidence, outcome in zip(confidences, outcomes):
        ds.require(type(confidence) in (float, int) and 0 <= confidence <= 1 and
                   math.isfinite(confidence) and type(outcome) is int and outcome in (0, 1),
                   "invalid reliability probability/outcome")
        index = min(int(confidence * 10), 9)
        bins[index]["count"] += 1
        bins[index]["confidence_sum"] += confidence
        bins[index]["outcome_sum"] += outcome
    result, ece = [], 0.0
    for index, item in enumerate(bins):
        count = item["count"]
        mean = item["confidence_sum"] / count if count else None
        rate = item["outcome_sum"] / count if count else None
        gap = abs(mean - rate) if count else None
        if count:
            ece += count / len(confidences) * gap
        result.append({"lower_inclusive": index / 10, "upper": (index + 1) / 10,
                       "upper_inclusive": index == 9, "count": count,
                       "mean_probability": mean, "observed_frequency": rate, "absolute_gap": gap})
    return {"bins": result, "ece": ece, "examples": len(confidences),
            "limitation": "Descriptive equal-width bins; sparse/empty bins do not establish calibration."}


def evaluate(logits, labels, temperature: float) -> dict:
    scores, truth = checked(logits, labels)
    loss = nll(scores, truth, temperature)
    probabilities = (scores / temperature).softmax(dim=1).tolist()
    values = truth.tolist()
    output = net.metrics(values, probabilities)
    # Stable logits avoid the baseline helper's 1e-12 probability clipping for NLL.
    output["negative_log_likelihood"] = loss
    output["probability_status"] = "raw_frozen_logits" if temperature == 1 else "validation_temperature_scaled_experiment"
    predictions = scores.argmax(dim=1).tolist()
    output["top_label_reliability"] = reliability(
        [row[prediction] for row, prediction in zip(probabilities, predictions)],
        [int(prediction == label) for prediction, label in zip(predictions, values)])
    output["classwise_reliability"] = {
        label: reliability([row[index] for row in probabilities], [int(value == index) for value in values])
        for index, label in enumerate(net.CLASSES)}
    output["source_label_errors"] = {
        label: {"support": sum(value == index for value in values),
                "disagreements": sum(value == index and prediction != value
                                     for value, prediction in zip(values, predictions)),
                "predicted_as": {other: sum(value == index and prediction == other_index
                                            for value, prediction in zip(values, predictions))
                                 for other_index, other in enumerate(net.CLASSES) if other_index != index}}
        for index, label in enumerate(net.CLASSES)}
    ds.require(predictions == [max(range(4), key=row.__getitem__) for row in probabilities],
               "numeric scaling changed a class decision")
    return output


def load_frozen(directory: Path):
    baseline = ds.load_json(BASELINE)
    ds.require(baseline.get("model_version") == net.MODEL_VERSION and
               baseline.get("model_status") == "experiment" and baseline.get("production_eligible") is False,
               "unsupported baseline evidence")
    for filename, digest in baseline["source_files_sha256"].items():
        # The checked-in baseline is trusted configuration, not a downloaded manifest.
        path = (ds.ROOT / filename).resolve()
        ds.require(path.is_relative_to(ds.ROOT.resolve()), "baseline source path outside checkout")
        ds.require(ds.sha256(path.read_bytes()) == digest, "frozen baseline source changed")
    with (directory / "checkpoint.json").open("rb") as stream:
        raw = stream.read(256 * 1024 + 1)
    ds.require(len(raw) <= 256 * 1024 and ds.sha256(raw) == baseline["model_sha256"],
               "frozen checkpoint digest mismatch")
    value = ds.load_json(directory / "checkpoint.json")
    model, normalizer = net.restore(value)
    return model, normalizer, baseline, raw


def provenance() -> dict:
    files = ["ml/calibration.py", "docs/reference/EVENTNET_CALIBRATION_V1.md",
             "docs/reference/eventnet-baseline-v1-result.json"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, check=True,
                            capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT,
                                check=True, capture_output=True, text=True).stdout)
    return {"analysis_code_commit": commit, "analysis_source_dirty": dirty,
            "analysis_source_sha256": {name: ds.sha256((ds.ROOT / name).read_bytes()) for name in files}}


def run(checkpoint_dir: Path, import_dir: Path, run_name: str) -> dict:
    ds.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", run_name), "invalid audit run name")
    ds.require(torch.__version__ == "2.15.0+cpu", "pinned CPU environment required")
    root = ds.ROOT / "ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)),
               "audit output ancestors cannot be links")
    target = root / run_name
    ds.require(not target.exists() and not target.is_symlink(), "audit already exists; never overwrite")
    model, normalizer, baseline, original = load_frozen(checkpoint_dir)
    partitions, manifest = net.imported_windows(import_dir)
    ds.require(ds.sha256(ds.canonical_json(manifest)) == baseline["import_manifest_sha256"],
               "frozen import manifest changed")
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    validation_x, validation_y = net.tensors(partitions["validation"])
    with torch.inference_mode():
        validation_logits = model(net.normalize(validation_x, normalizer))
    calibration = fit_temperature(validation_logits, validation_y)
    # Fitting is over before test logits/labels enter the audit.
    test_x, test_y = net.tensors(partitions["test"])
    with torch.inference_mode():
        test_logits = model(net.normalize(test_x, normalizer))
    temperature = calibration["temperature"]
    results = {name: {"before": evaluate(logits, labels, 1.0),
                      "after": evaluate(logits, labels, temperature)}
               for name, logits, labels in (("validation", validation_logits, validation_y),
                                            ("test", test_logits, test_y))}
    for item in results.values():
        ds.require(item["before"]["confusion_matrix_true_rows"] == item["after"]["confusion_matrix_true_rows"],
                   "temperature scaling changed confusion matrix")
    ds.require(ds.canonical_json(net.checkpoint(model, normalizer)) == original,
               "calibration changed frozen weights/normalization")
    calibration.update(source_model_sha256=baseline["model_sha256"], feature_schema=net.FEATURE_VERSION,
                       label_schema="mendeley-driving-behavior-v3", dataset_license=baseline["dataset_license"],
                       attribution=baseline["attribution"])
    report = {"audit_version": VERSION, "production_eligible": False, "calibration": calibration,
              "source_model_sha256": baseline["model_sha256"], "model_weights_unchanged": True,
              "baseline_code_commit": baseline["training_code_commit"],
              "source_import_manifest_sha256": baseline["import_manifest_sha256"],
              "source_dataset": {"dataset_id": baseline["dataset_id"], "version": baseline["dataset_version"],
                                 "source_sha256": baseline["dataset_source_sha256"],
                                 "license": baseline["dataset_license"], "attribution": baseline["attribution"]},
              "class_names": baseline["class_names"], "class_order": list(net.CLASSES),
              "split": net.GROUPS, "results": results,
              "majority_prior_baseline": baseline["majority_baseline"],
              "runtime": {"python": platform.python_version(), "torch": torch.__version__, "device": "cpu"},
              "data_reuse": {"validation_reused_after_checkpoint_selection": True,
                             "test_driver_previously_reported_in_m7_2": True,
                             "fresh_blinded_validation": False},
              "limitations": baseline["limitations"] + [
                  "Retrospective audit: validation driver selected the original checkpoint; test driver was previously reported.",
                  "35 calibration tasks and 39 test tasks are insufficient for population or safety calibration claims.",
                  "No normal/severe truth or production event mapping: false severe events/hour remains unavailable, not zero.",
                  "Disagreements are with source labels, not confirmed real driving errors or causal explanations."],
              **provenance()}
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".calibration-", dir=root) as temporary:
        staging = Path(temporary) / "result"
        staging.mkdir()
        (staging / "calibrator.json").write_bytes(ds.canonical_json(calibration))
        (staging / "report.json").write_bytes(ds.canonical_json(report))
        ds.require(not target.exists(), "audit appeared concurrently")
        staging.rename(target)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-dir", type=Path, required=True)
    parser.add_argument("--import-dir", type=Path, required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    try:
        report = run(args.checkpoint_dir, args.import_dir, args.run_name)
        print(f"Retrospective calibration audit complete; T={report['calibration']['temperature']:.6f}; "
              "production eligible: false.")
        return 0
    except (ds.InvalidDataset, OSError, ValueError, RuntimeError, KeyError, subprocess.SubprocessError):
        print("Calibration audit failed; verify frozen provenance, inputs and output collision.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
