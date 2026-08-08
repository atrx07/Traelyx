# Traelyx — MVP Stages & Executable Steps

## Planning assumptions

Feature-rich agent-assisted MVP:

- focused/intensive: ~12–14 weeks;
- part-time/college schedule: ~14–20 calendar weeks;
- internal prototype can appear around week 6;
- usable alpha around week 10;
- ~50 major executable steps.

Stages overlap, especially data collection/ML. Estimates are not promises.

---

# Stage 0 — Governance & Project Bootstrap

**Milestone M0: Skeleton**
**Target:** ~3–5 focused days

### 0.1 Confirm identity
- product name: `Traelyx`;
- repository and Flutter project identifier: `traelyx`;
- Android application ID;
- initial versioning convention;
- review naming conflicts before public release.

### 0.2 Initialize repository
- Flutter Android project;
- Git;
- directory responsibility boundaries;
- copy governance pack.

### 0.3 Toolchain pinning
- Flutter/Dart constraints;
- Android compile/target/min SDK decisions;
- JDK/Gradle setup;
- Python ML environment approach.

### 0.4 Quality commands
- formatter;
- static analysis;
- Flutter tests;
- Kotlin tests;
- JSON/YAML validation.

### 0.5 CI foundation
- GitHub Actions analysis/tests;
- debug/release-validation build without private signing key;
- secret scanning;
- artifact size reporting.

### 0.6 Core architecture skeleton
- Flutter feature/core modules;
- native bridge skeleton;
- Drift setup;
- provider/map interfaces.

**Exit:** app launches; CI green; docs discoverable; no secret/signing material in repo.

---

# Stage 1 — Application Foundation

**Target:** ~4–6 focused days

### 1.1 Design tokens/theme
Dark-first semantic tokens, typography, spacing, motion primitives.

### 1.2 Navigation
Drive / Trips / DNA / Social / You skeleton with deep-link-safe routing.

### 1.3 Local settings
Non-secret settings persistence + secure-storage abstraction for secrets.

### 1.4 Drift schema v1
Vehicles, trips, chunks index, events, scores, baselines, sync queue.

### 1.5 Migration harness
Database upgrade fixture tests before data exists in the wild.

### 1.6 Diagnostics shell
App/build info, DB version, recorder state placeholder, storage breakdown.

**Exit:** clean local-first app shell with reliable persistence foundation.

---

# Stage 2 — Native Recording Engine

**Milestone M1: Recorder**
**Target:** ~1.5–2 weeks

### 2.1 Foreground service lifecycle
Start/stop/query/recovery and persistent active-trip state.

### 2.2 GNSS acquisition
Location/speed/bearing/accuracy/source timestamps and health counters.

### 2.3 IMU acquisition
Accelerometer/gyro source timestamps, accuracy, batching.

### 2.4 Crash-safe buffering
Bounded buffers + durable telemetry chunks + checksum/atomic writes.

### 2.5 Flutter↔Kotlin bridge
Commands + recorder status/live health without requiring Flutter for acquisition.

### 2.6 Permissions/onboarding
Contextual Android permissions and foreground notification.

### 2.7 Service recovery tests
Screen lock, background, activity recreate, network loss, GNSS loss.

### 2.8 First real-drive fixture
30–60 minute trip; preserve/export synchronized raw timeline.

**Exit:** real physical drive can be recorded with screen locked and recovered intact.

---

# Stage 3 — Telemetry Processing Engine

**Milestone M2 foundation: trustworthy derived telemetry**
**Target:** ~1–2 weeks

### 3.1 Decoder/resampler
Versioned raw chunk decoder and time alignment.

### 3.2 GNSS sanity filtering
Accuracy/gap/impossible jump handling, distance accumulation.

### 3.3 IMU calibration
Bias/stationary calibration path and quality state.

### 3.4 Orientation/frame transform
Device → world/vehicle frame with explicit confidence.

### 3.5 Derived channels
Filtered speed, longitudinal/lateral/vertical accel, jerk, yaw/heading change.

### 3.6 Telemetry confidence v1
Subcomponents + explainable aggregate eligibility.

### 3.7 Replay channel generator
Reduced synchronized timeline optimized for display.

### 3.8 Fixture regression corpus
Straight/corner/brake/pothole/phone-move/GPS-loss cases.

**Exit:** derived telemetry is explainable, confidence-aware, and replayable.

---

# Stage 4 — Deterministic Intelligence v1

**Milestone M3: Driver**
**Target:** ~1–1.5 weeks

### 4.1 Event taxonomy implementation
Strong accel/brake, lateral load, abrupt transitions, road impact, phone moved.

### 4.2 Event merge/debounce
Coherent maneuver-level events rather than window spam.

### 4.3 Integrity rules v1
Cross-sensor consistency, mock signal, impossible jumps, corrupted chunks.

### 4.4 Scoring v1
Explicit dimension formulas with confidence weighting and audit contributions.

