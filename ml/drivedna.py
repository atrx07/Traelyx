"""Generated self-supervised embedding experiment; no production Drive DNA changes."""

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

from . import datasets as ds, drivedna_corpus as corpus

SPEC = corpus.SPEC
CONFIG = SPEC["config"]
PROGRAMS = tuple(SPEC["programs"])
VERSION = "drivedna-generated-ae-v1"
ds.require(SPEC["experiment_version"] == VERSION and SPEC["production_eligible"] is False and
           len(SPEC["features"]) == 8 and len(PROGRAMS) == 5, "unsupported experiment manifest")


def _pairs(items):
    result = {}
    for key, value in items:
        ds.require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def physical_features(value):
    return (type(value) is list and len(value) == 8 and
            all(type(number) in (int, float) and math.isfinite(number) and 0 <= number <= 1000 for number in value) and
            value[6] <= 1 and all(value[index] <= value[index+1]+1e-9 for index in (0, 2, 4)))


def eligible(row):
    return row["supported"] is True and physical_features(row["features"]) and row["features"][6] <= 1-SPEC["minimum_moving_fraction"]


def load_source(path, digest):
    ds.require(type(digest) is str and re.fullmatch(r"[a-f0-9]{64}", digest), "source digest required")
    with path.open("rb") as stream: raw = stream.read(2*1024*1024+1)
    ds.require(len(raw) <= 2*1024*1024 and ds.sha256(raw) == digest, "source size/hash mismatch")
    value = json.loads(raw, object_pairs_hook=_pairs)
    header = dict(format=corpus.VERSION, source_kind="generated_only", feature_schema=SPEC["feature_schema"],
                  duration_seconds=60, sample_interval_ms=1000, coordinate_frame="generated_vehicle",
                  manifest_sha256=ds.sha256(ds.canonical_json(SPEC)))
    ds.require(type(value) is dict and set(value) == set(header)|{"cases"} and
               all(type(value[key]) is type(item) and value[key] == item for key, item in header.items()) and
               type(value["cases"]) is list and len(value["cases"]) == 408, "unsupported source contract")
    expected = {row["id"]: row for row in corpus.case_specs()}
    for row in value["cases"]:
        ds.require(type(row) is dict and set(row) == {"id", "group", "partition", "vehicle_scope", "driving_context", "category", "program", "variant", "features", "supported"}, "invalid case fields")
        ds.require(type(row["id"]) is str and row["id"] in expected, "duplicate or unknown case")
        descriptor = expected.pop(row["id"])
        ds.require(all(type(row[key]) is type(item) and row[key] == item for key, item in descriptor.items()), "group/scope/partition mismatch")
        ds.require(type(row["supported"]) is bool and row["supported"] == (row["category"] != "unsupported"), "invalid support")
        if row["category"] == "missing": ds.require(row["features"] is None, "missing evidence must remain missing")
        else:
            ds.require(physical_features(row["features"]), "invalid physical summaries")
            if row["category"] == "stationary": ds.require(row["features"] == [0., 0., 0., 0., 0., 0., 1., 0.], "invalid stationary diagnostics")
        ds.require(eligible(row) == (row["category"] == "supported"), "eligibility mismatch")
    ds.require(not expected, "incomplete source")
    parts = {part: [row for row in value["cases"] if row["partition"] == part] for part in ("train", "validation", "test")}
    ds.require([len(rows) for rows in parts.values()] == [200, 104, 104], "partition mismatch")
    return parts


class DriveDnaEncoder(nn.Module):
    def __init__(self):
        super().__init__()
        self.encoder = nn.Sequential(nn.Linear(8, CONFIG["hidden"]), nn.Tanh(), nn.Linear(CONFIG["hidden"], CONFIG["latent"]))
        self.decoder = nn.Sequential(nn.Linear(CONFIG["latent"], CONFIG["hidden"]), nn.Tanh(), nn.Linear(CONFIG["hidden"], 8))

    def forward(self, value):
        return self.decoder(self.encoder(value))


def tensor(rows):
    ds.require(0 < len(rows) <= 408 and all(eligible(row) for row in rows), "complete supported summaries required")
    return torch.tensor([row["features"] for row in rows], dtype=torch.float32, device="cpu")


