"""Original generated physical summaries, without recordings or device/network access."""

import argparse
import json
import math
from pathlib import Path

from . import datasets as ds

VERSION = "traelyx-style-fixtures-v1"
SPEC = ds.load_json(ds.ROOT / "ml/experiments/drivedna-v1.json")


def case_specs():
    cases = []
    for group, partition in SPEC["groups"].items():
        for vehicle in SPEC["vehicle_scopes"]:
            for context in SPEC["driving_contexts"]:
                common = dict(group=group, partition=partition, vehicle_scope=vehicle, driving_context=context)
                for program in SPEC["programs"]:
                    for variant in SPEC["variants"]:
                        cases.append(dict(common, id=f"{group}-{vehicle}-{context}-{program}-v{variant}",
                                          category="supported", program=program, variant=variant))
                if partition != "train":
                    for category in ("missing", "unsupported", "stationary"):
                        cases.append(dict(common, id=f"{group}-{vehicle}-{context}-{category}",
                                          category=category, program=None, variant=1))
    return cases


def frame(program, profile, vehicle, context, variant, time):
    factor = (.85 if vehicle.endswith("a") else 1.15) * (1+.01*profile) * (.98 if variant == 1 else 1.02)
    frequency = 1. if context.endswith("a") else .8
    base = 8+.2*profile+(0 if context.endswith("a") else .5)
    phase = .07*profile+.1*variant
    if program == "stop_go":
        position = (time*frequency+phase*3) % 30
        if position < 10: return [0., 0., 0., 0.]
        angle = math.pi*(position-10)/20
        peak = base*factor
        return [peak*math.sin(angle)**2, peak*math.pi/20*frequency*math.sin(2*angle),
                .1*factor*math.sin(time/10), peak*math.pi**2/200*frequency**2*math.cos(2*angle)]
    amplitude, omega = {"steady": (.1, math.pi/15), "progressive": (2., math.pi/20),
                        "lateral": (.2, math.pi/15), "abrupt": (1.5, math.pi/2)}[program]
    amplitude, omega = amplitude*factor, omega*frequency
    angle = omega*time+phase
    lateral = (1.4 if program == "lateral" else .1)*factor*math.sin(math.pi/10*frequency*time+phase)
    return [base+amplitude*math.sin(angle), amplitude*omega*math.cos(angle), lateral, -amplitude*omega**2*math.sin(angle)]


def summaries(descriptor):
    if descriptor["category"] == "missing": return None
    if descriptor["category"] == "stationary": return [0., 0., 0., 0., 0., 0., 1., 0.]
    values = [frame(descriptor["program"] or "steady", int(descriptor["group"][-2:]), descriptor["vehicle_scope"],
                    descriptor["driving_context"], descriptor["variant"], index+.5) for index in range(60)]
    speed, longitudinal, lateral, jerk = zip(*values)
    def moments(channel): return [sum(map(abs, channel))/60, math.sqrt(sum(value*value for value in channel)/60)]
    mean_speed = sum(speed)/60
    return moments(longitudinal)+moments(jerk)+moments(lateral)+[sum(value <= .5 for value in speed)/60,
                                                               math.sqrt(sum((value-mean_speed)**2 for value in speed)/60)]


def generate():
    cases = [dict(row, features=summaries(row), supported=row["category"] != "unsupported") for row in case_specs()]
    value = dict(format=VERSION, source_kind="generated_only", feature_schema=SPEC["feature_schema"],
                 duration_seconds=60, sample_interval_ms=1000, coordinate_frame="generated_vehicle",
                 manifest_sha256=ds.sha256(ds.canonical_json(SPEC)), cases=cases)
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)+"\n").encode()


def write_generated(destination):
    root = ds.ROOT/".dart_tool"
    ds.require(destination.absolute().parent == root.absolute() and destination.name == "drivedna-fixtures-v1.json", "explicit ignored destination required")
    ds.require(not any(path.is_symlink() or path.is_junction() for path in (root, *root.parents)), "output links denied")
    root.mkdir(exist_ok=True)
    ds.require(not destination.exists() and not destination.is_symlink(), "never overwrite source")
    raw = generate()
    with destination.open("xb") as stream: stream.write(raw)
    return ds.sha256(raw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    print("Generated-only DriveDNA fixture SHA-256:", write_generated(parser.parse_args().output))
