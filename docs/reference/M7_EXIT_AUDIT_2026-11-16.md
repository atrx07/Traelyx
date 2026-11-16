# M7 exit audit — 2026-11-16

## When to read

Read before deciding whether to start M8 or enable any M7 model. This audits
baseline `6ce5ca91afd5fa6a0681239a5704698e1e7c83e4`, all eleven M7 substeps,
their retained evidence, and the production boundaries. It does not activate M8,
change a promotion gate, or substitute for M8's release acceptance work.

## Verdict

**Conditional go for M8 hardening; no-go for formal M7 completion or public release.**

The deterministic application and its optional reviewed cloud commentary have a
validated engineering baseline. Starting hardening with production ML disabled is
reasonable. M7.4 remains blocked and M7.5 remains partial; their acceptance cannot
be erased by passing software tests. The maintainer must explicitly authorize
carrying those gates forward before M8 starts. No such transition is made here.

The recommended next action is M8 hardening with rules authoritative, no model
promotion, the local narrator unavailable, and the outstanding acceptance ledger
retained. Holding all hardening work until an experimental model succeeds is not
technically necessary. Claiming M7 is fully delivered or release-ready is not
supported by the evidence.

## Delivery and acceptance matrix

| Step | Delivered and checked | Remaining limitation / disposition |
|---|---|---|
| M7.1 | Versioned licensed registry, immutable offline imports, source hashes, synthetic fixture source and explicit quarantine. Fresh validation passes all three entries. | Source v2 lacks grouping/time and stays training-blocked; smoke data is synthetic-only; v3 supports only the bounded experiment. [Registry/import contract](../../ml/README.md). |
| M7.2 | Reproducible 492-parameter source-space TCN; driver grouping enforced before windows; train-only normalization; held-out-driver test macro F1 0.5378 versus majority 0.0851. | Only 35/35/39 train/validation/test tasks across three drivers. Seven source rows are not the planned aligned vehicle-frame 5–8 second feature contract. No accepted production feature units/frame/timing, normal/severe truth or rule-baseline superiority. Experiment complete, promotion blocked. [Evidence](eventnet-baseline-v1-result.json). |
| M7.3 | Frozen retrospective temperature/calibration and per-class error audit; weights/splits retained. Test NLL 2.5048→2.2166 and Brier 0.8891→0.8682. | ECE worsens 0.41561→0.41656; class prior still has better NLL/Brier. Reused validation and previously observed test data are disclosed. Severe false events/hour and detection latency are unavailable, not zero. Audit complete, safety acceptance open. [Evidence](eventnet-calibration-v1-result.json). |
| M7.4 | Repeatable ONNX export, exact hashes, permission-free standalone benchmark, and three recorded generated-input physical-device runs. | **Blocked:** int8 probability drift 0.0509469 exceeds frozen 0.05 gate. Int8 is 22,927 B versus float32 20,013 B, with no consistent warm speed advantage. No production efficiency/battery acceptance. Rejected artifact preserved. [Evidence](eventnet-mobile-v1-result.json). |
| M7.5 | Generated-only provider/audit/fallback foundation, quality/identity/probability validation and rule/score preservation. Production analysis records disabled inference. | **Partial:** no accepted real model, production feature adapter, governed class mapping, corroboration policy or runtime integration. Do not call this completed hybrid deployment. [Evidence](hybrid-event-evidence-v1-result.json). |
| M7.6 | Reproducible generated IntegrityNet comparison; 6/6 numeric injections versus native 4/6, both 0/16 known clean false flags. | Only generated signal, no field FPR. Strengthened deterministic alternatives, unseen legitimate/inconsistent examples, calibration and physical runtime/battery acceptance remain open. Experiment complete; model not promoted. [Evidence](integritynet-generated-v1-result.json). |
| M7.7 | Fixed ContextNet/temporal-rule experiment and prespecified value gate. | Candidate fails added-value, recall, coverage and open-set checks. Test predictions remain unopened. Keeping rules is the correct completed experiment outcome, not missing mandatory promotion. [Evidence](contextnet-generated-v1-result.json). |
| M7.8 | Fixed self-supervised embedding/summary comparator; both retrieve 80/80 validation programs and detect 40/40 controlled changes. | Fewer stable-pair false flags (2/40 versus 5/40) do not satisfy the frozen material-value gate. Test predictions remain unopened. Explicit production dimensions retained. Experiment complete. [Evidence](drivedna-generated-v1-result.json). |
| M7.9 | Source-bound local corrections, optimistic revision checks, per-note consent, reviewed categorical document export, quarantine-only offline receiver; additive schema4 migrations. | Contributions lack verified labels, aligned features, source quality and driver/trip grouping. They are not training-ready. Real signed-app/history upgrade rehearsal belongs to M8. [Evidence](event-correction-v1-result.json). |
| M7.10 | Secure BYO Groq settings, account-model discovery, explicit parked/idle request review, bounded transport and strict selection among existing wording choices. Recorded one personally approved live synthetic request. | This is reviewed wording selection, not free-form narration quality acceptance or an all-model availability/price guarantee. No live request repeated by this audit. Scoped contract complete. [Evidence](cloud-commentary-v1-result.json). |
| M7.11 | Strict bundled manifests/admission, verified no-backup artifact staging/removal, shared wording validator, explicit status and actual managed-byte accounting. Generated-only Pixel QA retained. | Catalog is empty; runtime/source unavailable. No neural generation or real weight-download transport. This satisfies the roadmap's architecture scope and the MVP's optional local-model clause; optional activation remains gated. [Evidence](local-commentary-v1-result.json). |

