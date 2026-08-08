# INTEGRITY_ENGINE.md — Telemetry Integrity / Anti-Cheat

## When to read

Read for ranking eligibility, mock-location detection, anomaly analysis, corruption handling, sensor consistency, or integrity UI.

## 1. Purpose

Integrity auditing answers:

> Is this trip's telemetry coherent and trustworthy enough for analysis/ranking?

It does not attempt to prove malicious intent.

## 2. Evidence sources

### Deterministic checks

- platform mock-location signal;
- impossible GNSS jumps/speeds;
- timestamp disorder/manipulation;
- GNSS vs IMU disagreement;
- unrealistic acceleration transitions;
- sensor dropout;
- phone movement;
- repeated/replayed identical data patterns where detectable;
- corrupted/truncated chunks;
- suspiciously absent vehicle motion sensors during large GNSS changes.

### Anomaly model

A small autoencoder or other anomaly detector may learn legitimate relationships between motion channels. High reconstruction/anomaly score is evidence, not guilt.

## 3. Integrity output

Keep separate sub-scores/evidence:

- source integrity;
- GNSS consistency;
- IMU consistency;
- cross-sensor agreement;
- temporal integrity;
- anomaly score;
- overall eligibility.

User-facing states can be:

- Verified;
- Limited Confidence;
- Questionable;
- Unranked.

Avoid "Cheater" unless there is a future moderation process with strong evidence.

## 4. Ranking policy

A questionable/unranked trip can remain in private history. Integrity status primarily governs competitive/social trust.

## 5. Security through design, not obscurity alone

Do not publish every exploit threshold in client-visible UI if that would make spoofing trivial, but core architecture can remain open source. Favor multi-signal consistency, server-side validation of summaries, signed/versioned event outputs where appropriate, and continuously improving tests.

Open-source anti-cheat cannot depend solely on keeping code secret.

## 6. Model/rule audit

Persist rule/model version with integrity result. When a false positive is found, create a sanitized regression fixture.

## 7. Avoid false certainty

Train/public messaging must distinguish:

- low quality;
- anomalous;
- inconsistent;
- known platform mock-location signal;
- proven manipulation (rare).

## 8. Passenger/train problem

A phone on a train or in another vehicle may produce physically plausible motion. The system should not pretend it can always infer who is driving. Ranking eligibility may rely on declared vehicle/trip context plus consistency heuristics, but avoid unsupported identity claims.