def checked_normalizer(value):
    ds.require(type(value) is dict and set(value) == {"mean", "scale"} and all(
        type(value[key]) is list and len(value[key]) == 8 and all(type(number) in (int, float) and
        math.isfinite(number) and abs(number) <= 1000 for number in value[key]) for key in ("mean", "scale")), "invalid normalization")
    mean, scale = (torch.tensor(value[key], dtype=torch.float32) for key in ("mean", "scale"))
    ds.require(bool((scale >= CONFIG["normalizer_scale_floor"]).all()), "invalid scale")
    return mean, scale


def normalized(rows, normalizer):
    mean, scale = checked_normalizer(normalizer)
    values = (tensor(rows)-mean)/scale
    ds.require(bool(torch.isfinite(values).all()), "nonfinite normalized features")
    return values


def fit(rows):
    ds.require(all(row["partition"] == "train" and row["category"] == "supported" for row in rows), "training supported cases only")
    torch.set_num_threads(CONFIG["threads"])
    torch.use_deterministic_algorithms(True)
    torch.manual_seed(CONFIG["seed"])
    values = tensor(rows)
    norm = {"mean": values.mean(dim=0).tolist(), "scale": values.std(dim=0, unbiased=False).clamp_min(CONFIG["normalizer_scale_floor"]).tolist()}
    target = normalized(rows, norm)
    generator = torch.Generator(device="cpu").manual_seed(CONFIG["augmentation_seed"])
    noisy = target+torch.randn(target.shape, generator=generator)*CONFIG["training_noise_std"]
    model = DriveDnaEncoder().cpu()
    optimizer = torch.optim.Adam(model.parameters(), lr=CONFIG["learning_rate"])
    losses = []
    for _ in range(CONFIG["epochs"]):
        optimizer.zero_grad()
        loss = nn.functional.mse_loss(model(noisy), target)
        ds.require(bool(torch.isfinite(loss)), "nonfinite training loss")
        loss.backward()
        optimizer.step()
        losses.append(float(loss.detach()))
    return model.eval(), norm, {"cases": len(rows), "initial_loss": losses[0], "last_epoch_loss": losses[-1], "target": "clean_normalized_training_summaries_only"}


def representations(model, norm, rows, identity):
    ds.require(type(identity) is str and re.fullmatch(r"[a-f0-9]{64}", identity), "representation identity required")
    complete = [row for row in rows if eligible(row)]
    if not complete: return {}
    values = normalized(complete, norm)
    if model is not None:
        with torch.inference_mode(): values = model.encoder(values)
    width = 8 if model is None else CONFIG["latent"]
    ds.require(values.shape == (len(complete), width) and bool(torch.isfinite(values).all()), "invalid representation")
    # Independently bind actual weights/statistics, even if a caller accidentally
    # reuses an external identity for a different coordinate space.
    binding = ds.sha256(ds.canonical_json(checkpoint(model, norm, "0"*64) if model is not None else
                                         dict(version=SPEC["baseline_version"], normalizer=norm, feature_schema=SPEC["feature_schema"])))
    return {row["id"]: dict(representation=SPEC["baseline_version"] if model is None else VERSION, identity=identity,
                           coordinate_space_sha256=binding,
                           feature_schema=SPEC["feature_schema"], dataset_id=SPEC["dataset_id"], vehicle_scope=row["vehicle_scope"],
                           driving_context=row["driving_context"], sensor_scope=SPEC["sensor_scope"], mount_scope=SPEC["mount_scope"],
                           vector=vector) for row, vector in zip(complete, values.tolist())}


def distance(left, right):
    fields = {"representation", "identity", "coordinate_space_sha256", "feature_schema", "dataset_id", "vehicle_scope", "driving_context", "sensor_scope", "mount_scope", "vector"}
    for record in (left, right):
        ds.require(type(record) is dict and set(record) == fields and record["representation"] in (VERSION, SPEC["baseline_version"]) and
                   type(record["identity"]) is str and re.fullmatch(r"[a-f0-9]{64}", record["identity"]) and
                   type(record["coordinate_space_sha256"]) is str and re.fullmatch(r"[a-f0-9]{64}", record["coordinate_space_sha256"]) and
                   record["feature_schema"] == SPEC["feature_schema"] and record["dataset_id"] == SPEC["dataset_id"] and
                   record["vehicle_scope"] in SPEC["vehicle_scopes"] and record["driving_context"] in SPEC["driving_contexts"] and
                   record["sensor_scope"] == SPEC["sensor_scope"] and record["mount_scope"] == SPEC["mount_scope"], "unsupported representation contract")
        vector = record["vector"]
        ds.require(type(vector) is list and len(vector) == (3 if record["representation"] == VERSION else 8) and
                   all(type(number) in (int, float) and math.isfinite(number) and abs(number) <= 1e9 for number in vector), "invalid vector")
    ds.require(all(left[field] == right[field] for field in fields-{"vector"}), "incompatible representation or cohort")
    return math.sqrt(sum((a-b)**2 for a, b in zip(left["vector"], right["vector"])))


