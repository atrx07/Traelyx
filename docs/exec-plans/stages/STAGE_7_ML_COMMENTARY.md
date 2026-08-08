# Stage 7 Playbook — ML & Advanced Commentary

## Goal

Add validated machine-learning evidence and optional generative personality without sacrificing auditability or storage.

## Minimum references

`ml/AGENTS.md`, `ML_SYSTEM.md`, `ML_GOVERNANCE.md`, `DATASET_GOVERNANCE.md`, commentary/provider specs.

## Work units

1. Register public/project datasets and licenses.
2. Lock label/feature schemas.
3. Construct driver-held-out split before window generation.
4. Train simple deterministic/classical baseline for comparison.
5. Train EventNet TCN candidate.
6. Evaluate per-class precision/recall/F1/PR-AUC/false severe events per hour/calibration.
7. Analyze failure fixtures and retrain only with documented changes.
8. Quantize/export and benchmark mobile inference.
9. Integrate ML probabilities as evidence beside deterministic rules.
10. Generate production manifest/hash.
11. Experiment with IntegrityNet; promote only if it improves false-positive tradeoff.
12. Experiment with ContextNet; do not ship complexity without measurable value.
13. Add post-drive correction UI and separate data-contribution consent.
14. Implement cloud CommentaryProvider interface.
15. Implement BYO Groq adapter if provider still suitable at implementation time.
16. Fetch/discover available model IDs rather than relying on historical planning names.
17. Store key securely and sanitize event dossier.
18. Benchmark candidate commentary models using `commentary-benchmark.yaml` for warmth/humor, not just capability.
19. Implement optional local-model provider/download if resource budget permits.

## Acceptance

- production model beats/justifies itself against deterministic baseline;
- no driver leakage in reported test set;
- model manifest reproducible;
- app still works if model/provider is unavailable;
- cloud commentary receives no precise route by default;
- large local model is never bundled silently.
