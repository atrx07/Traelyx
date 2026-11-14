"""EventNet source-space CPU experiment v1. No app or safety-state integration."""

from __future__ import annotations

import argparse
import copy
import csv
import io
import math
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile

import torch
from torch import nn
from torch.nn import functional as F

from . import datasets as ds

MODEL_VERSION = "eventnet-source-tcn-v1"
FEATURE_VERSION = "eventnet-source-imu-v1"
WINDOW = 7
CLASSES = ("1", "2", "3", "4")
GROUPS = {"source-driver-1": "train", "source-driver-2": "validation", "source-driver-3": "test"}
CONFIG = {"seed": 7462, "epochs": 60, "learning_rate": 0.01, "width": 8,
          "kernel_size": 3, "dilations": [1, 2], "threads": 1}


class CausalBlock(nn.Module):
    def __init__(self, width: int, dilation: int):
        super().__init__()
        self.left_padding = 2 * dilation
        self.conv = nn.Conv1d(width, width, 3, dilation=dilation)

    def forward(self, value):
        return F.relu(value + self.conv(F.pad(value, (self.left_padding, 0))))


class EventNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.project = nn.Conv1d(6, CONFIG["width"], 1)
        self.blocks = nn.Sequential(*(CausalBlock(CONFIG["width"], dilation)
                                      for dilation in CONFIG["dilations"]))
        self.classifier = nn.Linear(CONFIG["width"], len(CLASSES))

    def encode(self, value):
        return self.blocks(F.relu(self.project(value)))

    def forward(self, value):
        return self.classifier(self.encode(value).mean(dim=2))


def imported_windows(directory: Path) -> tuple[dict, dict]:
    """Verify provenance/split first; only then form one trailing window per task."""
    manifest = ds.load_json(directory / "manifest.json")
    expected = next(entry for entry in ds.registry_entries()
                    if entry["dataset_id"] == "mendeley-driving-behavior" and entry["version"] == "3")
    ds.require(manifest.get("registry_entry") == expected, "experiment source registry mismatch")
    ds.require(manifest.get("registry_entry_sha256") == ds.sha256(ds.canonical_json(expected)),
               "experiment registry digest mismatch")
    ds.require(manifest.get("source_sha256") == expected["source_sha256"] and
               manifest.get("source_bytes") == expected["source_bytes"] and
               manifest.get("import_version") == ds.IMPORT_VERSION, "experiment source identity mismatch")
    path = directory / "samples.csv"
    with path.open("rb") as stream:
        raw = stream.read(ds.MAX_SOURCE_BYTES + 1)
    ds.require(len(raw) <= ds.MAX_SOURCE_BYTES, "experiment sample size limit")
    ds.require(ds.sha256(raw) == manifest.get("samples_sha256"), "experiment samples digest mismatch")
    try:
        reader = csv.DictReader(io.StringIO(raw.decode("utf-8"), newline=""), strict=True)
        ds.require(reader.fieldnames == ds.OUTPUT_HEADER, "experiment feature columns mismatch")
        tasks = {}
        last_task = None
        partitions = {name: [] for name in ("train", "validation", "test")}
        partition_counts = {}
        label_counts = {}
        count = 0
        for index, row in enumerate(reader):
            count += 1
            ds.require(count <= ds.MAX_ROWS and None not in row and None not in row.values(),
                       "experiment malformed row")
            ds.require(row["sample_index"] == str(index), "experiment sample order mismatch")
            driver, task, partition = (row[name] for name in ("driver_group", "trip_group", "partition"))
            label = row["source_label"]
            ds.require(driver in GROUPS and partition == GROUPS[driver], "driver partition leakage")
            ds.require(label in CLASSES and row["source_label_name"] == expected["source_labels"][label],
                       "experiment label mismatch")
            ds.require(re.fullmatch(re.escape(driver) + "-c" + label + r"-t[1-9][0-9]{0,3}", task),
                       "experiment task identity mismatch")
            ds.require(re.fullmatch(r"[0-9]{1,12}", row["elapsed_ms"]), "invalid relative time")
            elapsed = int(row["elapsed_ms"])
            values = [float(row[channel]) for channel in ds.CHANNELS]
            ds.require(all(math.isfinite(value) and abs(value) <= 1e9 for value in values),
                       "experiment non-finite/unbounded feature")
            if task not in tasks:
                ds.require(elapsed == 0, "task must begin at relative zero")
                tasks[task] = {"driver": driver, "partition": partition, "label": label,
                               "values": [], "previous_elapsed": 0}
            elif task != last_task:
                raise ds.InvalidDataset("experiment noncontiguous task")
            item = tasks[task]
            ds.require((driver, partition, label) == (item["driver"], item["partition"], item["label"]),
                       "experiment task provenance changed")
            ds.require(elapsed >= item["previous_elapsed"], "experiment time reversal")
            item["previous_elapsed"] = elapsed
            item["values"].append(values)
            last_task = task
            partition_counts[partition] = partition_counts.get(partition, 0) + 1
            label_counts[label] = label_counts.get(label, 0) + 1
        ds.require(count == expected["source_expected_rows"] == manifest.get("record_count") and
                   len(tasks) == expected["source_expected_tasks"], "experiment population mismatch")
        ds.require(partition_counts == manifest.get("partition_counts") and
                   label_counts == manifest.get("source_label_counts"), "experiment count mismatch")
        # Every row's driver partition has been checked before any window exists.
        for task, item in tasks.items():
            ds.require(len(item["values"]) >= WINDOW, "task shorter than fixed window")
            partitions[item["partition"]].append({"task": task, "driver": item["driver"],
                                                  "label": CLASSES.index(item["label"]),
                                                  "values": item["values"][-WINDOW:]})
        ds.require(all({item["label"] for item in rows} == set(range(4))
                       for rows in partitions.values()), "all source classes required per partition")
        return partitions, manifest
    except (ValueError, csv.Error, UnicodeError, OverflowError) as error:
        if isinstance(error, ds.InvalidDataset):
            raise
        raise ds.InvalidDataset("invalid experiment feature input") from None