## Findings ordered by consequence

1. **Formal exit blocker — M7.4/M7.5 are unfinished.** The roadmap explicitly
   requires mobile acceptance and real hybrid integration. Current experiment
   output is not demonstrably better than deterministic rules in production.
   Runtime guards prevent these open scientific gates becoming unsafe app behavior.
   Source: [roadmap M7](../exec-plans/ROADMAP.md#m7--ml--advanced-commentary) and
   [promotion policy](../governance/ML_GOVERNANCE.md).
2. **Promotion blocker — data/measurement acceptance is missing.** Suitable unseen
   driver/device/mount/vehicle evidence, verified SI/frame/time contracts, governed
   event mapping, normal/severe truth and false severe events/hour are still needed.
   A new versioned protocol is required; do not retune against the old observed
   test set or loosen the quantization threshold after seeing its result.
3. **Release hold — physical reliability and Guardian acceptance remain open.**
   M6.8 active-driver lifecycle/recovery and physical/OEM/vehicle gates were carried
   forward by the maintainer. Generated tests and the prior phone repair are useful
   evidence, but do not close these gates. Much of this can be addressed during
   M8's torture/performance work; deferment does not imply a release waiver.
4. **Optional capability limits are honest and contained.** ContextNet/embedding
   rejection, IntegrityNet non-promotion and the missing local LLM are not reasons
   to force unvalidated models into the product. Keep the existing behavior and
   distinguish accepted architecture/experiments from deployed intelligence.
5. **Operational CI failure investigated.** The docs-only baseline run initially
   failed before application tests at the official SQLite asset download (HTTP
   403). The full implementation run had already passed. Only the failed job was
   rerun against the same baseline; no checksum, dependency or test gate changed.
   Attempt 2 passed all four jobs, including the final release build. The first
   failure remains recorded; it was not counted as validation.

No additional blocking runtime defect was identified in the reviewed M7 paths.
This is a bounded code/evidence audit, not a claim that all defects or all security
issues have been excluded.

## Production boundaries inspected

- `HybridEventEvidenceBoundary.productionAudit()` and its `LocalTripAnalysis`
  call site: constant disabled-model record; generated provider not wired into
  production analysis; rules/scoring/safety remain authoritative.
- EventNet driver partitions, train-only normalizer and fixed selection; frozen
  ContextNet/DriveDNA value-gate branches leave test predictions uncomputed.
- Corrections stay in a separate table, bind the full source snapshot and revision,
  and never update detections/scores. Consent/evidence is checked again after the
  document picker, before native export. Receiver accepts only bounded categorical
  declarations and marks training blocked. No uploader or auto-training added.
- Groq uses a fixed HTTPS host, no redirects, bounded payload/response/time,
  separate secure storage and backup exclusions. Reviewed wording inputs omit
  routes, measurements, identifiers and times; output indices are validated.
  No credential/response body is exposed in failure UI.
- Local narrator production bindings are explicitly unavailable. Artifact paths
  are owned/no-backup, staged and hash-verified, with before-use verification,
  explicit file-close acknowledgement, an owner-isolate lease and scoped removal.
  No cloud fallback or credential exists in this local path.
- Only schema4's additive correction table changes persistence in M7. Historical
  schema snapshots and legacy analysis behavior are retained; generated migration
  tests cover supported earlier schemas. Actual signed-device upgrade rehearsal
  remains M8 work.
- No private ML imports/checkpoints or production weights are tracked. The model
  benchmark app is separate; the normal main-target APK checks exclude QA markers
  and model weights. Latest recorded release is 65,400,562 B (~62.37 MiB), a
  196,991 B increase from M7.10, with no inference SDK.

## Validation evidence

- Fresh audit run: **592/592 Flutter tests, 105/105 Python regressions**, all three
  dataset-registry entries valid, format check and analysis clean. No retraining
  or reopening of the frozen experiment test sets was performed.
- Independently checked **39 recorded source-file hashes** across EventNet,
  calibration, mobile export, IntegrityNet, ContextNet and DriveDNA against their
  retained commits. Thirty-six match Git blob bytes directly; three baseline
  source hashes match the documented CRLF representation. No semantic mismatch.
- Both frozen baseline/calibration evidence hashes and retained float32/int8
  artifact sizes/hashes match. Failed context/embedding tests remain unopened.
- Baseline differs from green implementation source `06d0108` in five
  evidence/status documents only. That implementation's [four-job source CI](https://github.com/atrx07/Traelyx/actions/runs/43886630798)
  passed full Flutter/native tests, generated-source/schema equality, debug/release
  builds, ML/mobile tooling and cloud/Guardian regressions.
- Recorded native suite: **509/509**, no skips. App lint: zero errors, seven
  pre-existing warnings and one documented conservative usable-space advisory.
  Pixel tests used a separate generated-data package; the main app was untouched.
- Exact baseline [CI 43888823803, attempt 2](https://github.com/atrx07/Traelyx/actions/runs/43888823803)
  passed all four jobs after retrying the failed SQLite-download job. No source,
  dependency, checksum or test change was needed. Repository/privacy validation
  passes. See [the machine-readable audit result](m7-exit-audit-2026-11-16.json).

## Conditions for the next decision

To **start M8 hardening**, explicitly retain the M7.4 rejection/M7.5 partial status,
keep all unaccepted inference disabled, carry the physical/Guardian ledger forward,
and authorize the sequencing exception. No model download, promotion or live
Guardian operation follows from that authorization alone.

To **close formal M7**, either complete accepted model/feature/runtime evidence and
real hybrid integration, or explicitly revise/defer that required scope in the
authoritative roadmap. Never relabel failed acceptance as complete.

To **release publicly**, finish the applicable M8 reliability, battery, security,
upgrade, failure-UX, signing/install and release gates, plus a deliberate disposition
of all carried-forward safety/model/vehicle limitations. This audit provides no
release authorization.

Audit limits: no new physical/OEM/battery test, dangerous maneuver collection,
live account/Guardian mutation, real Groq request, signing action or deployment.
