"""Offline, pinned Zenodo trip-2 development probe. No training or native admission."""
from __future__ import annotations

import argparse
from array import array
from bisect import bisect_left
from collections import Counter
import csv
from decimal import Decimal, ROUND_HALF_EVEN
import io
import json
import math
from pathlib import Path
from statistics import median
import sys

from ml.qualify_eventnet_sources import InvalidSource, ZENODO, label_summary, pinned_bytes, require

VERSION = "zenodo-stream-feasibility-v1"
PROFILE = Path(__file__).parent / "qualification" / (VERSION + ".json")
STEP, WINDOW, HOP, MAX_GAP = 10_000_000, 6_000_000_000, 1_000_000_000, 50_000_000
HEADERS = {
    "acceleration": ["Time (s)"] + [f"Linear Acceleration {axis} (m/s^2)" for axis in "xyz"],
    "gyroscope": ["Time (s)"] + [f"Gyroscope {axis} (rad/s)" for axis in "xyz"],
}


def time_nanos(value):
    require(type(value) is str and 0 < len(value) <= 64, "time_text")
    try:
        seconds = Decimal(value)
        require(seconds.is_finite() and 0 <= seconds <= 14_400, "time_range")
        ns = seconds * 1_000_000_000
        rounded = ns.to_integral_value(rounding=ROUND_HALF_EVEN)
        return int(rounded), float(abs(ns-rounded))
    except ArithmeticError:
        raise InvalidSource("time_text") from None


def inspect_stream(data, kind):
    require(0 < len(data) <= 16_000_000 and kind in HEADERS, "stream_size_or_kind")
    reader = csv.reader(io.StringIO(data.decode("utf-8-sig"), newline=""))
    require(next(reader, None) == HEADERS[kind], "stream_columns")
    times = array("q")
    rounding = 0.0
    for row in reader:
        require(len(times) < 500_000 and len(row) == 4, "stream_rows")
        ns, error = time_nanos(row[0])
        rounding = max(rounding, error)
        require(not times or ns > times[-1], "stream_clock_not_strict")
        for value in row[1:]:
            require(0 < len(value) <= 64, "stream_numeric")
            try:
                require(math.isfinite(float(value)), "stream_nonfinite")
            except ValueError:
                raise InvalidSource("stream_numeric") from None
        times.append(ns)
    require(len(times) >= 2, "stream_empty")
    gaps = sorted(b-a for a, b in zip(times, times[1:]))
    duration = times[-1]-times[0]
    return times, {
        "samples": len(times), "duration_seconds": duration/1e9,
        "observed_mean_rate_hz": (len(times)-1)*1e9/duration,
        "minimum_gap_seconds": gaps[0]/1e9,
        "median_gap_seconds": median(gaps)/1e9,
        "p99_gap_seconds": gaps[math.ceil(.99*len(gaps))-1]/1e9,
        "maximum_gap_seconds": gaps[-1]/1e9,
        "gaps_over_native_50ms": sum(d > MAX_GAP for d in gaps),
        "maximum_timestamp_rounding_error_nanos": rounding,
        "clock_order": "strictly_increasing_after_explicit_nearest_nanosecond_rounding",
        "android_accuracy_or_flags_present": False,
    }


def supported_target(times, target):
    index = bisect_left(times, target)
    if index < len(times) and times[index] == target:
        return True, 0, True
    if index == 0 or index == len(times) or times[index]-times[index-1] > MAX_GAP:
        return False, 0, False
    return True, times[index]-target, False


