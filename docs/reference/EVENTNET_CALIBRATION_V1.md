# EventNet retrospective calibration / error audit v1 (M7.3)

**Status:** Protocol frozen; implementation/tests under validation.

## Scope and frozen protocol

Version `eventnet-temperature-audit-v1` audits the preserved M7.2 source-space
experiment. It does not change weights, normalization, source/import/split,
class labels, architecture or app behavior. Source limitations and the M6.8
acceptance deferral remain. No new dependency, phone, emulator or upload.

Scalar temperature scaling follows the method family described by
[Guo et al. (PMLR 2017)](https://proceedings.mlr.press/v70/guo17a.html).
This implementation is original. A positive scalar divides frozen logits;
class decisions/confusion/F1 must remain unchanged. No fitting of weights or
class thresholds, calibration-method search or test-driven hyperparameter change.

1. Verify baseline evidence, source-file hashes, the exact preserved JSON
   checkpoint hash and imported-data manifest hash before fitting.
2. Restore the fixed architecture/normalization and infer validation logits
   from driver 2 only (35 tasks).
3. Minimize mean validation NLL with temperature bounded to **[0.1, 100]**.
   Use 80 golden-section iterations on inverse temperature, where fixed-logit
   NLL is convex. Include identity and both endpoints; ties within `1e-12`
   prefer identity. A boundary solution is disclosed.
4. Freeze the scalar, then evaluate the previously reported driver-3 test
   (39 tasks). No test tensors or labels enter the fit function.
5. Assert weight/normalization bytes and class decisions remain unchanged;
   publish a data-only calibrator and audit report to ignored local storage.

The protocol, range, iteration count and ten reliability bins were chosen before
this audit's held-out outcomes. Repeats verify reproducibility, not model/method
selection. Cross-platform numeric identity is not promised.

## Metrics and error semantics

Report before/after per-class precision/recall/F1/support, confusion and macro
F1, multiclass Brier (sum over classes), and NLL directly from stable logsumexp.
The older baseline helper clips tiny probabilities at `1e-12`; this audit uses
unclipped finite logits for NLL, explicitly versioning that numeric distinction.

Reliability uses ten equal-width bins: `[i/10, (i+1)/10)`, with probability 1
included in the last bin. Report counts, mean probability, observed frequency,
absolute gap and sample-weighted ECE for top-label correctness and every
one-vs-rest source class. Empty-bin means/gaps are **null**, not zero evidence.
Small bins and point estimates do not establish population calibration.

Class-error counts describe disagreement with publisher labels, not confirmed
driving errors, causes or intent. There is no road-impact, phone-movement,
ordinary-driving or severe-event truth, no production severe-event mapping and
no trustworthy high-rate timing. False severe events/hour, severe PR-AUC and
detection latency remain **unavailable with reasons**, never fabricated as zero.
Production severe false-positive acceptance remains blocked on suitable evidence.

## Reuse and interpretation limits

The validation driver already selected the M7.2 checkpoint, so fitting a scalar
on it reuses selection data. The test driver and baseline results were already
reported in M7.2. This is a **retrospective audit**, not fresh blinded validation.
There are only 35 calibration and 39 test tasks in three source drivers, with
unverified units/frame/timing/annotation and unresolved route/device diversity.

Before/after results retain regressions and comparison to the frozen train-prior
baseline. Better probability metrics here do not authorize promotion or establish
safety, motorcycle/OEM generalization or on-device performance. The artifact is
an experiment; no downstream score/safety state consumes its probabilities.

## Reproduction / artifacts

Use the existing hash-pinned CPU environment; no new package is added:

```text
<venv-python> -m unittest tests.tool.test_calibration
<venv-python> -m ml.calibration --checkpoint-dir ml/checkpoints/eventnet-source-v1-20261114 --import-dir ml/data/private/imports/mendeley-driving-behavior--3--import-v1 --run-name calibration-source-v1
```

`ml/checkpoints/<run-name>/calibrator.json` and `report.json` contain scalar,
protocol, source hashes, code/runtime provenance, reuse disclosures, metrics and
limits. They stay ignored; existing runs are refused before fitting. Completed
audit evidence is published only as aggregate JSON/documentation. No weights,
raw telemetry, source clock-of-day or task-level prediction rows enter Git.

CI uses generated evidence only and checks fitting isolation, exact bin
boundaries, stable numerical loss, invariance, corruption/collision rejection and
repeatability. An actual frozen-source audit/repeat is a separate local gate.
