# IntegrityNet generated baseline v1 — M7.6 experiment

The frozen configuration and generated dataset registration are in
`ml/experiments/integritynet-v1.json`, separate from historical M7.1 imports.
This experiment compares a small CPU autoencoder with the actual native
`IntegrityPipeline` version 1. No app integration or promotion follows.

## Source, labels and split

Use the governed M3 generated corpus, never public maneuver labels or private
recordings as integrity ground truth. Nine fictional profiles perturb raw IMU
gain/bias deterministically: gain=1+((profile*7)%13-6)*0.002 and
bias=((profile*17)%11-5)*0.0007, with x+=bias/y-=bias. Static perturbations are
fixtures, not measured hardware. Groups 1/3/5/7/9 train, 2/8 validation, 4/6 test
are assigned before generating/aggregating cases. Every family shares the same
scenario generator across partitions; no real-driver/generalization claim.

Eight coherent scenarios per profile yield 40 training-clean cases. Each held-out
profile adds eight diagnostic cases: source speed 400 m/s, gyro-z offset +4 rad/s,
or accelerometer-y offset +12 m/s² during elapsed 5–11.5 seconds; an explicit mock
signal; governed GNSS loss/phone movement; corrupt header/truncated final chunk.
Injections operate on generated `SMOOTH_STRAIGHT`, not public-road collection.
Validation/test each contain 16 clean, six numeric injections, two platform,
four quality and four corruption cases: 104 total. Injection provenance supplies
labels independently of the baseline. Never collapse these roles into guilt.

Run unchanged native decode→analysis/confidence→events→integrity for the baseline.
Export only CSV with synthetic IDs, categories, rule states/kinds/IDs and eight
whole-trip raw-signal summaries: source speed mean/max/population std; acceleration
norm mean/std (including gravity); gyro norm mean/max/std. Units are m/s, m/s² and
rad/s as named. No positions, raw samples, wall times or real identities leave
the generated test. Decoder-invalid cases have no features; learned inference
abstains and deterministic corruption handling remains authoritative.

## Fit, threshold and comparison

Use the existing isolated hash-pinned CPU PyTorch environment. Fixed seed7606,
one thread, 8→4→2→4→8 autoencoder (98 parameters), ReLU hidden/linear output,
Adam lr0.01 for 200 full-batch epochs. No search, early stopping or checkpoint
selection. Mean/std fit on training-clean cases only; population std is clamped
at 1e-6. Fit reconstruction-MSE threshold on validation-clean cases only:
nearest-rank 97.5th percentile +1e-12. Never fit on validation injections/test.

Freeze fitting before test evaluation. Compare numeric-injection recall and
synthetic clean false-flag rate against native `INCONSISTENCY` findings. Report
all category/family slices, abstentions and coverage. Keep platform, quality and
corruption meanings visible. Fixed 0.5/1/2 threshold multipliers are sensitivity
diagnostics, not alternatives from which to select a better test result.

Generated added-value flag requires no clean-FPR or numeric-recall regression
and a strict improvement in one. A negative result completes the comparison and
retains deterministic rules. Even a positive generated result remains experiment
only; real legitimate-drive FPR and calibrated probability are null, not zero.
No ranking, scoring, integrity, Guardian or safety state consumes the model.

## Artifacts / reproduction / validation

Safe data-only JSON weights, train normalization, frozen threshold, fixture hash,
manifest/config/source hashes, source commit and full aggregate metrics identify
the experiment. Refuse overwrite and symlink/junction output ancestors. No pickle
or downloaded model. Repeats must be byte-identical within the pinned platform;
cross-platform numeric identity is not promised.

The native test exporter accepts only the explicit absolute ignored destination
`<repository>/.dart_tool/integrity-fixtures-v1.csv` and refuses overwrite:

```text
TRAELYX_INTEGRITY_FIXTURE_OUTPUT=<absolute repository>/.dart_tool/integrity-fixtures-v1.csv
android/gradlew -p android :app:testDebugUnitTest --tests '*IntegrityExperimentFixtureTest'
python -m unittest tests.tool.test_integritynet
python -m ml.integritynet --source .dart_tool/integrity-fixtures-v1.csv --expected-sha256 <SHA256 of generated CSV> --run-name integritynet-generated-v1
```

Use JDK21 for native tests and install `ml/requirements-eventnet.txt` into an
isolated Windows Python3.14/Linux Python3.12 CPU environment. No new dependency,
runtime, provider, network operation, data upload or device work is introduced.
CI exports generated native features and runs the same CPU fit/evaluation twice.
Keep raw features/checkpoints ignored; commit aggregate evidence only. Production
data/feature/model/runtime acceptance and M6.8 physical/vehicle gates stay open.
