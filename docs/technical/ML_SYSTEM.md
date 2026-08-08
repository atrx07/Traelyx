# ML_SYSTEM.md — Machine Learning Architecture

## When to read

Read for model architecture, features, inference, training, deployment, audit records, or when deciding whether a behavior belongs in ML versus deterministic logic.

## 1. ML philosophy

The app uses a hybrid system:

> Physics/rules establish evidence → ML recognizes patterns/context/anomalies → explicit logic produces scores/safety decisions → narrator turns outcomes into optional language.

Do not train one giant model to output "driver quality."

## 2. Proposed model roles

### EventNet — short-window event recognition

Candidate architecture: small **1D Temporal Convolutional Network (TCN)**.

Inputs may include a 5–8 second aligned window of:

- vehicle-frame longitudinal/lateral/vertical acceleration;
- gyro/yaw channels;
- filtered speed;
- GPS-derived acceleration;
- heading change;
- GNSS accuracy;
- telemetry quality.

Outputs: probabilities for event classes such as normal, strong acceleration, strong braking, high-load left/right corner, road impact, phone movement.

Why TCN candidate:

- efficient temporal convolutions;
- short high-rate sequence suitability;
- mobile-friendly inference;
- parallelizable training/inference.

Architecture must be benchmarked; TCN is not dogma.

### ContextNet — longer behavioral context

Candidate: tiny GRU or temporal network over lower-rate event/context features for 30–120 second context.

Possible states:

- steady cruising;
- stop-and-go;
- high dynamic load;
- repeated abrupt transitions;
- smooth consistent section.

Use only if it adds validated value over deterministic context.

### IntegrityNet — anomaly evidence

Candidate: small autoencoder or compact anomaly model trained on coherent telemetry relationships.

High reconstruction error contributes to integrity uncertainty; it does not autonomously ban a trip.

### DriveDNA encoder — future self-supervised style representation

A small segment/trip encoder may produce a low-dimensional embedding of driving style used for similarity/deviation trends.

It must supplement, not replace, explainable Drive DNA dimensions.

### Narrator selector — optional

A small ranking/classifier could estimate whether an event is interesting enough for commentary and its category. Generative text is separate.

## 3. Not ML

Prefer deterministic/physical methods for:

- unit conversion;
- timestamp alignment;
- coordinate transforms;
- basic gravity/orientation math;
- simple outlier sanity checks;
- final score formula;
- Guardian safety-state policy;
- API-key/provider routing.

## 4. Training stack

Recommended:

- Python;
- PyTorch;
- NumPy/Polars/Pandas as appropriate;
- SciPy;
- scikit-learn;
- Optuna or equivalent for bounded tuning;
- notebooks for exploration only, reproducible scripts/config for production training.

## 5. Deployment

Target small quantized edge models. Candidate runtime: ExecuTorch or another well-maintained Android-capable runtime selected through benchmarking.

Baseline execution should work on ordinary CPU. Hardware acceleration is optional optimization, not required for correctness.

## 6. Model size targets

Design targets, not promises:

- EventNet ~1–3 MB quantized;
- ContextNet ~1–4 MB;
- IntegrityNet <~1–2 MB;
- DriveDNA encoder ~1–3 MB.

Total core ML should ideally remain in low tens of MB or less. Validate with actual exported artifacts.

## 7. Inference audit record

For consequential ML evidence, retain enough metadata to reproduce/explain:

```text
prediction_id
model_name
model_version
model_hash
feature_schema_version
input_window reference/hash
predicted class/probabilities
calibrated confidence
sensor quality
rules/corroboration summary
timestamp
```

Do not persist enormous duplicate windows if a stable reference into local raw data is sufficient.

## 8. Dataset splitting

Never randomly split windows from the same driver's same trips across train/test and then advertise the result as generalization.

Preferred hierarchy:

- driver-held-out;
- device/mount diversity;
- route diversity;
- vehicle diversity;
- day/night/weather/road diversity when relevant.

## 9. Metrics

Depending on task:

- precision/recall/F1 per class;
- macro F1;
- PR-AUC for rare events;
- ROC-AUC only where informative;
- false severe events per driving hour;
- detection latency;
- calibration error/Brier/ECE;
- confusion matrix;
- model size;
- inference latency;
- CPU/battery impact.

Accuracy alone is forbidden as promotion justification.

## 10. Data sources

Public smartphone driving datasets may bootstrap development if licenses permit. Final models should be validated on project-relevant data, especially motorcycles and diverse phone mounting.

## 11. User labeling

After a trip, users may correct event detections:

```text
Hard braking detected here.
[ Correct ] [ Not braking ] [ Pothole ] [ Unsure ]
```

Never ask for labels while driving.

Corrections become training data only under explicit contribution consent.

## 12. LLMs

LLMs are optional commentary engines only. They do not analyze raw telemetry for safety/scoring in the MVP.
