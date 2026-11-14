# EventNet mobile export v1 — experiment only

M7.4 preserves `EVENTNET_BASELINE_V1.md` and `EVENTNET_CALIBRATION_V1.md`.
No source-space output is a Traelyx event, score or safety decision. Production
eligibility remains false, including if numerical and device gates pass.

## Frozen protocol

Input is float32 NCT `[1,6,7]`, six source channels, seven source rows; normalization
is embedded from the frozen training-only normalizer. Output is four raw logits.
The separately frozen temperature 1.1457625347025238 produces source-class
probabilities. Unsupported units/frame/timing and missing normal/severe truth
remain unchanged. Do not interpret seven rows as an aligned driving interval.

Export fixed-shape float32 ONNX opset 18. Require max absolute raw-logit drift
from PyTorch <=1e-4 on every partition. One static S8S8 per-channel QDQ MinMax
export fits ranges on the 35 training windows only, with symmetric activation
and weight ranges. Validation/test never fit ranges. Quantized gate: max
source-class probability drift <=0.05 on every partition and test macro F1 loss
<=0.02. A failure stays rejected; no test-guided configuration search is allowed.
Record per-class metrics, confusion, Brier/NLL and all unavailable safety metrics.

Native parity compares each artifact against its own host output on eight
generated inputs: max absolute raw-logit error <=1e-3 and probability error
<=1e-4. Artifacts/references have SHA-256 identity. The harness never receives
public task windows, private telemetry, device IDs or accounts.

## Dependency evaluation (2026-11-14)

These are optional development/benchmark dependencies, with no paid service or
core-app dependency. Existing Python stdlib cannot export/execute a TCN. Existing
PyTorch remains pinned separately, preserving its historical environment.

| Dependency | Purpose / license / boundary |
| --- | --- |
| ONNX 1.23.2 | Graph interchange/checker; Apache-2.0; optional host only |
| ONNX Runtime 1.32.0 | CPU quantization/host/native execution; MIT; replaceable harness |
| ONNX Script 0.7.2 / ONNX IR 1.1.0 | Modern PyTorch export; MIT / Apache-2.0; host only |
| NumPy 2.5.4 | Numeric interchange; BSD-3-Clause plus bundled permissive licenses; host only |
| ml_dtypes 0.6.0 / protobuf 7.36.2 | ONNX datatypes/serialization; Apache-2.0 / BSD-3-Clause; host only |
| flatbuffers 25.12.19 / packaging 26.3 | ORT/tooling transitives; Apache-2.0 / Apache-2.0 or BSD-2-Clause; host only |

Official stable releases and wheels were checked through PyPI/Maven; exact
Windows CPython 3.14 and Linux CPython 3.12 wheel hashes are in
`ml/requirements-mobile.txt`. Install the CPU lock first, then additions with
`--no-deps`; `pip check` verifies the combined graph. No implicit unpinned
installation is permitted. The Android AAR has no Maven runtime transitives;
minSDK 24, compile/targetSDK 36, arm64-only benchmark, Java 17 source/JDK 21 build.
Reviewed ExecuTorch 1.6.0 is a viable alternative but has a broader export graph
(torchao/pandas and platform-conditioned tooling). No production selection follows.

Known attack surfaces are native model parsing and dependency supply-chain
updates. Accept only locally generated digest-verified graphs, not arbitrary
downloads, pickle or user models. Pin official binaries and review future
updates rather than silently upgrading. This review is not a vulnerability-free
guarantee. There is no telemetry/data sharing requirement or billing requirement.

**Privacy:** the official Android AAR includes an initializing telemetry provider
and INTERNET/ACCESS_NETWORK_STATE. The harness removes all three and verifies
zero packaged permissions/providers before installation. Set
`ORT_DISABLE_TELEMETRY=1` before importing/loading ORT, then disable environment
telemetry explicitly. The package has no access to core-app private storage.
Do not add sensors, background recording, UI, network or wake locks. Run bounded
CPU-only work off the UI thread, close native tensors/sessions, then uninstall
only the new benchmark package. Model/runtime/APK sizes and process CPU/PSS are
reported with cold/warm timing. Battery drain/hour remains unavailable in this
short USB-connected run; no performance claim for production recording follows.

Official sources: [quantization](https://onnxruntime.ai/docs/performance/model-optimizations/quantization.html),
[mobile](https://onnxruntime.ai/docs/get-started/with-mobile.html),
[runtime privacy](https://github.com/microsoft/onnxruntime/blob/main/docs/Privacy.md),
[ExecuTorch Android](https://docs.pytorch.org/executorch/stable/using-executorch-android.html).

## Reproduction

Use a separate environment; do not update the preserved baseline environment.
Set process `ORT_DISABLE_TELEMETRY=1` before any ORT use.

```text
python -m pip install -r ml/requirements-eventnet.txt
python -m pip install --no-deps -r ml/requirements-mobile.txt
python -m pip check
python -W error::ResourceWarning -m unittest tests.tool.test_mobile_export
python -m ml.mobile_export --checkpoint-dir ml/checkpoints/eventnet-source-v1-20261114 --calibrator-dir ml/checkpoints/calibration-source-v1-20261114 --import-dir ml/data/private/imports/mendeley-driving-behavior--3--import-v1 --run-name mobile-source-v1-20261114
```

Download the official AAR to the ignored
`.dart_tool/m7-runtime-review/onnxruntime-android-1.32.0.aar`:
[Maven binary](https://repo.maven.apache.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.32.0/onnxruntime-android-1.32.0.aar).
Expected SHA-256:
`8e8dbb412ed4939675a157702f0c1e3621b436a645af7f7244536ac20bfad628`.
The build verifies it before packaging. Build independently using the existing
Gradle wrapper, passing an absolute export directory and an installed SDK:

```text
android/gradlew -p ml/android-benchmark -PexportDir=/absolute/export/directory assembleDebug lintDebug --no-daemon
```

Export `apkanalyzer manifest print` from the exact APK and run
`python -m ml.verify_mobile_apk APK MANIFEST_XML`. This checks asset hashes,
arm64-only runtime libraries and the packaged privacy contract. Inspect the
final APK with Android SDK apkanalyzer: exact package
`io.github.atrx07.traelyx.mlbenchmark`, zero permissions/providers/activities/
services/receivers and self-targeting instrumentation only. Confirm this package
is absent on the authorized arm64 phone before installing. Use `am instrument -w`
with `.BenchmarkInstrumentation`, retrieve only its aggregate `files/result.json`
with its own `run-as`, then uninstall this task-owned package. Never clear/update
the core app, change permissions/settings or read its files. Save private device
identifiers only in ignored local files; commit aggregate evidence only.

Cold runtime initialization is measured once per fresh instrumentation process.
Session/first-inference timings are ordered float32 then int8 in that process;
cache/JIT/order effects are not removed. Warm results use 200 warmup and 10,000
measured iterations on one fixed generated input, with nearest-rank median/p95.
Process CPU is milliseconds accumulated over the entire warm interval, expressed
also as percent of one core; thread CPU has nanosecond resolution. PSS/heap are
snapshots, not peak-memory or sustained real-recording guarantees. CPU threads are
fixed to one intra-op and one inter-op; only CPU execution is enabled.
