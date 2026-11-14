# EventNet retrospective calibration / error audit v1 (M7.3)

**Status:** M7.3 experimental audit complete, 2026-11-14. Frozen audit/repeat,
53 local Python checks and full [CI 43607386501](https://github.com/atrx07/Traelyx/actions/runs/43607386501)
pass for source `5e8d2ff` (all four jobs). No production acceptance/promotion.

## Recorded retrospective audit — 2026-11-14

Frozen audit source `5e8d2ff19824ab1aa045186ce7f77cb4e158c97e` ran twice with
clean provenance. Calibrator and complete audit report are byte-identical in
the recorded CPU environment. The M7.2 model/normalization bytes remain unchanged.
Validation-only fitting selected **T = 1.1457625347025238**, inside the frozen
bounds; there was no boundary solution or post-test retuning. Aggregate evidence:
[`eventnet-calibration-v1-result.json`](eventnet-calibration-v1-result.json).

| Metric | Validation before → after (35 tasks) | Previously reported test before → after (39 tasks) |
|---|---|---|
| NLL, lower is better | 0.110679 → 0.108903 | 2.504756 → 2.216558 |
| Multiclass Brier, lower is better | 0.070090 → 0.068655 | 0.889123 → 0.868231 |
| Top-label ECE, lower is better | 0.044247 → 0.062759 | 0.415610 → 0.416560 |
| Macro F1 | 0.973389 → 0.973389 | 0.537838 → 0.537838 |

NLL/Brier improve, while top-label ECE regresses in both partitions. The
test source-braking classwise ECE also worsens (0.313385 → 0.321271); the other
three test classwise ECE values improve. All four validation classwise ECE
values worsen. These descriptive sparse-bin results are retained, not used to
select another scalar or method. The frozen class-prior test Brier/NLL
(0.761402 / 1.408993) are still better than the scaled model's scores.
No model or calibrator is promoted; production eligibility remains false.

### Source-label disagreement analysis

The confusion matrix is unchanged: 19 of 39 test tasks disagree with source
labels. These are class-label disagreements, not measured severe false alerts.

| Source label | Support | Disagreements | Other predicted source labels |
|---|---:|---:|---|
| Sudden acceleration | 8 | 3 | Braking: 3 |
| Sudden right turn | 9 | 2 | Acceleration: 1; braking: 1 |
| Sudden left turn | 7 | 5 | Acceleration: 4; braking: 1 |
| Sudden braking | 15 | 9 | Acceleration: 9 |

The validation/test performance gap persists. Source frame, units, annotation
boundaries and route/device/mount diversity are unverified; this audit cannot
identify a cause or assign driver fault. A scalar cannot repair class errors.
False severe events/hour, severe PR-AUC and detection latency remain unavailable.
Neither a zero rate nor production safety acceptance has been established.

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
