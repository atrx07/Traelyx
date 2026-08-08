# Traelyx — MVP Milestones & Executable Substeps

## Planning assumptions

Feature-rich agent-assisted MVP:

- focused/intensive: ~12–14 weeks;
- part-time/college schedule: ~14–20 calendar weeks;
- internal prototype can appear around week 6;
- usable alpha around week 10;
- ~50 major executable substeps.

Milestones may overlap, especially data collection/ML. Estimates are not promises.

---

# M0 — Project Bootstrap

**Target:** ~3–5 focused days

### M0.1 Confirm identity
- product name: `Traelyx`;
- repository and Flutter project name: `traelyx`;
- Android namespace: `io.github.atrx07.traelyx`;
- Android application ID: `io.github.atrx07.traelyx`;
- initial versioning convention;
- review naming conflicts before public release.

### M0.2 Initialize repository
- Flutter Android project;
- Git;
- directory responsibility boundaries;
- copy governance pack.

### M0.3 Toolchain pinning
- Flutter/Dart constraints;
- Android compile/target/min SDK decisions;
- JDK/Gradle setup;
- Python ML environment approach.

### M0.4 Quality commands
- formatter;
- static analysis;
- Flutter tests;
- Kotlin tests;
- JSON/YAML validation.

### M0.5 CI foundation
- GitHub Actions analysis/tests;
- debug/release-validation build without private signing key;
- secret scanning;
- artifact size reporting.

### M0.6 Core architecture skeleton
- Flutter feature/core modules;
- native bridge skeleton;
- Drift setup;
- provider/map interfaces.

**Exit:** app launches; CI green; docs discoverable; no secret/signing material in repo.

---

# M1 — Application Foundation

**Target:** ~4–6 focused days

### M1.1 Design tokens/theme
Dark-first semantic tokens, typography, spacing, motion primitives.

### M1.2 Navigation
Drive / Trips / DNA / Social / You skeleton with deep-link-safe routing.

### M1.3 Local settings
Non-secret settings persistence + secure-storage abstraction for secrets.

### M1.4 Drift schema v1
Vehicles, trips, chunks index, events, scores, baselines, sync queue.

### M1.5 Migration harness
Database upgrade fixture tests before data exists in the wild.

### M1.6 Diagnostics shell
App/build info, DB version, recorder state placeholder, storage breakdown.

**Exit:** clean local-first app shell with reliable persistence foundation.

---

# M2 — Native Recording Engine

**Target:** ~1.5–2 weeks

### M2.1 Foreground service lifecycle
Start/stop/query/recovery and persistent active-trip state.

### M2.2 GNSS acquisition
Location/speed/bearing/accuracy/source timestamps and health counters.

### M2.3 IMU acquisition
Accelerometer/gyro source timestamps, accuracy, batching.

### M2.4 Crash-safe buffering
Bounded buffers + durable telemetry chunks + checksum/atomic writes.

### M2.5 Flutter↔Kotlin bridge
Commands + recorder status/live health without requiring Flutter for acquisition.

### M2.6 Permissions/onboarding
Contextual Android permissions and foreground notification.

### M2.7 Service recovery tests
Screen lock, background, activity recreate, network loss, GNSS loss.

### M2.8 First real-drive fixture
30–60 minute trip; preserve/export synchronized raw timeline.

**Exit:** real physical drive can be recorded with screen locked and recovered intact.

---

# M3 — Telemetry Processing Engine

**Target:** ~1–2 weeks

### M3.1 Decoder/resampler
Versioned raw chunk decoder and time alignment.

### M3.2 GNSS sanity filtering
Accuracy/gap/impossible jump handling, distance accumulation.

### M3.3 IMU calibration
Bias/stationary calibration path and quality state.

### M3.4 Orientation/frame transform
Device → world/vehicle frame with explicit confidence.

### M3.5 Derived channels
Filtered speed, longitudinal/lateral/vertical accel, jerk, yaw/heading change.

### M3.6 Telemetry confidence v1
Subcomponents + explainable aggregate eligibility.

### M3.7 Replay channel generator
Reduced synchronized timeline optimized for display.

### M3.8 Fixture regression corpus
Straight/corner/brake/pothole/phone-move/GPS-loss cases.

**Exit:** derived telemetry is explainable, confidence-aware, and replayable.

---

# M4 — Deterministic Intelligence v1

**Target:** ~1–1.5 weeks

### M4.1 Event taxonomy implementation
Strong accel/brake, lateral load, abrupt transitions, road impact, phone moved.

### M4.2 Event merge/debounce
Coherent maneuver-level events rather than window spam.

### M4.3 Integrity rules v1
Cross-sensor consistency, mock signal, impossible jumps, corrupted chunks.

