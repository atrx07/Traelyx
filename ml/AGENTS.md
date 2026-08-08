# ml/AGENTS.md — Traelyx Machine Learning Scope

Applies to files under `ml/`.

## Read selectively

Primary references: `docs/technical/ML_SYSTEM.md`, `docs/governance/ML_GOVERNANCE.md`, `DATASET_GOVERNANCE.md`, and the affected event/telemetry schemas.

## Non-negotiables

- ML is evidence, not unquestioned authority.
- No model may silently replace explicit safety logic or final scoring logic.
- Never report raw accuracy as the sole performance metric.
- Validation/test splits must be driver-held-out where identity leakage is possible.
- Avoid route/device/mount leakage between train/test partitions.
- All production models require reproducible manifests, hashes, feature schema, metrics, and model version.
- Benchmark mobile size, latency, and battery/CPU impact before production promotion.
- Model output must include calibrated probabilities/confidence where the downstream contract expects them.
- LLMs are not used for crash detection, score calculation, integrity verdicts, or safety state transitions.
- Do not train on user-contributed data without consent and dataset governance.

## Promotion gate

Follow `ML_GOVERNANCE.md`. A numerically "better" model is not automatically a valid replacement if false severe events, calibration, runtime, or model size regress.