def paired_rows(rows):
    supported = [row for row in rows if row["category"] == "supported"]
    index = {(row["group"], row["vehicle_scope"], row["driving_context"], row["program"], row["variant"]): row for row in supported}
    ds.require(len(index) == len(supported) and supported, "unique paired cases required")
    pairs = []
    for row in supported:
        if row["variant"] != 1: continue
        common = (row["group"], row["vehicle_scope"], row["driving_context"])
        next_program = PROGRAMS[(PROGRAMS.index(row["program"])+1) % len(PROGRAMS)]
        ds.require((*common, row["program"], 2) in index and (*common, next_program, 2) in index, "incomplete paired cases")
        pairs.append((row, index[(*common, row["program"], 2)], index[(*common, next_program, 2)]))
    ds.require(len(pairs)*2 == len(supported), "complete variant pairs required")
    return pairs


def training_cutoff(rows, records):
    ds.require(rows and all(row["partition"] == "train" and row["category"] == "supported" for row in rows), "training pairs only")
    values = sorted(distance(records[reference["id"]], records[stable["id"]]) for reference, stable, _ in paired_rows(rows))
    return {"value": values[math.ceil(CONFIG["normal_pair_quantile"]*len(values))-1]+CONFIG["distance_floor"],
            "pairs": len(values), "fit_partition": "train_generated_correspondence", "quantile": CONFIG["normal_pair_quantile"]}


def retrieval(queries, anchors, records, anchor_records):
    ds.require(anchors and all(row["partition"] == "train" and eligible(row) for row in anchors), "training anchors only")
    matrix = [[0]*5 for _ in PROGRAMS]
    reciprocal = []
    for row in queries:
        cohort = [anchor for anchor in anchors if (anchor["vehicle_scope"], anchor["driving_context"]) == (row["vehicle_scope"], row["driving_context"])]
        ranked = []
        for program in PROGRAMS:
            candidates = [(distance(records[row["id"]], anchor_records[anchor["id"]]), anchor["id"]) for anchor in cohort if anchor["program"] == program]
            ds.require(candidates, "incomplete program anchors")
            value, identity = min(candidates)
            ranked.append((value, program, identity))
        order = [item[1] for item in sorted(ranked)]
        matrix[PROGRAMS.index(row["program"])][PROGRAMS.index(order[0])] += 1
        reciprocal.append(1/(order.index(row["program"])+1))
    per_program = {}
    for index, program in enumerate(PROGRAMS):
        true, support, predicted = matrix[index][index], sum(matrix[index]), sum(row[index] for row in matrix)
        precision, recall = true/predicted if predicted else 0., true/support if support else 0.
        per_program[program] = dict(precision=precision, recall=recall, f1=2*precision*recall/(precision+recall) if precision+recall else 0., support=support)
    ds.require(queries, "supported queries required")
    return dict(cases=len(queries), macro_f1=sum(item["f1"] for item in per_program.values())/5, per_program=per_program,
                top_1_hit_rate=sum(matrix[index][index] for index in range(5))/len(queries), mean_reciprocal_rank=math.fsum(reciprocal)/len(queries),
                confusion_true_rows=matrix)


def deviation(rows, records, cutoff):
    ds.require(type(cutoff) in (int, float) and math.isfinite(cutoff) and cutoff > 0, "invalid distance cutoff")
    outcomes = []
    for reference, stable, changed in paired_rows(rows):
        same = distance(records[reference["id"]], records[stable["id"]]) > cutoff
        different = distance(records[reference["id"]], records[changed["id"]]) > cutoff
        outcomes.append((reference["vehicle_scope"]+"/"+reference["driving_context"], same, different))
    def summarize(values):
        ds.require(values, "deviation pairs required")
        false, detected = sum(item[1] for item in values), sum(item[2] for item in values)
        return dict(stable_pairs=len(values), changed_pairs=len(values), stable_false_flags=false, changed_detections=detected,
                    stable_false_flag_rate=false/len(values), changed_detection_rate=detected/len(values),
                    confusion_true_stable_changed_rows=[[len(values)-false, false], [len(values)-detected, detected]])
    return dict(overall=summarize(outcomes), by_cohort={key: summarize([row for row in outcomes if row[0] == key]) for key in sorted({row[0] for row in outcomes})})


