# EventNet source-space baseline v1 (M7.2)

**Status:** M7.2 complete as an unpromoted experiment, 2026-11-14. All 41 Python
checks, clean-source repeat and full [CI 43604983837](https://github.com/atrx07/Traelyx/actions/runs/43604983837)
pass for source `e858ebf` (all four jobs, including CPU/Linux and Android builds).

## Recorded baseline result — 2026-11-14

Source commit `e858ebf22dca4e7d0dcd5f1c4129063d265ef83b`, Python 3.14.6,
PyTorch 2.15.0+cpu on Windows. Both frozen runs have clean source and produce
byte-identical checkpoints and complete reports. Configuration is unchanged
from the provisional run; test results were not used for tuning. Selected epoch
60, 492 parameters, 20,393-byte JSON checkpoint, SHA-256 `46180afd…848c8cb`.
Machine-readable aggregate evidence is
[`eventnet-baseline-v1-result.json`](eventnet-baseline-v1-result.json).
Raw public inputs, weights and task-level prediction reports stay ignored locally.

| Held-out source class | Precision | Recall | F1 | Support |
|---|---:|---:|---:|---:|
| Sudden acceleration | 0.263 | 0.625 | 0.370 | 8 |
| Sudden right turn | 1.000 | 0.778 | 0.875 | 9 |
| Sudden left turn | 1.000 | 0.286 | 0.444 | 7 |
| Sudden braking | 0.545 | 0.400 | 0.462 | 15 |

Macro F1 is **0.5378**, versus majority **0.0851** on 39 held-out-driver tasks.
Probability quality regresses: multiclass Brier **0.8891** versus the training
class-prior baseline **0.7614**, and negative log likelihood **2.5048** versus
**1.4090** (lower is better for both). The model remains an **uncalibrated
experiment**, with production eligibility false. These results do not validate
normal/severe-event detection, road safety or on-device behavior.

## Contract / scope

This is an isolated CPU **experiment**, not production EventNet, an app model,
crash detection or a replacement for deterministic evidence/scoring. It uses
the four publisher maneuver labels in Mendeley DOI `10.17632/jj3tw8kj6h.3`.
The [publisher](https://data.mendeley.com/datasets/jj3tw8kj6h/3) licenses the data
under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Source bytes/SHA-256, attribution, populations and limits are registry-pinned.

Unlike version 2, version 3 supplies anonymous driver and task IDs. Joint
`(DriverID, Class, TaskID)` keys identify 109 contiguous source tasks in 1,114
rows. Task IDs alone repeat across classes/drivers. Import strips clock-of-day
after deriving coarse within-task elapsed milliseconds. Repeated seconds are
preserved; reversals fail closed. No timing is interpolated or invented.

Registry schema v2 permits only `experiment_only` for this reviewed format;
v1 entries and outputs remain unchanged. This deliberately allows source-space
classification despite unresolved SI units/frame/annotation quality, without
claiming compatibility with vehicle-frame production features or training-data
promotion. Those limitations cannot be removed by changing an eligibility flag.

## Fixed experiment

- Feature schema `eventnet-source-imu-v1`: six source numeric channels, ordered
  `ax, ay, az, gx, gy, gz`; no conversion, gravity removal, alignment or resampling.
- Window policy: one trailing seven-row window per joint task. Driver split is
  verified on every row **before** window creation; no task boundary is crossed.
  These are index-domain windows, not a claimed 5–8 second aligned window.
- Locked split `driver-holdout-v1`: driver 1 train (35 windows), driver 2
  validation (35), driver 3 test (39). No random row/window split.
- Normalization: channel mean/population standard deviation from training
  windows only; nearly constant channels use scale 1. No clipping/tuning on test.
- Architecture `eventnet-source-tcn-v1`: 6→8 pointwise projection; two residual
  left-padded Conv1d/ReLU blocks, width 8, kernel 3, dilations 1 and 2; temporal
  mean pooling and four logits. Receptive field seven samples, 492 parameters.
- Training: CPU, one thread, seed 7462, deterministic algorithms, full batch,
  Adam learning rate 0.01, 60 epochs. Lowest validation cross-entropy chooses
  the checkpoint, earliest tie. Test has no path into fitting or selection.
- Report the locked test once per frozen run. An identical repeat is solely a
  reproducibility check, not an opportunity to retune on these test results.

## Outputs and interpretation

Ignored `ml/checkpoints/<run-name>/` contains bounded, data-only JSON weights
and a report with source/import/model/code hashes, commit and dirty-source flag,
runtime/config, selected epoch/history, per-class precision/recall/F1/support,
macro F1, confusion, multiclass Brier and negative log likelihood, plus a
train-prior/majority baseline. No pickle, downloaded model or dynamic model code
is loaded. Existing runs are never overwritten; publication follows validation.

Probabilities are **uncalibrated**. Severe PR-AUC, false severe events/hour and
detection latency are null with reasons: the source has no severe/ordinary
negative ground truth and no trustworthy high-rate time axis. There is no
mapping to governed Traelyx event IDs. M7.3 owns further calibration/error work;
M7.4 owns mobile export/benchmarking. Neither is implemented here.

The three-driver, shared hardware/route/vehicle population does not establish
route/device/mount/motorcycle generalization. A better macro F1 than majority
does not justify promotion, especially if probability quality regresses.

## Reproduce

Use a repository-local virtual environment (Windows CPython 3.14 or Linux
CPython 3.12), with CPU wheels and all runtime dependencies hash-pinned:

```text
python -m venv .dart_tool/eventnet-venv
<venv-python> -m pip install -r ml/requirements-eventnet.txt
python ml/datasets.py import --dataset mendeley-driving-behavior --version 3 --source ml/data/private/m7-eventnet-review/jj3tw8kj6h-sensor_raw.csv
<venv-python> -m unittest tests.tool.test_eventnet
<venv-python> -m ml.eventnet --import-dir ml/data/private/imports/mendeley-driving-behavior--3--import-v1 --run-name eventnet-source-v1
```

Acquire the public `sensor_raw.csv` explicitly from the version-3 publisher
record first. It must be 135,636 bytes with registry SHA-256 `9b3a0667…8d1594`.
Keep it ignored. A clean commit is required for a final reproducibility claim;
provisional reports explicitly disclose dirty source. Full source/report hashes
are retained locally; only aggregate non-personal experiment evidence enters Git.

## Dependency evaluation

PyTorch `2.15.0+cpu` is an optional development dependency. Standard-library
imports, the app and offline core do not depend on it. Manual convolution
gradients/optimization would add unnecessary correctness and maintenance risk.
Official [Conv1d documentation](https://docs.pytorch.org/docs/2.15/generated/torch.nn.Conv1d.html)
and [distribution/license](https://github.com/pytorch/pytorch/blob/main/LICENSE)
were reviewed. The library is maintained; CPU wheels are obtained solely from
the official PyTorch index, with published Windows/Linux SHA-256 pins.

Direct/transitive runtime versions are fully pinned in `requirements-eventnet.txt`:
PyTorch (BSD-style plus bundled notices), filelock (MIT), fsspec (BSD-3-Clause),
Jinja2/MarkupSafe (BSD-3-Clause), mpmath/SymPy (BSD), NetworkX (BSD-3-Clause),
setuptools (MIT), typing_extensions (PSF-2.0). Installed notices and release
metadata were checked. No package is added to the APK. No paid API, billing,
telemetry SDK or runtime network call is involved. Installation downloads code;
training remains local and CPU-bounded. PyTorch's optional NumPy bridge may emit
an initialization warning when NumPy is absent; the experiment uses no NumPy.

The CPU index initially resolved setuptools 78.1.0, which precedes the published
[path-traversal fix](https://github.com/pypa/setuptools/security/advisories/GHSA-5rjg-fvgr-3xxf).
The final lock instead uses the current setuptools 84.2.1 wheel directly from
official PyPI, with its published hash; no secondary index/name fallback is used.

The [upstream security policy](https://github.com/pytorch/pytorch/security/policy)
does not make untrusted models safe: this pipeline avoids pickle/model downloads
and reconstructs only fixed architecture tensors from bounded JSON. This is not
a comprehensive third-party vulnerability audit. Platform/latency/battery effects
are unmeasured because nothing runs on-device. The fixed feature/weight/report
contracts isolate PyTorch so another training implementation can replace it
without changing app telemetry or scoring. No inference runtime is selected.
