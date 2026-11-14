"""Isolated experimental ONNX export; never loads a production or safety model."""

from __future__ import annotations

import os
# Must precede even importing ORT: official builds otherwise initialize telemetry.
os.environ["ORT_DISABLE_TELEMETRY"] = "1"

import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

import numpy as np
import onnx
import onnxruntime as ort
import torch
from torch import nn
from onnxruntime.quantization import CalibrationDataReader, CalibrationMethod, QuantFormat, QuantType, quantize_static
from onnxruntime.quantization.shape_inference import quant_pre_process

from . import calibration as cal
from . import datasets as ds
from . import eventnet as net

ort.disable_telemetry_events()
VERSION = "eventnet-onnx-mobile-v1"
RUNTIME_VERSION = "1.32.0"
AAR_SHA256 = "8e8dbb412ed4939675a157702f0c1e3621b436a645af7f7244536ac20bfad628"
AAR_URL = "https://repo.maven.apache.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.32.0/onnxruntime-android-1.32.0.aar"
MODEL_FILES = {"fp32": "eventnet-fp32.onnx", "int8": "eventnet-int8.onnx"}
GATES = {"fp32_max_logit_error": 1e-4, "quantized_max_probability_error": 0.05,
         "quantized_test_macro_f1_loss": 0.02, "android_max_logit_error": 1e-3,
         "android_max_probability_error": 1e-4}


class NormalizedModel(nn.Module):
    def __init__(self, model, normalizer):
        super().__init__()
        net.normalize(torch.zeros(1, 6, 7), normalizer)
        self.model = model
        self.register_buffer("mean", torch.tensor(normalizer["mean"], dtype=torch.float32))
        self.register_buffer("scale", torch.tensor(normalizer["scale"], dtype=torch.float32))

    def forward(self, features):
        return self.model((features - self.mean) / self.scale)


def valid_input(value):
    ds.require(isinstance(value, np.ndarray) and value.shape == (1, 6, 7) and value.dtype == np.float32,
               "fixed float32 NCT [1,6,7] input required")
    ds.require(bool(np.isfinite(value).all()) and bool((np.abs(value) <= 1e9).all()), "invalid input values")
    return np.ascontiguousarray(value)


class TrainingReader(CalibrationDataReader):
    def __init__(self, training_inputs):
        ds.require(0 < len(training_inputs) <= 10_000, "bounded training-only quantization input required")
        self.values = [valid_input(value).copy() for value in training_inputs]
        self.index = 0

    def get_next(self):
        if self.index >= len(self.values):
            return None
        value = self.values[self.index]
        self.index += 1
        return {"features": value}


def session(path: Path):
    ds.require(os.environ.get("ORT_DISABLE_TELEMETRY") == "1", "telemetry must be disabled before runtime use")
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    return ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])


def predict(runtime, value):
    output = runtime.run(["logits"], {"features": valid_input(value)})[0]
    ds.require(output.shape == (1, 4) and bool(np.isfinite(output).all()), "invalid exported logits")
    return output[0].astype(np.float64)


def probabilities(logits, temperature):
    ds.require(np.shape(logits) == (4,) and 0.1 <= temperature <= 100 and bool(np.isfinite(logits).all()),
               "invalid probability inputs")
    values = np.asarray(logits, dtype=np.float64) / temperature
    values = np.exp(values - np.max(values))
    return values / values.sum()


def export_pair(model, normalizer, training_inputs, destination: Path):
    ds.require(not destination.exists(), "export destination exists")
    destination.mkdir(parents=True)
    reader = TrainingReader(training_inputs)
    wrapper = NormalizedModel(model.eval(), normalizer).eval()
    fp32 = destination / MODEL_FILES["fp32"]
    # Fixed dimensions, no external tensor files or downloaded/pretrained graph.
    torch.onnx.export(wrapper, torch.zeros(1, 6, 7), str(fp32), dynamo=True, opset_version=18,
                      input_names=["features"], output_names=["logits"], external_data=False, verbose=False)
    onnx.checker.check_model(str(fp32))
    prepared = destination / "prepared.onnx"
    quant_pre_process(str(fp32), str(prepared), skip_optimization=True)
    quantize_static(str(prepared), str(destination / MODEL_FILES["int8"]), reader,
                    quant_format=QuantFormat.QDQ, per_channel=True,
                    activation_type=QuantType.QInt8, weight_type=QuantType.QInt8,
                    calibrate_method=CalibrationMethod.MinMax,
                    extra_options={"ActivationSymmetric": True, "WeightSymmetric": True})
    onnx.checker.check_model(str(destination / MODEL_FILES["int8"]))
    quantized = onnx.load(str(destination / MODEL_FILES["int8"]), load_external_data=False)
    ds.require(any(value.data_type == onnx.TensorProto.INT8 for value in quantized.graph.initializer) and
               any(node.op_type == "DequantizeLinear" for node in quantized.graph.node), "no int8 QDQ quantization found")
    prepared.unlink()
    return wrapper


