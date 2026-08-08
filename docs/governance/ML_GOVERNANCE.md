# ML_GOVERNANCE.md — Model Promotion & Audit Policy

## When to read

Read when training, evaluating, replacing, quantizing, deploying, or changing features/labels for a production model.

## 1. Model status lifecycle

- Experiment
- Candidate
- Shadow / evaluation
- Production
- Deprecated

Only explicit promotion can make a model production.

## 2. Production manifest required

Each production model must include:

- model name/version;
- architecture revision;
- training code commit;
- dataset version(s);
- label schema version;
- feature schema version;
- split strategy;
- metrics by class/subgroup where available;
- calibration method/metrics;
- model file hash;
- quantization/runtime;
- size;
- target-device latency benchmark;
- known limitations.

## 3. Evaluation split

Prefer driver-held-out test sets. Prevent leakage through adjacent windows, same trips, exact routes, device/mount signatures where possible.

## 4. Required metrics

Event classification:

- per-class precision/recall/F1;
- macro F1;
- PR-AUC for rare severe classes;
- false severe events/hour;
- detection latency;
- calibration metrics.

Integrity/anomaly:

- false-positive rate on legitimate drives;
- detection rate on known corrupt/synthetic anomalies;
- calibration/threshold sensitivity.

On-device:

- model bytes;
- cold/warm inference latency;
- CPU utilization;
- memory;
- battery impact where meaningful.

## 5. Promotion rule

A candidate does not replace production solely because one headline metric improves.

Promotion requires no unacceptable regression in:

- severe false positives;
- calibration;
- latency/battery;
- model size;
- important vehicle/device subgroups;
- fixture regression corpus.

Thresholds become explicit once baseline data exists.

## 6. Explainability/audit

Persist model version and probabilities/evidence sufficient for replaying important inferences. Do not promise human-level causal explanations from a neural model; explain downstream use honestly.

## 7. Rollback

Keep prior supported model artifact/manifests until a new release is validated. App should be able to identify which model generated historic evidence.

## 8. LLM exclusion

Generative commentary models are not governed as driving classifiers, but they are still evaluated for privacy/safety/tone. They may not influence scoring, integrity, or crash detection.