def evaluate(model, norm, training, rows, identities, cutoffs):
    ds.require(rows and len({row["partition"] for row in rows}) == 1 and rows[0]["partition"] in ("validation", "test"), "held-out evaluation only")
    supported = [row for row in rows if row["category"] == "supported"]
    results = {}
    for kind, candidate in (("embedding", model), ("summary", None)):
        records = representations(candidate, norm, rows, identities[kind])
        anchors = representations(candidate, norm, training, identities[kind])
        results[kind] = dict(retrieval=retrieval(supported, training, records, anchors), deviation=deviation(rows, records, cutoffs[kind]["value"]),
                             diagnostics={category: {"cases": sum(row["category"] == category for row in rows),
                                                     "abstentions": sum(row["category"] == category and row["id"] not in records for row in rows)}
                                          for category in ("missing", "unsupported", "stationary")},
                             ineligible_inferred=sum(row["category"] != "supported" and row["id"] in records for row in rows))
    return results


def value_gate(result):
    model, baseline = result["embedding"], result["summary"]
    m, b = model["retrieval"], baseline["retrieval"]
    md, bd = model["deviation"], baseline["deviation"]
    checks = dict(material_gain=m["macro_f1"] >= b["macro_f1"]+CONFIG["minimum_retrieval_f1_gain"] or
                  md["overall"]["changed_detection_rate"] >= bd["overall"]["changed_detection_rate"]+CONFIG["minimum_change_detection_gain"],
                  retrieval_preserved=m["macro_f1"] >= b["macro_f1"] and m["mean_reciprocal_rank"] >= b["mean_reciprocal_rank"] and all(m["per_program"][label]["recall"] >= b["per_program"][label]["recall"] for label in PROGRAMS),
                  deviation_preserved=all(md[key]["stable_false_flag_rate"] <= bd[key]["stable_false_flag_rate"] and md[key]["changed_detection_rate"] >= bd[key]["changed_detection_rate"] for key in ("overall",)) and all(
                      md["by_cohort"][key]["stable_false_flag_rate"] <= item["stable_false_flag_rate"] and md["by_cohort"][key]["changed_detection_rate"] >= item["changed_detection_rate"] for key, item in bd["by_cohort"].items()),
                  quality_preserved=all(item["ineligible_inferred"] == 0 and all(slice["cases"] == slice["abstentions"] for slice in item["diagnostics"].values()) for item in (model, baseline)))
    return dict(passed=all(checks.values()), checks=checks)


def checkpoint(model, norm, digest):
    return dict(format=VERSION, production_eligible=False, source_sha256=digest, manifest_sha256=ds.sha256(ds.canonical_json(SPEC)),
                config=copy.deepcopy(CONFIG), feature_schema=SPEC["feature_schema"], normalizer=copy.deepcopy(norm),
                state={name: dict(shape=list(value.shape), values=value.flatten().tolist()) for name, value in model.state_dict().items()})


def restore(saved):
    ds.require(type(saved) is dict and set(saved) == {"format", "production_eligible", "source_sha256", "manifest_sha256", "config", "feature_schema", "normalizer", "state"} and
               saved["format"] == VERSION and saved["production_eligible"] is False and saved["manifest_sha256"] == ds.sha256(ds.canonical_json(SPEC)) and
               saved["config"] == CONFIG and saved["feature_schema"] == SPEC["feature_schema"] and type(saved["source_sha256"]) is str and
               re.fullmatch(r"[a-f0-9]{64}", saved["source_sha256"]), "unsupported checkpoint")
    checked_normalizer(saved["normalizer"])
    model = DriveDnaEncoder().cpu()
    expected = model.state_dict()
    ds.require(type(saved["state"]) is dict and set(saved["state"]) == set(expected), "invalid parameter keys")
    parameters = {}
    for name, original in expected.items():
        item = saved["state"][name]
        ds.require(type(item) is dict and set(item) == {"shape", "values"} and item["shape"] == list(original.shape) and type(item["values"]) is list and
                   len(item["values"]) == original.numel() and all(type(number) in (int, float) and math.isfinite(number) and abs(number) <= 1e6 for number in item["values"]), "invalid weights")
        parameters[name] = torch.tensor(item["values"], dtype=torch.float32).reshape(original.shape)
    model.load_state_dict(parameters, strict=True)
    return model.eval(), copy.deepcopy(saved["normalizer"])


