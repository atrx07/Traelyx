# DriveDNA embedding experiment v1 — M7.8

Frozen manifest: `ml/experiments/drivedna-v1.json`. This is an optional generated
CPU experiment after the deterministic baseline. It does not replace the four
explainable Drive DNA dimensions, consistency, cohort/lifecycle, scores or history.
No production model, feature extractor, UI, persistence or cross-user comparison
is introduced. No raw embedding vector is exposed to an ordinary user.

## Source and comparison contract

Generate original 60-second vehicle-frame mathematical programs sampled at bin
midpoints, 1 Hz: steady, progressive, stop/go, lateral oscillation and abrupt
oscillation. `drivedna_corpus.py` defines the exact kinematics and derivatives.
Do not reuse/modify previous frozen datasets or infer real style labels. Reduce
each complete sequence to eight physical summaries: longitudinal acceleration
mean-absolute/RMS, longitudinal jerk mean-absolute/RMS, lateral acceleration
mean-absolute/RMS, stopped fraction (speed<=0.5 m/s) and population speed std.
No maximum speed, coordinates, wall time, identity or score is a model feature.

Assign fictional groups before generation: train1/3/5/7/9, validation2/8, test4/6.
Each group has five programs ×two variants ×two vehicle scopes ×two contexts:
200/80/80 supported cases. Each held-out group/cohort adds one missing summary,
one unsupported summary and one insufficient stationary case: 24 diagnostics
per held-out partition, giving 200/104/104 (408 total). Missing summaries stay
missing; unsupported and <10% moving evidence abstain before inference. These
generated scope tags are not physical vehicle/population evidence. Shared
templates prevent claims of independent driver/style generalization. A separate
CC0 dedication preserves all historical licenses and results.

Both methods use training-only population mean/std (floor1e-6). Comparator:
Euclidean distance in the eight normalized summaries. Candidate: denoising
autoencoder 8→6(tanh)→3(linear)→6(tanh)→8(linear), 155 parameters. PyTorch2.15.0+cpu,
one thread, seed7808; one fixed Gaussian training noise tensor (std0.05,
separate seed7809), 200 full-batch Adam epochs lr0.01, MSE to clean normalized
training summaries. Final epoch only, no search/selection/early stop. Neither
program labels, profile/group IDs nor scope tags enter encoder weights/loss.
Held-out data never fits normalization, weights or distance cutoffs.

Diagnostic similarity: for each held-out supported query, rank five program
labels by minimum distance to a matching-cohort training anchor. Anchors are
training only; ties sort by program name then case ID. Report per-program
precision/recall/F1, macro F1, confusion, top-1 hit rate and mean reciprocal rank
of the generation program. These are program-retrieval metrics, not a trained
style classifier, real-driver identification or probability/confidence.

Diagnostic deviation: within each group/cohort, variant1 is reference and
variant2 of the same program is a stable pair. Variant2 of the next program in
manifest order (cyclic) is a controlled changed pair. Each method's distance
cutoff is the nearest-rank training stable-pair 95th percentile plus1e-12, with
100 training pairs. Pairing uses generated correspondence, not inferred physical
truth. Report the cutoff and stable false flags/changed detections, rates and
confusion, overall and per generated vehicle/context cohort (40+40 held-out pairs).

Every comparison requires identical representation kind, exact checkpoint hash
(or baseline normalizer identity), feature/model version, dataset, vehicle,
driving context, sensor and mount scope. Reject incompatible/malformed records;
records also compute an independent coordinate-space hash from actual weights/
normalizer, preventing accidental reuse of an external identity for new statistics.
Never compare different weights as if embedding coordinates were stable. This
is an experimental contract, not a production migration or baseline API.

## Value and test-opening gate

Validation requires no retrieval macro F1/per-program recall/MRR regression,
no increase in stable false-flag rate, no decrease in changed detection (overall
and each cohort), and complete quality/insufficient-evidence abstention. It must
also improve macro F1 by>=0.02 OR changed detection by>=0.05 over the comparator.
Reducing eight coordinates to three alone is not validated usefulness. A failed
gate retains explicit dimensions and leaves test predictions/metrics uncomputed;
test metadata/structure is still checked. If validation passes, evaluate test
once with the identical gate. No after-result tuning or gate change.

## Artifacts and reproduction

Preserve source/data/manifest/code hashes, safe JSON checkpoint (no pickle), train
statistics and pair cutoffs, validation/test-opening status, and repeat hashes.
Generated source/model stay ignored. Refuse output links/overwrite. Repeat within
each pinned platform byte-identically; cross-platform source/float identity is
not asserted. Commit aggregate results, including negative outcomes.

```text
python -m pip install -r ml/requirements-eventnet.txt
python -m unittest tests.tool.test_drivedna
python -m ml.drivedna_corpus --output .dart_tool/drivedna-fixtures-v1.json
python -m ml.drivedna --source .dart_tool/drivedna-fixtures-v1.json --expected-sha256 <source SHA256> --run-name drivedna-generated-v1
```

No new dependency/provider/runtime, private data, network upload, migration,
phone/emulator or recorder change. Real style/overlap/trip representativeness,
valid feature extraction, calibrated downstream uncertainty, runtime/battery and
physical acceptance remain separate. No impairment, fatigue or safety diagnosis.
Stop after M7.8; M7.9 requires separate authorization.
