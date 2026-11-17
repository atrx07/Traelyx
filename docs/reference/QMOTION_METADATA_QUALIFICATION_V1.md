# Q-Motion metadata qualification v1

## When to read

Read before using Q-Motion for M7.4/M7.5 training or evaluation. This extends the
[public-source review](EVENTNET_PUBLIC_QUALIFICATION_V1.md) with reproducible
session, annotation and transform checks. It grants no training, distribution,
production-feature or model approval. No sensor stream or 5.05 GB telemetry ZIP
was downloaded. No emulator or physical phone was used.

## Scope and provenance — 2026-11-17

The original [publisher release](https://doi.org/10.17632/p5376m6xfc.1) and official
DOI metadata identify version 1 / CC-BY-NC-4.0. The license includes a
[noncommercial restriction](https://creativecommons.org/licenses/by-nc/4.0/);
unrestricted production distribution has not been approved. No model weights
were trained or released. Attribution remains required for source reuse.

The committed `ml/qualification/qmotion-v1.json` pins 22 public metadata inputs
totalling 150,280 bytes: four publisher documents, four session ledgers, one
rotation ledger and 13 manual annotation logs. Source bytes, original driver keys
and annotation wall times remain ignored/local. Reviewed aggregates, SHA-256 pins
and public-release file/session references needed to bind those pins are committed.
Group ordinals are reproducible by
sorting source driver keys; they are not assigned model splits.

`python -m ml.qmotion_qualification --root <ignored-pinned-metadata-directory>`
checks bounded relative paths, file sizes/hashes, session identity, label pairing,
group coverage and transform arithmetic. It has no network access and uses the
standard library only. It preserves each explicit source start/stop pair;
timestamp sorting before pairing is incorrect after publisher boundary edits.
No annotation or sensor time is corrected, and no interval is relabelled normal.

## Measured coverage

The ledgers contain 81 sessions and five driver groups. One session has no
smartphone source. There are 13 annotation logs, one containing only auxiliary/
recording controls, and 294 manual driving intervals:

| Group ordinal | Sessions | Annotation logs | Acceleration | Braking | Bump | Curve | Zig-zag |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4 | 1 | 23 | 30 | 2 | 7 | 19 |
| 2 | 30 | 8 | 30 | 73 | 21 | 12 | 14 |
| 3 | 11 | 1 | 4 | 13 | 1 | 3 | 4 |
| 4 | 8 | 1 | 2 | 7 | 1 | 2 | 0 |
| 5 | 28 | 2 | 5 | 13 | 4 | 3 | 1 |
| Total | 81 | 13 | 64 | 136 | 29 | 27 | 38 |

Metadata review can inform a future predeclared allocation; it does not justify
selecting groups after model outcomes. Small counts and missing group classes
must remain visible in metrics/calibration. No verified normal-driving exposure
is established by these logs. Recording-control duration is not negative truth.

The source arrays have 22 adjacent reverse-time pairs, 21 overlaps between
different manual classes and one same-class overlap after explicit pairing.
These are annotation serialization/edited-boundary observations, not evidence of
phone-clock rollback. A single-label training protocol must explicitly handle
ambiguous/context-overlapping windows; do not silently sort, merge or select a
dominant class to manufacture truth.

## Feature compatibility findings

The four publisher documents are separately pinned in the profile. Their
processing contract says smartphone times within each one-second bin are
reconstructed using sample-count spacing; this is not measured Android monotonic
timing. It assigns baseline/background normal labels and also produces distinct
rules-based labels. Those fields are not independent negative/event truth.
Manual boundaries are approximate and include passenger-reaction/date corrections.

The eight published frame matrices have a maximum `|R Rᵀ − I|` entry of 0.0783
and determinants from 0.921796 to 1.003620. This arithmetic shows that those
stored transforms are not all exact orthonormal rotations. It does not prove a
publisher defect: scaling/calibration and rounding may contribute, and that cause
was not established. No matrix was corrected or applied. Native frame equivalence
cannot be asserted from matching column names.

Raw-unit scale configuration, source quality equivalence and the exact native
preprocessing adapter remain unverified. Reusing preprocessed columns would not
establish that the training and serving signals have identical meaning. The
[native input proposal](EVENTNET_NATIVE_INPUT_PROPOSAL_V1.md) specifies the target
that an adapter would need to satisfy; no adapter is implemented by this audit.

## Validation and disposition

Eleven generated-data regressions cover source pin/path integrity, private output,
explicit pairs with edited/contiguous bounds, overlapping classes, incomplete
groups, shared source recordings, malformed metadata and passive matrix checks.
The real pinned metadata command and all 142 local Python tests pass. Source CI is pending
in [the aggregate result](qmotion-metadata-qualification-v1-result.json).

Q-Motion remains a research lead with useful manual positive labels, not an
accepted production corpus. Independent negatives, source/native equivalence,
label mapping, grouped protocol and intended-distribution license review remain
required. No candidate is trained, no historical experiment is changed and no
acceptance metric is fabricated. M7.4/M7.5 remain open; M8 is inactive.