### M4.4 Scoring v1
Explicit dimension formulas with confidence weighting and audit contributions.

### M4.5 Drive DNA baseline
Smoothness/braking/acceleration/cornering/consistency.

### M4.6 Personal/vehicle baseline lifecycle
Emerging/established/recalibrating behavior.

### M4.7 Explanation data
Every score/event has a user-facing reason path.

**Exit:** useful analysis works with no ML dependency.

---

# M5 — Experience & Replay

**Target:** ~1.5–2 weeks

### M5.1 Ready/Drive screen
Glanceable recorder health and safe minimal live mode.

### M5.2 Trip history/result
Shareable rich result hierarchy with confidence/integrity.

### M5.3 Drive DNA visual
Original signature/ring treatment, trends, insufficient-data states.

### M5.4 Map abstraction + route rendering
Provider-neutral map component and cache controls.

### M5.5 Synchronized replay clock
Map + graphs + events tied to one timeline.

### M5.6 Replay animations
Camera framing, marker/path progress, event pulses, pause/scrub/speed.

### M5.7 Procedural road commentary
Tone packs, context/cooldown/interestingness, anchored bubbles.

### M5.8 Reduced-motion/accessibility
Alternative transitions and accessible severity/metrics.

### M5.9 Storage manager/export
Raw retention controls, map cache, debug export/anonymization.

**Exit:** app is fun to use/replay, not merely technically correct.

---

# M6 — Connected / Social Layer

**Target:** ~1–1.5 weeks

### M6.1 Supabase project/schema/RLS
Free-tier connected layer with explicit policies.

### M6.2 Auth UX
Continue locally + sign-in methods + secure sessions.

### M6.3 Local→account migration
Optional compact summary sync without raw-route auto-upload.

### M6.4 Profiles/vehicles sync
Sanitized public/private separation.

### M6.5 Friends/social
Basic relationship capability with abuse/privacy controls.

### M6.6 Safe leaderboards
Smoothness/consistency/improvement; server-validated eligibility.

### M6.7 Guardian pairing
Short-lived token/QR, acceptance, granular permissions.

### M6.8 Guardian alerts
Event-triggered severe/crash-like alert flow + deduplication.

**Exit:** online features add value without breaking local-first privacy.

---

# M7 — ML & Advanced Commentary

**Target:** ~2–3 weeks of engineering plus ongoing data collection

### M7.1 Dataset registry/import
Public licensed data + project fixture corpus.

### M7.2 EventNet baseline
TCN candidate with driver-held-out evaluation.

### M7.3 Calibration and error analysis
Per-class metrics, false severe events/hour, confidence calibration.

### M7.4 Mobile export/inference
Quantized model and on-device benchmark.

### M7.5 Hybrid event integration
Rules + EventNet evidence + audit record.

### M7.6 IntegrityNet experiment
Anomaly model compared against deterministic baseline.

### M7.7 ContextNet experiment
Only promote if it materially improves contextual interpretation.

### M7.8 DriveDNA embedding experiment
Post-baseline, not required to replace explicit dimensions.

### M7.9 User post-drive correction
Safe labeling UX + consented contribution pipeline.

### M7.10 BYO cloud commentary
Groq first adapter if desired, dynamic model discovery, secure key, sanitized dossier.

### M7.11 Local AI commentary provider
Architecture + optional model download if schedule/performance allows.

**Exit:** production ML is demonstrably better than deterministic-only where used, and fully auditable.

---

# M8 — Hardening & Public Release

**Target:** ~1–1.5 weeks

### M8.1 Android torture matrix
Screen lock/background/restart/GNSS loss/network loss/device conditions.

### M8.2 Battery/performance baseline
Recorder, replay, ML, DB, APK size.

### M8.3 Privacy/security audit
Permissions, RLS, logs, exports, provider payloads, Guardian access.

### M8.4 Database upgrade rehearsal
Previous-build → RC migration with real-like history.

### M8.5 Failure UX pass
Low GPS, corruption, provider failure, invalid key, offline cloud.

### M8.6 Release keystore setup/backup
Maintainer-controlled; never committed.

### M8.7 Signed APK build
ABI strategy, signature verification, checksums.

### M8.8 Clean install test
Fresh user path.

### M8.9 Upgrade install test
Prior signed version with trips/settings → new APK.

### M8.10 GitHub Release
APK(s), checksums, release notes, known issues, model/scoring changes.

**Exit:** strangers can install v0.1.0 from GitHub and use it without developer assistance.

---

# Continuous tracks

These run throughout milestones:

- real-drive fixture collection beginning M2;
- privacy/security review;
- docs/ADR maintenance;
- APK/storage/battery measurement;
- regression corpus growth;
- visual polish only after core reliability remains green.