def tensors(rows: list[dict]):
    x = torch.tensor([row["values"] for row in rows], dtype=torch.float32).transpose(1, 2)
    y = torch.tensor([row["label"] for row in rows], dtype=torch.long)
    ds.require(x.ndim == 3 and x.shape[1:] == (6, WINDOW) and bool(torch.isfinite(x).all()),
               "invalid feature tensor")
    ds.require(bool(((y >= 0) & (y < 4)).all()), "invalid class tensor")
    return x, y


def fit_normalizer(train):
    mean = train.mean(dim=(0, 2), keepdim=True)
    scale = train.std(dim=(0, 2), unbiased=False, keepdim=True)
    scale = torch.where(scale < 1e-6, torch.ones_like(scale), scale)
    return {"mean": mean.tolist(), "scale": scale.tolist()}


def normalize(value, normalizer):
    mean = torch.tensor(normalizer["mean"], dtype=torch.float32)
    scale = torch.tensor(normalizer["scale"], dtype=torch.float32)
    ds.require(mean.shape == scale.shape == (1, 6, 1) and bool(torch.isfinite(mean).all()) and
               bool(torch.isfinite(scale).all()) and bool((scale > 0).all()), "invalid normalizer")
    result = (value - mean) / scale
    ds.require(bool(torch.isfinite(result).all()), "non-finite normalized feature")
    return result


