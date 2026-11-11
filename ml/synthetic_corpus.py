"""Version-1, integer-generated IMU import fixtures; not field evidence."""

import csv
import io

VERSION = 1
HEADER = [
    "driver_group", "trip_group", "partition", "elapsed_ms", "label",
    "ax", "ay", "az", "gx", "gy", "gz",
]
GROUPS = {"synthetic-a": "train", "synthetic-b": "validation", "synthetic-c": "test"}
LABELS = ("stationary", "acceleration", "braking", "left", "right", "bump")


def generate() -> bytes:
    """Generate exact decimal strings without platform-dependent random/trig math."""
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(HEADER)
    for driver, partition in GROUPS.items():
        for label in LABELS:
            for index in range(31):
                pulse = 10 <= index < 20
                ax = "2.000" if pulse and label == "acceleration" else "0.000"
                if pulse and label == "braking":
                    ax = "-2.000"
                az = "11.807" if pulse and label == "bump" else "9.807"
                gz = "0.300" if pulse and label == "left" else "0.000"
                if pulse and label == "right":
                    gz = "-0.300"
                writer.writerow([
                    driver, f"{driver}-{label}", partition, index * 20, label,
                    ax, "0.000", az, "0.000", "0.000", gz,
                ])
    return output.getvalue().encode("utf-8")
