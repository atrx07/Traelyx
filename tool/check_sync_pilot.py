"""Audit explicitly selected private software-marker/clock observations offline."""

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import re
import sys

MAX_BYTES = 262144
MAX_NS = 2**63 - 1
SHA = re.compile(r"[0-9a-f]{64}\Z")


class SyncInvalid(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise SyncInvalid(code)


def integer(value, minimum=0, maximum=MAX_NS):
    require(type(value) is int and minimum <= value <= maximum, "integer_bounds")
    return value


def keys(value, expected):
    require(type(value) is dict and set(value) == set(expected.split()), "object_fields")


def digest(value, nullable=False):
    require((nullable and value is None) or (type(value) is str and SHA.fullmatch(value)), "digest")
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate_json_key")
        result[key] = value
    return result


def read_pinned(path, expected):
    digest(expected)
    with path.open("rb") as stream:
        raw = stream.read(MAX_BYTES + 1)
    require(0 < len(raw) <= MAX_BYTES, "input_size")
    require(hashlib.sha256(raw).hexdigest() == expected, "input_hash")
    try:
        return json.loads(raw, object_pairs_hook=unique_object,
                          parse_constant=lambda _: (_ for _ in ()).throw(SyncInvalid("json_nonfinite")))
    except (UnicodeError, json.JSONDecodeError, RecursionError, ValueError) as error:
        if isinstance(error, SyncInvalid):
            raise
        raise SyncInvalid("json_invalid") from None


def validate_journal(value):
    keys(value, "version clock session_alias measurement presentation_delay_bound_ns "
         "reference_alignment_verified stopped stop_reason markers")
    require(value["version"] == "traelyx.sync-marker.v1" and
            value["clock"] == "elapsedRealtimeNanos" and
            value["measurement"] == "software_canvas_draw_not_photon_presentation", "journal_version")
    require(type(value["session_alias"]) is str and re.fullmatch(
        r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", value["session_alias"]), "session_alias")
    require(value["presentation_delay_bound_ns"] is None and
            value["reference_alignment_verified"] is False and
            value["stopped"] is True and value["stop_reason"] in ("user", "paused", "limit"), "journal_state")
    rows = value["markers"]
    require(type(rows) is list and 4 <= len(rows) <= 64, "marker_count")
    previous = -1
    for i, row in enumerate(rows, 1):
        keys(row, "sequence token draw_before_ns draw_after_ns")
        require(type(row["sequence"]) is int and row["sequence"] == i and
                row["token"] == f"M{i:04}", "marker_identity")
        before, after = integer(row["draw_before_ns"]), integer(row["draw_after_ns"])
        require(previous < before <= after and after-before <= 1_000_000_000, "marker_clock")
        previous = after
    return rows


def ceiling(value):
    return -(-value.numerator // value.denominator)


def ratio(value):
    return {"numerator": str(value.numerator), "denominator": str(value.denominator)}


def audit(journal, observations, journal_sha256):
    rows = validate_journal(journal)
    digest(journal_sha256)
    keys(observations, "version journal_sha256 reference_sha256 reference_kind "
         "native_start_ns native_end_ns maximum_error_ns maximum_rate_error_ppm "
         "presentation_delay_bound_ns presentation_evidence_sha256 reference_latency_bound_ns "
         "reference_latency_evidence_sha256 same_boot_evidence_sha256 anchors")
    require(observations["version"] == "traelyx.sync-observations.v1" and
            observations["journal_sha256"] == journal_sha256, "journal_binding")
    digest(observations["reference_sha256"])
    require(observations["reference_kind"] in ("video_pts", "generated"), "reference_kind")
    digest(observations["same_boot_evidence_sha256"], nullable=True)
    bounds = []
    for key, evidence in [("presentation_delay_bound_ns", "presentation_evidence_sha256"),
                          ("reference_latency_bound_ns", "reference_latency_evidence_sha256")]:
        bound = observations[key]
        digest(observations[evidence], nullable=True)
        require((bound is None) == (observations[evidence] is None), "bound_evidence")
        if bound is not None:
            integer(bound, maximum=1_000_000_000)
        bounds.append(bound)
    start, end = integer(observations["native_start_ns"]), integer(observations["native_end_ns"])
    require(start < end, "interval")
    budget = integer(observations["maximum_error_ns"], 1, 1_000_000_000)
    rate_budget = integer(observations["maximum_rate_error_ppm"], 0, 10000)
    anchors = observations["anchors"]
    require(type(anchors) is list and 4 <= len(anchors) <= 64, "anchor_count")
    points, seen, previous = {"fit": [], "check": []}, set(), -1
    for row in anchors:
        keys(row, "sequence role reference_before_ns reference_after_ns")
        sequence = integer(row["sequence"], 1, len(rows))
        require(sequence not in seen and type(row["role"]) is str and row["role"] in points, "anchor_identity")
        require(not seen or sequence > max(seen), "anchor_order")
        seen.add(sequence)
        before, after = integer(row["reference_before_ns"]), integer(row["reference_after_ns"])
        require(previous < before <= after and
                (observations["reference_kind"] != "video_pts" or before < after), "reference_clock")
        previous = after
        marker = rows[sequence-1]
        native_before = marker["draw_before_ns"]
        native_after = marker["draw_after_ns"] + (bounds[0] or 0)
        integer(native_after)
        x = Fraction(before+after, 2)
        y = Fraction(native_before+native_after, 2)
        points[row["role"]].append((x, y, Fraction(after-before, 2),
                                     Fraction(native_after-native_before, 2)))
    require(all(len(points[role]) >= 2 for role in points), "disjoint_fit_check_required")
    # Center before solving: multi-day boot times never pass through float64.
    fit = points["fit"]
    mx = sum(p[0] for p in fit) / len(fit)
    my = sum(p[1] for p in fit) / len(fit)
    variance = sum((p[0]-mx)**2 for p in fit)
    require(variance > 0, "fit_degenerate")
    slope = sum((p[0]-mx)*(p[1]-my) for p in fit) / variance
    require(slope > 0, "negative_clock_rate")
    offset = my-slope*mx
    drift = abs(slope-1)*1_000_000
    require(drift <= rate_budget, "clock_rate_budget")
    # Both fit and untouched check anchors must enclose the claimed native span.
    for role in points:
        require(min(p[1]+p[3] for p in points[role]) <= start and
                end <= max(p[1]-p[3] for p in points[role]), "unsupported_interval")
    residual = max(abs(y-(slope*x+offset)) for x, y, _, _ in points["check"])
    error = None
    if all(bound is not None for bound in bounds):
        error = max(abs(y-(slope*x+offset)) + dy + slope*(dx+bounds[1])
                    for x, y, dx, dy in points["check"])
    blockers = []
    if bounds[0] is None:
        blockers.append("physical_presentation_delay_unknown")
    if bounds[1] is None:
        blockers.append("reference_capture_latency_unknown")
    if observations["same_boot_evidence_sha256"] is None:
        blockers.append("same_boot_recording_evidence_missing")
    if error is not None and error > budget:
        blockers.append("declared_check_error_exceeds_budget")
    summary = {
        "version": "traelyx.sync-audit.v1", "privacy_class": "aggregate_private_diagnostic",
        "marker_count": len(rows), "fit_anchor_count": len(fit),
        "check_anchor_count": len(points["check"]), "maximum_software_check_residual_ns": ceiling(residual),
        "maximum_checked_error_under_declared_bounds_ns": None if error is None else ceiling(error),
        "declared_check_budget_satisfied": error is not None and error <= budget,
        "rate_error_ppm_ceiling": ceiling(drift), "blockers": blockers,
        "physical_alignment_verified": False, "recording_binding_verified": False,
        "between_anchor_error_bound_verified": False, "reference_artifact_verified": False,
        "training_admitted": False, "model_accepted": False,
    }
    private = {
        "version": "traelyx.sync-private-map.v1", "privacy_class": "precise_private",
        "journal_sha256": journal_sha256, "observations": observations,
        "native_ns_per_reference_ns": ratio(slope), "native_offset_ns": ratio(offset),
        "claimed_native_start_ns": start, "claimed_native_end_ns": end,
        "mapping_basis": "draw_midpoints_with_declared_presentation_bound_if_supplied",
        "limitations": summary,
    }
    return summary, private


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--journal", type=Path, required=True)
    parser.add_argument("--expected-journal-sha256", required=True)
    parser.add_argument("--observations", type=Path, required=True)
    parser.add_argument("--expected-observations-sha256", required=True)
    parser.add_argument("--private-map", type=Path)
    args = parser.parse_args(argv)
    try:
        journal = read_pinned(args.journal, args.expected_journal_sha256)
        observations = read_pinned(args.observations, args.expected_observations_sha256)
        summary, private = audit(journal, observations, args.expected_journal_sha256)
        if args.private_map is not None:
            with args.private_map.open("x", encoding="utf-8") as stream:
                stream.write(json.dumps(private, indent=2, sort_keys=True)+"\n")
    except (OSError, SyncInvalid, OverflowError) as error:
        code = str(error) if isinstance(error, SyncInvalid) else "file_operation_failed"
        print("sync_pilot_invalid: "+code, file=sys.stderr)
        return 1
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
