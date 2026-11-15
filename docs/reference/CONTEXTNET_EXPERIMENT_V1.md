# ContextNet generated value experiment v1 — M7.7

The frozen manifest is `ml/experiments/contextnet-v1.json`. This is a generated
CPU experiment, not a production context classifier, driver-quality judgment,
field evaluation or narrator change. Existing procedural commentary uses event
repetition/cooldown; the comparator here is a new explicit experimental temporal
rule baseline, not an asserted five-state production classifier.

## Source / label / feature contract

Generate original mathematical 30/60/120-second sequences at one analytical
midpoint sample per one-second bin. Do not tile/stretch M3 fixtures or import
private/public maneuvers as context ground truth. Channels are speed (m/s),
longitudinal/lateral acceleration (m/s²), longitudinal jerk (m/s³), in an explicitly
generated vehicle frame. These are instantaneous analytical samples, not accepted
production extraction/calibration or anti-aliasing. Support/missingness is separate.

Five source programs label steady-cruise, stop/go, high lateral load, repeated
abrupt transitions and smoothly varying speed fixtures. `contextnet_corpus.py`
defines the exact analytical functions: base speed 8+0.35*profile, phase
0.13*profile+0.27*variant; sinusoids carry exact acceleration/jerk derivatives.
Cruise/load use amplitude0.12+0.005*profile and omega=pi/15; smooth variation uses
amplitude2.5+0.05*variant+0.01*profile and omega=pi/30; abrupt uses
amplitude2.5+0.05*profile and omega=pi/2. Load uses lateral2.2+0.04*profile; other
programs use lateral0.1*sin(t/10). Stop/go uses ten stopped seconds and twenty
seconds of sine-squared speed per 30-second cycle, with analytical derivatives.
These are scenario definitions, not real-driver labels or safe driving advice.

Assign fictional groups first: train1/3/5/7/9, validation2/8, test4/6. Each has
5 labels ×3 durations ×2 variants: 270 labelled cases (150/60/60). Each held-out
partition also has 20 unavailable-quality cases (five missing/unsupported bins
per 60-second case) and four stationary/mixed-load+abrupt open-set cases. Totals
are 150/84/84. Shared generators/kinematics do not establish independent physical
generalization or mutually exclusive real contexts. No coordinates/identities/
wall time, recorded data or consented contribution is involved. Original generated
data has its own CC0 dedication, preserving all historical artifacts/licenses.

## Comparison / gate

Both methods receive the same four channels and exact times/support. Missing or
unsupported frames abstain, without interpolation or fabricated zero features.
The temporal rules count stopped/moving transitions, lateral-load occupancy and
separate signed jerk episodes (including an opposite-sign transition while
magnitude remains above threshold), then discriminate stable versus smoothly varying speed;
multiple dynamic matches or stationary/out-of-contract cases abstain. Exact
thresholds are frozen in the manifest. They do not change production event rules.

One GRU input4/hidden8/head5 (381 parameters), CPU PyTorch2.15.0+cpu, seed7707,
one thread, Adam lr0.01, 80 full-batch epochs. No tuning, early stopping or model
selection. Normalization uses all 10,500 valid training frames only, with population
std floor1e-6. Packed sequence lengths exclude batch padding from recurrent state;
no padded/missing test data fits normalization. Use a fixed max-softmax>=0.6
selective cutoff, explicitly uncalibrated. No confidence percentage is asserted.

Report validation argmax/selective precision/recall/F1, abstention-column confusion,
coverage, raw-probability Brier/NLL and quality/open-case diagnostics. The material
value gate requires selective macro F1 >=rules+0.02, no per-class recall/labelled
coverage regression, no more non-abstained open cases and matching quality
abstention. Gate failure retains rules and leaves test predictions/metrics
uncomputed. Test structure/label metadata is still validated; it is not physically
unseen field data. If validation passes, open test once with the same gate.
No after-result tuning/retry/calibration. A negative result completes the experiment.

## Artifacts / reproduction

Preserve generated source, safe JSON model/normalizer, exact protocol/manifest/
code/data hashes, validation result and test-opening status. Refuse overwrite and
output links; no pickle/downloaded weights. Require byte-identical artifacts
within the pinned platform, without asserting cross-platform identity. Model/data
artifacts stay ignored; commit aggregates only.

```text
python -m pip install -r ml/requirements-eventnet.txt
python -m unittest tests.tool.test_contextnet
python -m ml.contextnet_corpus --output .dart_tool/contextnet-fixtures-v1.json
python -m ml.contextnet --source .dart_tool/contextnet-fixtures-v1.json --expected-sha256 <generated source SHA256> --run-name contextnet-generated-v1
```

Use the existing isolated Windows Python3.14/Linux Python3.12 CPU environment.
CI generates the same source contract and executes two repeat runs. No new
dependency, app/runtime/provider, network data field, migration, phone, recorder,
scoring/integrity/Guardian or narrator behavior is introduced. Real-context labels,
overlap/open-set/calibration, runtime/battery/device validation and all earlier
acceptance gates remain open. Stop after M7.7 before M7.8 authorization.