def provenance():
    files = ["ml/drivedna.py", "ml/drivedna_corpus.py", "ml/experiments/drivedna-v1.json", "ml/experiments/DRIVEDNA_DATA_LICENSE.md",
             "ml/requirements-eventnet.txt", "docs/reference/DRIVEDNA_EMBEDDING_V1.md"]
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ds.ROOT, check=True, capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "status", "--porcelain", "--", *files], cwd=ds.ROOT, check=True, capture_output=True, text=True).stdout)
    return dict(source_commit=commit, source_dirty=dirty, source_files_sha256={name: ds.sha256((ds.ROOT/name).read_bytes()) for name in files})


def run(source, digest, name):
    ds.require(type(name) is str and re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", name), "invalid run name")
    ds.require(torch.__version__ == "2.15.0+cpu", "pinned CPU runtime required")
    parts = load_source(source, digest)
    root = ds.ROOT/"ml/checkpoints"
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output links denied")
    root.mkdir(parents=True, exist_ok=True)
    target = root/name
    ds.require(not target.exists() and not target.is_symlink() and not target.is_junction(), "never overwrite experiment")
    model, norm, training = fit(parts["train"])
    state = ds.canonical_json(checkpoint(model, norm, digest))
    identities = dict(embedding=ds.sha256(state), summary=ds.sha256(ds.canonical_json(dict(version=SPEC["baseline_version"], feature_schema=SPEC["feature_schema"], normalizer=norm))))
    cutoffs = {kind: training_cutoff(parts["train"], representations(candidate, norm, parts["train"], identities[kind])) for kind, candidate in (("embedding", model), ("summary", None))}
    validation = evaluate(model, norm, parts["train"], parts["validation"], identities, cutoffs)
    gate = value_gate(validation)
    test = evaluate(model, norm, parts["train"], parts["test"], identities, cutoffs) if gate["passed"] else None
    test_gate = value_gate(test) if test is not None else None
    restored, restored_norm = restore(json.loads(state))
    ds.require(evaluate(restored, restored_norm, parts["train"], parts["validation"], identities, cutoffs) == validation, "checkpoint replay mismatch")
    report = dict(experiment_version=VERSION, model_status="experiment", production_eligible=False, source_kind="generated_only",
                  source_sha256=digest, manifest_sha256=ds.sha256(ds.canonical_json(SPEC)), license=SPEC["license"], attribution=SPEC["attribution"],
                  feature_schema=SPEC["feature_schema"], groups=SPEC["groups"], programs=list(PROGRAMS), config=CONFIG, baseline_version=SPEC["baseline_version"],
                  normalizer=norm, normalizer_fit_partition="train", parameters=sum(value.numel() for value in model.parameters()),
                  model_sha256=identities["embedding"], model_bytes=len(state), representation_widths=dict(embedding=3, summary=8),
                  training=training, cutoffs=cutoffs, validation=validation, validation_value_gate=gate,
                  test=dict(predictions_computed=test is not None, metadata_validated=True, cases_available=len(parts["test"]), metrics=test, value_gate=test_gate),
                  decision="generated_value_only_keep_explicit_dimensions" if test_gate and test_gate["passed"] else "no_validated_added_value_keep_explicit_dimensions",
                  real_style_accuracy=None, calibrated_confidence=None, mobile_runtime_metrics=None,
                  runtime=dict(python=platform.python_version(), torch=torch.__version__, device="cpu"), limitations=SPEC["limitations"], **provenance())
    with tempfile.TemporaryDirectory(prefix=".drivedna-", dir=root) as temporary:
        staging = Path(temporary)/"result"
        staging.mkdir()
        (staging/"checkpoint.json").write_bytes(state)
        (staging/"report.json").write_bytes(ds.canonical_json(report))
        ds.require(not target.exists(), "experiment appeared concurrently")
        staging.rename(target)
    return copy.deepcopy(report)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--run-name", required=True)
    args = parser.parse_args()
    try: report = run(args.source, args.expected_sha256, args.run_name)
    except (OSError, ValueError, RuntimeError) as failure:
        print(f"DriveDNA experiment failed ({type(failure).__name__}); no production result published.", file=sys.stderr)
        raise SystemExit(2)
    print(f"DriveDNA comparison complete: {report['decision']}; test predictions computed: {report['test']['predictions_computed']}; production eligible: false.")