def generated_inputs():
    """Generated source-space fixtures, never phone sensors or recorded trip windows."""
    values = []
    for index in range(8):
        value = np.zeros((1, 6, 7), dtype=np.float32)
        value[0, 2, :] = -1.0
        if index in (1, 2):
            value[0, 0, 3:] = 0.3 if index == 1 else -0.3
        if index in (3, 4):
            value[0, 5, 3:] = 10.0 if index == 3 else -10.0
        if index == 5:
            value[0, 2, 3] = -1.3
        if index == 6:
            value[0, 4, :] = np.arange(7, dtype=np.float32) - 3
        if index == 7:
            value[0, :, :] += np.arange(7, dtype=np.float32) * 0.01
        values.append(value)
    return values


def write_fixtures(destination, sessions, temperature, quantized_pass):
    fixtures = {"version": VERSION, "shape": [1, 6, 7], "temperature": temperature,
                "gates": GATES, "quantized_numerical_gate_pass": quantized_pass,
                "fixture_origin": "generated_not_sensors_or_recorded_tasks", "cases": []}
    for index, value in enumerate(generated_inputs()):
        references = {kind: predict(runtime, value).tolist() for kind, runtime in sessions.items()}
        fixtures["cases"].append({"name": f"generated-{index}", "features_nct": value.flatten().tolist(),
                                  "references": references})
    fixtures["models"] = {kind: {"file": name, "sha256": ds.sha256((destination / name).read_bytes()),
                                  "bytes": (destination / name).stat().st_size} for kind, name in MODEL_FILES.items()}
    (destination / "fixtures.json").write_bytes(ds.canonical_json(fixtures))
    return fixtures


def compare(wrapper, sessions, rows, temperature):
    labels, fp_prob, qt_prob = [], [], []
    max_float = max_probability = max_quantized = 0.0
    for row in rows:
        value = np.array(row["values"], dtype=np.float32).T[None, :, :]
        with torch.inference_mode():
            reference = wrapper(torch.from_numpy(value)).numpy()[0].astype(np.float64)
        fp = predict(sessions["fp32"], value)
        qt = predict(sessions["int8"], value)
        max_float = max(max_float, float(np.max(np.abs(reference - fp))))
        max_quantized = max(max_quantized, float(np.max(np.abs(fp - qt))))
        before, after = probabilities(fp, temperature), probabilities(qt, temperature)
        max_probability = max(max_probability, float(np.max(np.abs(before - after))))
        labels.append(row["label"])
        fp_prob.append(before.tolist())
        qt_prob.append(after.tolist())
    metrics = {"fp32_metrics": net.metrics(labels, fp_prob), "int8_metrics": net.metrics(labels, qt_prob)}
    for value in metrics.values():
        value["probability_status"] = "retrospective_frozen_temperature_experimental"
    return {"fp32_max_logit_error": max_float, "int8_max_logit_error": max_quantized,
            "int8_max_probability_error": max_probability,
            **metrics}


def provenance():
    files = ["ml/mobile_export.py", "ml/requirements-mobile.txt", "docs/reference/EVENTNET_MOBILE_V1.md",
             "ml/verify_mobile_apk.py", "ml/android-benchmark/build.gradle",
             "ml/android-benchmark/src/main/AndroidManifest.xml",
             "ml/android-benchmark/src/main/res/xml/no_backup.xml",
             "ml/android-benchmark/src/main/java/io/github/atrx07/traelyx/mlbenchmark/BenchmarkInstrumentation.java",
             "ml/android-benchmark/src/main/java/io/github/atrx07/traelyx/mlbenchmark/BenchmarkMath.java"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, capture_output=True, text=True, check=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT,
                                capture_output=True, text=True, check=True).stdout)
    return {"export_code_commit": commit, "export_source_dirty": dirty,
            "export_source_sha256": {name: ds.sha256((ds.ROOT / name).read_bytes()) for name in files}}