def fit(train_rows: list, validation_rows: list) -> tuple[EventNet, dict, dict]:
    """No test argument: selection can depend only on train and validation."""
    torch.set_num_threads(CONFIG["threads"])
    torch.use_deterministic_algorithms(True)
    torch.manual_seed(CONFIG["seed"])
    x, y = tensors(train_rows)
    vx, vy = tensors(validation_rows)
    normalizer = fit_normalizer(x)
    x, vx = normalize(x, normalizer), normalize(vx, normalizer)
    model = EventNet()
    optimizer = torch.optim.Adam(model.parameters(), lr=CONFIG["learning_rate"])
    best_loss, best_state, best_epoch = math.inf, None, 0
    history = []
    for epoch in range(1, CONFIG["epochs"] + 1):
        model.train()
        optimizer.zero_grad()
        loss = F.cross_entropy(model(x), y)
        ds.require(bool(torch.isfinite(loss)), "non-finite training loss")
        loss.backward()
        optimizer.step()
        model.eval()
        with torch.no_grad():
            validation_loss = float(F.cross_entropy(model(vx), vy))
        ds.require(math.isfinite(validation_loss), "non-finite validation loss")
        history.append({"epoch": epoch, "train_loss": float(loss.detach()), "validation_loss": validation_loss})
        if validation_loss < best_loss:
            best_loss, best_epoch = validation_loss, epoch
            best_state = copy.deepcopy(model.state_dict())
    ds.require(best_state is not None, "no finite checkpoint")
    model.load_state_dict(best_state)
    return model.eval(), normalizer, {"selected_epoch": best_epoch, "history": history,
                                      "selection": "minimum_validation_cross_entropy_earliest_tie"}


def metrics(labels: list[int], probabilities: list[list[float]]) -> dict:
    ds.require(len(labels) == len(probabilities) > 0, "empty/mismatched evaluation")
    matrix = [[0] * 4 for _ in range(4)]
    brier = nll = 0.0
    for label, values in zip(labels, probabilities):
        ds.require(type(label) is int and 0 <= label < 4 and len(values) == 4,
                   "invalid evaluation class")
        ds.require(all(math.isfinite(value) and 0 <= value <= 1 for value in values) and
                   abs(sum(values) - 1) <= 1e-5, "invalid probability vector")
        prediction = max(range(4), key=values.__getitem__)
        matrix[label][prediction] += 1
        brier += sum((value - int(index == label)) ** 2 for index, value in enumerate(values))
        nll -= math.log(max(values[label], 1e-12))
    per_class = {}
    for index, label in enumerate(CLASSES):
        tp, support = matrix[index][index], sum(matrix[index])
        predicted = sum(row[index] for row in matrix)
        precision = tp / predicted if predicted else 0.0
        recall = tp / support if support else 0.0
        f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
        per_class[label] = {"precision": precision, "recall": recall, "f1": f1, "support": support}
    return {"per_class": per_class, "macro_f1": sum(row["f1"] for row in per_class.values()) / 4,
            "confusion_matrix_true_rows": matrix, "examples": len(labels),
            "brier_multiclass_sum": brier / len(labels), "negative_log_likelihood": nll / len(labels),
            "probability_status": "uncalibrated", "false_severe_events_per_hour": None,
            "detection_latency_ms": None, "severe_pr_auc": None,
            "unavailable_reason": "No severe/negative truth or trustworthy high-rate time axis."}


def checkpoint(model: EventNet, normalizer: dict) -> dict:
    # Small JSON tensors avoid pickle execution and non-deterministic ZIP metadata.
    return {"format": "traelyx-eventnet-weights-v1", "model_version": MODEL_VERSION,
            "feature_schema": FEATURE_VERSION, "config": CONFIG, "normalizer": normalizer,
            "state": {name: tensor.tolist() for name, tensor in model.state_dict().items()}}


def restore(value: dict) -> tuple[EventNet, dict]:
    ds.require(value.get("format") == "traelyx-eventnet-weights-v1" and
               value.get("model_version") == MODEL_VERSION and value.get("feature_schema") == FEATURE_VERSION
               and value.get("config") == CONFIG, "checkpoint contract mismatch")
    model = EventNet()
    expected = model.state_dict()
    ds.require(set(value["state"]) == set(expected), "checkpoint parameter mismatch")
    state = {}
    for name, reference in expected.items():
        tensor = torch.tensor(value["state"][name], dtype=torch.float32)
        ds.require(tensor.shape == reference.shape and bool(torch.isfinite(tensor).all()),
                   "checkpoint tensor mismatch")
        state[name] = tensor
    model.load_state_dict(state)
    normalize(torch.zeros(1, 6, WINDOW), value["normalizer"])
    return model.eval(), value["normalizer"]