def inspect_timing_and_labels(acc, gyro, label_data):
    labels = label_summary(label_data)
    intervals = []
    for row in csv.DictReader(io.StringIO(label_data.decode("utf-8-sig"))):
        intervals.append((time_nanos(row["start"])[0], time_nanos(row["end"])[0], row["target"]))
    begin, end = max(acc[0], gyro[0]), min(acc[-1], gyro[-1])
    require(begin < end, "no_stream_overlap")
    candidate_count = max(0, (end-begin-WINDOW)//HOP+1)
    supported = 0
    exact = [0, 0]
    lookahead = 0
    contained = Counter()
    for window_index in range(candidate_count):
        start = begin + window_index*HOP
        supported_window = True
        for target in range(start+STEP, start+WINDOW+1, STEP):
            for channel, times in enumerate((acc, gyro)):
                available, delay, is_exact = supported_target(times, target)
                supported_window &= available
                lookahead = max(lookahead, delay)
                exact[channel] += int(is_exact)
        if supported_window:
            supported += 1
            for left, right, label in intervals:
                if left <= start+STEP and start+WINDOW <= right:
                    contained[label] += 1
    return {
        "label_summary": labels,
        "common_stream_duration_seconds": (end-begin)/1e9,
        "unverified_initial_clock_offset_seconds": abs(acc[0]-gyro[0])/1e9,
        "label_intervals_outside_common_span": sum(left < begin or right > end for left, right, _ in intervals),
        "label_intervals_shorter_than_six_seconds": sum(right-left < WINDOW for left, right, _ in intervals),
        "six_second_one_second_hop_candidates": candidate_count,
        "timing_only_supported_windows": supported,
        "windows_crossing_oversized_gap": candidate_count-supported,
        "fully_label_contained_timing_windows_by_publisher_target": dict(sorted(contained.items())),
        "reused_grid_target_exact_observations": dict(zip(("acceleration", "gyroscope"), exact)),
        "maximum_diagnostic_bracket_lookahead_seconds": lookahead/1e9,
        "grid_origin": "common_stream_start_development_probe_only",
        "time_rounding": "nearest_nanosecond_half_even_diagnostic_only_source_bytes_unchanged",
        "label_time_policy": "direct_source_seconds_as_publisher_notebook_no_timesync_shift_applied",
        "label_clock_alignment_independently_verified": False,
        "native_eligibility": "not_assessed_missing_source_semantics",
        "native_admitted_windows": 0,
        "native_rejection": "source_semantics_and_quality_unverified_not_a_native_raw_IMU_input",
    }


def inspect_notebook(data):
    require(0 < len(data) <= 3_300_000, "notebook_size")
    book = json.loads(data)
    require(type(book) is dict and type(book.get("cells")) is list and len(book["cells"]) <= 100, "notebook_schema")
    sources = []
    for cell in book["cells"]:
        require(type(cell) is dict and type(cell.get("source")) is list and
                all(type(s) is str for s in cell["source"]), "notebook_cell")
        sources.append("".join(cell["source"]))
    source = "\n".join(sources)
    markers = ["landscape orientation", "audio recorder", "accel2_x[i] = acc_eventsgt2[i]['Linear Acceleration y (m/s^2)']",
               "accel2_y[i] = acc_eventsgt2[i]['Linear Acceleration x (m/s^2)']*-1",
               "accel2_z[i] = acc_eventsgt2[i]['Linear Acceleration z (m/s^2)']*-1"]
    require(all(marker in source for marker in markers), "notebook_reviewed_contract_changed")
    return {"executed": False, "reviewed_as_source_text": True,
            "reported_mount": "dashboard_landscape_no_phone_operation",
            "label_provenance": "driver_audio_start_stop_notes_later_annotated",
            "publisher_plot_axis_mapping": ["device_y", "negative_device_x", "negative_device_z"],
            "plot_mapping_determinant": -1,
            "plot_mapping_applied": False,
            "plot_mapping_is_native_right_handed_rotation": False,
            "raw_accelerometer_and_stationary_reference_present": False,
            "linear_acceleration_gravity_algorithm_established": False}


def qualify(root):
    profile = json.loads(PROFILE.read_text(encoding="utf-8"))
    require(profile["protocol_version"] == VERSION and len(profile["files"]) == 3, "profile_version")
    blobs = {}
    for entry in profile["files"]:
        name = entry["name"]
        require(name in {"Linear_Acceleration_2.csv", "Gyroscope_2.csv", "Events_Extract_and_Visualization.ipynb"}, "profile_name")
        blobs[name] = pinned_bytes(root/name, (entry["bytes"], entry["sha256"]))
    label_data = pinned_bytes(root/"Labeled_events_2.csv", ZENODO["Labeled_events_2.csv"])
    acc, acc_summary = inspect_stream(blobs["Linear_Acceleration_2.csv"], "acceleration")
    gyro, gyro_summary = inspect_stream(blobs["Gyroscope_2.csv"], "gyroscope")
    return {"probe_version": VERSION, "source": profile["source"], "license": profile["license"],
            "role": "qualification_exposed_development_only", "training_or_predictions": False,
            "production_admitted": False, "normal_labels_inferred": False,
            "source_bytes_changed": False, "native_tensor_created_from_public_data": False,
            "streams": {"acceleration": acc_summary, "gyroscope": gyro_summary},
            "timing_and_labels": inspect_timing_and_labels(acc, gyro, label_data),
            "publisher_notebook": inspect_notebook(blobs["Events_Extract_and_Visualization.ipynb"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = qualify(args.root)
    except (ValueError, OSError, UnicodeError, csv.Error, KeyError, TypeError, OverflowError):
        print("Invalid pinned development input; no source admitted.", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True, allow_nan=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