def run(checkpoint_dir: Path, calibrator_dir: Path, import_dir: Path, run_name: str):
    ds.require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", run_name), "invalid export name")
    ds.require((torch.__version__, ort.__version__, onnx.__version__, np.__version__) ==
               ("2.15.0+cpu", "1.32.0", "1.23.2", "2.5.4"), "use pinned export environment")
    model, normalizer, baseline, _ = cal.load_frozen(checkpoint_dir)
    audit = ds.load_json(ds.ROOT / "docs/reference/eventnet-calibration-v1-result.json")
    ds.require((calibrator_dir / "calibrator.json").stat().st_size <= 256 * 1024, "calibrator too large")
    raw_calibrator = (calibrator_dir / "calibrator.json").read_bytes()
    ds.require(len(raw_calibrator) <= 256 * 1024 and ds.sha256(raw_calibrator) == audit["calibrator_sha256"],
               "preserved calibrator digest mismatch")
    calibrator = json.loads(raw_calibrator)
    ds.require(calibrator["source_model_sha256"] == baseline["model_sha256"] and
               calibrator["production_eligible"] is False, "experimental source mismatch")
    partitions, manifest = net.imported_windows(import_dir)
    ds.require(ds.sha256(ds.canonical_json(manifest)) == baseline["import_manifest_sha256"], "frozen data mismatch")
    root = ds.ROOT / "ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output link denied")
    target = root / run_name
    ds.require(not target.exists() and not target.is_symlink(), "export exists; never overwrite")
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    temperature = calibrator["temperature"]
    training = [np.array(row["values"], dtype=np.float32).T[None, :, :] for row in partitions["train"]]
    with tempfile.TemporaryDirectory(prefix=".mobile-export-", dir=root) as temporary:
        staging = Path(temporary) / "result"
        wrapper = export_pair(model, normalizer, training, staging)
        sessions = {kind: session(staging / filename) for kind, filename in MODEL_FILES.items()}
        comparisons = {name: compare(wrapper, sessions, rows, temperature) for name, rows in partitions.items()}
        float_pass = all(value["fp32_max_logit_error"] <= GATES["fp32_max_logit_error"] for value in comparisons.values())
        quantized_pass = all(value["int8_max_probability_error"] <= GATES["quantized_max_probability_error"]
                             for value in comparisons.values()) and (
            comparisons["test"]["fp32_metrics"]["macro_f1"] - comparisons["test"]["int8_metrics"]["macro_f1"]
            <= GATES["quantized_test_macro_f1_loss"])
        ds.require(float_pass, "float export parity failed")
        fixtures = write_fixtures(staging, sessions, temperature, quantized_pass)
        model_info = fixtures["models"]
        report = {"export_version": VERSION, "production_eligible": False, "model_status": "experiment",
                  "feature_schema": net.FEATURE_VERSION, "source_model_sha256": baseline["model_sha256"],
                  "calibrator_sha256": audit["calibrator_sha256"], "temperature": temperature,
                  "quantization": {"format": "S8S8_per_channel_QDQ_MinMax", "range_fit_partition": "train",
                                   "range_fit_windows": len(training), "alternatives_searched": False},
                  "gates": GATES, "fp32_numerical_gate_pass": float_pass,
                  "quantized_numerical_gate_pass": quantized_pass, "partition_comparisons": comparisons,
                  "models": model_info, "fixtures_sha256": ds.sha256((staging / "fixtures.json").read_bytes()),
                  "runtime": {"torch": torch.__version__, "onnx": onnx.__version__, "onnxruntime": ort.__version__,
                              "numpy": np.__version__, "execution_provider": "CPUExecutionProvider", "telemetry_disabled": True},
                  "android_runtime": {"version": RUNTIME_VERSION, "aar_sha256": AAR_SHA256, "min_sdk": 24},
                  "attribution": baseline["attribution"], "limitations": audit["limitations"] + [
                      "One quantization configuration; numerical failure rejects integration, without test-driven retries.",
                      "Model/graph metadata overhead may exceed weight savings for this 492-parameter experiment.",
                      "Host parity and isolated generated-input phone timings are not production safety or battery validation."],
                  **provenance()}
        (staging / "export-report.json").write_bytes(ds.canonical_json(report))
        del sessions
        ds.require(not target.exists(), "export appeared concurrently")
        staging.rename(target)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint-dir", type=Path, required=True)
    parser.add_argument("--calibrator-dir", type=Path, required=True)
    parser.add_argument("--import-dir", type=Path, required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    report = run(args.checkpoint_dir, args.calibrator_dir, args.import_dir, args.run_name)
    print(f"Experimental mobile export complete; int8 numerical gate: {report['quantized_numerical_gate_pass']}; production eligible: false.")


if __name__ == "__main__":
    main()
