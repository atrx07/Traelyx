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

## 9. M4.3 implemented deterministic integrity contract

Integrity-rules version 1 audits complete local trips from already-governed evidence: M3.1 raw-decoder validity, M3.2 GNSS decisions, raw GNSS/IMU quality flags, synchronized M3.5/M3.6 movement and cross-sensor confidence, and accepted M4.2 phone-movement events. It never consumes replay-reduced display values and does not infer malicious intent.

The output is categorical rather than a fabricated score. Each audit reports `verified`, `limited_confidence`, `questionable`, or `unranked` for source integrity, GNSS consistency, IMU consistency, cross-sensor agreement, temporal integrity, and the overall trip. Ranking eligibility maps explicitly to `eligible`, `eligible_with_limitations`, `review_required`, or `ineligible`. These are analysis/rank-trust states; private history remains separate. `Verified` means no version-1 integrity rule fired—it is not proof of driver identity, perfect sensors, or universally precise telemetry, whose limitations remain governed by M3.6 confidence.

Findings distinguish four meanings: `quality_limitation`, `platform_signal`, `inconsistency`, and `data_corruption`. Only inconsistency findings carry the `EVT_TELEMETRY_INCONSISTENCY` umbrella machine ID. GNSS gaps, raw IMU dropout/unreliable flags, and accepted phone movement are limited-confidence quality findings. A platform mock-location signal is a questionable platform finding and never solely causes automatic unranking. Clock discontinuity, implausible platform GNSS speed, and sustained cross-sensor or motion-without-IMU conflicts are inconsistency findings, not proof of manipulation.

An isolated M3.2 impossible-jump decision is questionable; two or more make the synthetic version-1 baseline unranked. Cross-sensor disagreement becomes questionable after one continuous second; a shorter episode is limited confidence. Confirmed movement without an available accelerometer or gyroscope becomes questionable after two continuous seconds; a shorter episode is limited confidence. Durations use the authoritative analysis cadence and preserve the first/last observation, maximum continuous duration, occurrence count, typed reasons, contributing dimensions, and all source algorithm versions.

Any M3.1 raw-trip decoder rejection—including corrupt, truncated, mixed-contract, sequence, checksum, or record-order failure—is unranked and does not trust or expose a trip identity. The exact decoder error/index/sequence remains audit evidence. A successful audit is repeatable and bounded-memory: it keeps one constant-size accumulator per fixed rule ID, not per-frame findings.

These values are synthetic-fixture-reviewed policy, not population-calibrated probabilities. Changes to rule meaning, thresholds, state reduction, rank mapping, or finding identity require a new integrity-rules version. M4.3 adds no persistence/schema, network, permission, recorder, Flutter bridge, UI, scoring, ML/anomaly model, moderation accusation, server ranking enforcement, or crash decision.