def code_provenance() -> dict:
    files = ["ml/eventnet.py", "ml/datasets.py", "ml/registry/mendeley-driving-behavior-v3.json",
             "docs/reference/dataset-registry-v2.schema.json", "ml/requirements-eventnet.txt"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, capture_output=True,
                            text=True, check=True).stdout.strip()
    dirty = subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT,
                           capture_output=True, text=True, check=True).stdout != ""
    return {"training_code_commit": commit, "training_source_dirty": dirty,
            "source_files_sha256": {name: ds.sha256((ds.ROOT / name).read_bytes()) for name in files}}


def run(directory: Path, run_name: str) -> dict:
    ds.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", run_name), "invalid run name")
    ds.require(torch.__version__ == "2.15.0+cpu", "use the pinned CPU training environment")
    root = ds.ROOT / "ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)),
               "checkpoint output ancestors cannot be links")
    root.mkdir(parents=True, exist_ok=True)
    target = root / run_name
    ds.require(not target.exists() and not target.is_symlink(), "run already exists; never overwrite")
    partitions, manifest = imported_windows(directory)
    model, normalizer, selection = fit(partitions["train"], partitions["validation"])
    # The held-out test is evaluated once, after checkpoint selection has ended.
    x, labels = tensors(partitions["test"])
    with torch.no_grad():
        probabilities = model(normalize(x, normalizer)).softmax(dim=1).tolist()
    label_list = labels.tolist()
    train_counts = [sum(item["label"] == label for item in partitions["train"]) for label in range(4)]
    majority = max(range(4), key=train_counts.__getitem__)
    prior = [count / sum(train_counts) for count in train_counts]
    state_bytes = ds.canonical_json(checkpoint(model, normalizer))
    report = {
        "model_version": MODEL_VERSION, "model_status": "experiment", "production_eligible": False,
        "feature_schema": FEATURE_VERSION, "config": CONFIG, "class_order": list(CLASSES),
        "class_names": manifest["source_labels"], "parameters": sum(p.numel() for p in model.parameters()),
        "model_sha256": ds.sha256(state_bytes), "model_json_bytes": len(state_bytes),
        "dataset_id": manifest["dataset_id"], "dataset_version": manifest["dataset_version"],
        "dataset_source_sha256": manifest["source_sha256"], "import_manifest_sha256": ds.sha256(ds.canonical_json(manifest)),
        "split": GROUPS, "window_policy": "one_trailing_7_row_window_per_driver_class_task",
        "partition_examples": {name: len(rows) for name, rows in partitions.items()},
        "normalization_fit_partition": "train", "selection": selection,
        "test_metrics": metrics(label_list, probabilities),
        "majority_baseline": {"class": CLASSES[majority], "metrics": metrics(label_list, [prior] * len(label_list))},
        "predictions": [{"task": row["task"], "source_label": CLASSES[label],
                         "uncalibrated_probabilities": probability}
                        for row, label, probability in zip(partitions["test"], label_list, probabilities)],
        "runtime": {"python": platform.python_version(), "torch": torch.__version__, "platform": platform.system(),
                    "device": "cpu", "deterministic_algorithms": True},
        "limitations": manifest["known_limitations"] + [
            "No governed Traelyx event/score mapping, calibration, severe-event claim or mobile benchmark.",
            "Reproducibility is checked within the pinned environment; cross-platform numeric identity is not promised."],
        **code_provenance(),
    }
    with tempfile.TemporaryDirectory(prefix=".eventnet-", dir=root) as temporary:
        staging = Path(temporary) / "result"
        staging.mkdir()
        (staging / "checkpoint.json").write_bytes(state_bytes)
        (staging / "report.json").write_bytes(ds.canonical_json(report))
        ds.require(not target.exists(), "run appeared concurrently")
        staging.rename(target)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-dir", type=Path, required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    try:
        report = run(args.import_dir, args.run_name)
        print(f"EventNet experiment complete: {report['parameters']} parameters; "
              f"held-out macro F1 {report['test_metrics']['macro_f1']:.4f}; production eligible: false.")
        return 0
    except (ds.InvalidDataset, OSError, ValueError, RuntimeError, KeyError):
        print("EventNet experiment failed; verify source provenance, pinned environment and output collision.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
