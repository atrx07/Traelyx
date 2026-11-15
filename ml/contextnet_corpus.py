"""Original generated context sequences; no recordings, sensor access or network."""

import argparse
import json
import math
from pathlib import Path

from . import datasets as ds

VERSION = "traelyx-context-fixtures-v1"
SPEC_PATH = ds.ROOT / "ml/experiments/contextnet-v1.json"
SPEC = ds.load_json(SPEC_PATH)


def case_specs():
    rows = []
    for group, partition in SPEC["groups"].items():
        for label in SPEC["classes"]:
            for duration in SPEC["durations_seconds"]:
                for variant in SPEC["variants"]:
                    rows.append(dict(id=f"{group}-{label}-{duration}-v{variant}", group=group, partition=partition,
                                     category="labelled", label=label, duration_seconds=duration, variant=variant))
        if partition != "train":
            for category in ("quality_missing", "quality_unsupported"):
                for label in SPEC["classes"]:
                    rows.append(dict(id=f"{group}-{category}-{label}-60", group=group, partition=partition,
                                     category=category, label=label, duration_seconds=60, variant=1))
            for category in ("open_stationary", "open_mixed"):
                rows.append(dict(id=f"{group}-{category}-60", group=group, partition=partition,
                                 category=category, label=None, duration_seconds=60, variant=1))
    return rows


def analytical_frame(label, profile, variant, seconds):
    base = 8.0 + .35 * profile
    phase = .13 * profile + .27 * variant
    if label == "stop_and_go":
        position = (seconds + phase * 3) % 30
        if position < 10:
            return [0., 0., 0., 0.]
        angle = math.pi * (position - 10) / 20
        peak = base + .2 * variant
        return [peak * math.sin(angle)**2, peak * math.pi / 20 * math.sin(2*angle),
                .1 * math.sin(seconds / 10), peak * math.pi**2 / 200 * math.cos(2*angle)]
    if label == "repeated_abrupt_transitions":
        amplitude, omega = 2.5 + .05 * profile, math.pi / 2
    elif label == "smooth_variable":
        amplitude, omega = 2.5 + .05 * variant + .01 * profile, math.pi / 30
    else:
        amplitude, omega = .12 + .005 * profile, math.pi / 15
    angle = omega * seconds + phase
    lateral = 2.2 + .04 * profile if label == "high_dynamic_load" else .1 * math.sin(seconds / 10)
    return [base + amplitude * math.sin(angle), amplitude * omega * math.cos(angle),
            lateral, -amplitude * omega**2 * math.sin(angle)]


def generate():
    cases = []
    for descriptor in case_specs():
        profile = int(descriptor["group"][-2:])
        duration = descriptor["duration_seconds"]
        features, supported = [], []
        for index in range(duration):
            label = descriptor["label"]
            if descriptor["category"] == "open_stationary":
                value = [0., 0., 0., 0.]
            else:
                value = analytical_frame(label or "repeated_abrupt_transitions", profile, descriptor["variant"], index + .5)
                if descriptor["category"] == "open_mixed": value[2] = 2.2 + .04 * profile
            unavailable = descriptor["category"].startswith("quality_") and 20 <= index < 25
            features.append(None if unavailable and descriptor["category"] == "quality_missing" else value)
            supported.append(not unavailable)
        cases.append({**descriptor, "times_ms": [500 + 1000 * index for index in range(duration)],
                      "features": features, "supported": supported})
    bundle = {"format": VERSION, "source_kind": "generated_only", "feature_schema": SPEC["feature_schema"],
              "sample_interval_ms": 1000, "manifest_sha256": ds.sha256(ds.canonical_json(SPEC)), "cases": cases}
    return (json.dumps(bundle, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def write_generated(destination: Path):
    root = ds.ROOT / ".dart_tool"
    ds.require(destination.absolute().parent == root.absolute() and destination.name == "contextnet-fixtures-v1.json",
               "explicit ignored context fixture destination required")
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output links denied")
    root.mkdir(exist_ok=True)
    ds.require(not destination.exists() and not destination.is_symlink(), "never overwrite generated source")
    raw = generate()
    with destination.open("xb") as stream:
        stream.write(raw)
    return ds.sha256(raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    print("Generated-only context fixture SHA-256:", write_generated(parser.parse_args().output))