### 4.5 Drive DNA baseline
Smoothness/braking/acceleration/cornering/consistency.

### 4.6 Personal/vehicle baseline lifecycle
Emerging/established/recalibrating behavior.

### 4.7 Explanation data
Every score/event has a user-facing reason path.

**Exit:** useful analysis works with no ML dependency.

---

# Stage 5 — Experience & Replay

**Milestone M4: Experience**
**Target:** ~1.5–2 weeks

### 5.1 Ready/Drive screen
Glanceable recorder health and safe minimal live mode.

### 5.2 Trip history/result
Shareable rich result hierarchy with confidence/integrity.

### 5.3 Drive DNA visual
Original signature/ring treatment, trends, insufficient-data states.

### 5.4 Map abstraction + route rendering
Provider-neutral map component and cache controls.

### 5.5 Synchronized replay clock
Map + graphs + events tied to one timeline.

### 5.6 Replay animations
Camera framing, marker/path progress, event pulses, pause/scrub/speed.

### 5.7 Procedural road commentary
Tone packs, context/cooldown/interestingness, anchored bubbles.

### 5.8 Reduced-motion/accessibility
Alternative transitions and accessible severity/metrics.

### 5.9 Storage manager/export
Raw retention controls, map cache, debug export/anonymization.

**Exit:** app is fun to use/replay, not merely technically correct.

---

# Stage 6 — Connected / Social Layer

**Milestone M5: Connected**
**Target:** ~1–1.5 weeks

### 6.1 Supabase project/schema/RLS
Free-tier connected layer with explicit policies.

### 6.2 Auth UX
Continue locally + sign-in methods + secure sessions.

### 6.3 Local→account migration
Optional compact summary sync without raw-route auto-upload.

### 6.4 Profiles/vehicles sync
Sanitized public/private separation.

### 6.5 Friends/social
Basic relationship capability with abuse/privacy controls.

### 6.6 Safe leaderboards
Smoothness/consistency/improvement; server-validated eligibility.

### 6.7 Guardian pairing
Short-lived token/QR, acceptance, granular permissions.

### 6.8 Guardian alerts
Event-triggered severe/crash-like alert flow + deduplication.

**Exit:** online features add value without breaking local-first privacy.

---

# Stage 7 — ML & Advanced Commentary

**Milestone M6: Intelligence**
**Target:** ~2–3 weeks of engineering plus ongoing data collection

### 7.1 Dataset registry/import
Public licensed data + project fixture corpus.

### 7.2 EventNet baseline
TCN candidate with driver-held-out evaluation.

### 7.3 Calibration and error analysis
Per-class metrics, false severe events/hour, confidence calibration.

### 7.4 Mobile export/inference
Quantized model and on-device benchmark.

### 7.5 Hybrid event integration
Rules + EventNet evidence + audit record.

### 7.6 IntegrityNet experiment
Anomaly model compared against deterministic baseline.

### 7.7 ContextNet experiment
Only promote if it materially improves contextual interpretation.

### 7.8 DriveDNA embedding experiment
Post-baseline, not required to replace explicit dimensions.

### 7.9 User post-drive correction
Safe labeling UX + consented contribution pipeline.

### 7.10 BYO cloud commentary
Groq first adapter if desired, dynamic model discovery, secure key, sanitized dossier.

### 7.11 Local AI commentary provider
Architecture + optional model download if schedule/performance allows.

**Exit:** production ML is demonstrably better than deterministic-only where used, and fully auditable.

---

# Stage 8 — Hardening & Public Release

**Milestone M7: Release Candidate → M8: v0.1.0**
**Target:** ~1–1.5 weeks

### 8.1 Android torture matrix
Screen lock/background/restart/GNSS loss/network loss/device conditions.

### 8.2 Battery/performance baseline
Recorder, replay, ML, DB, APK size.

### 8.3 Privacy/security audit
Permissions, RLS, logs, exports, provider payloads, Guardian access.

### 8.4 Database upgrade rehearsal
Previous-build → RC migration with real-like history.

### 8.5 Failure UX pass
Low GPS, corruption, provider failure, invalid key, offline cloud.

### 8.6 Release keystore setup/backup
Maintainer-controlled; never committed.

### 8.7 Signed APK build
ABI strategy, signature verification, checksums.

### 8.8 Clean install test
Fresh user path.

### 8.9 Upgrade install test
Prior signed version with trips/settings → new APK.

### 8.10 GitHub Release
APK(s), checksums, release notes, known issues, model/scoring changes.

**Exit:** strangers can install v0.1.0 from GitHub and use it without developer assistance.

---

# Continuous tracks

These run throughout stages:

- real-drive fixture collection beginning Stage 2;
- privacy/security review;
- docs/ADR maintenance;
- APK/storage/battery measurement;
- regression corpus growth;
- visual polish only after core reliability remains green.
