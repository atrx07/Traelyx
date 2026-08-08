# Traelyx — Product Identity & Permanent Constraints

## When to read

Read this document when beginning a substantial task, making product/architecture tradeoffs, evaluating scope, or deciding whether a proposed feature belongs in the project.

For a tiny isolated implementation change whose intent is already unambiguous, consult only the relevant sections if needed.

## 1. Mission

Build Traelyx as an original, open-source, local-first driving telemetry platform that turns ordinary phone sensors into trustworthy, explainable, entertaining analysis of how a vehicle was driven.

The product should feel like a fusion of:

- serious telemetry instrumentation;
- personal performance analytics;
- social competition that does not incentivize reckless driving;
- safety networking;
- rich, replayable visual storytelling;
- a transparent engineering project that technically curious users want to inspect.

It must be useful even when completely offline and even when the user never creates an account.

## 2. Signature product ideas

Traelyx is differentiated by the combination of:

### Drive DNA
A multidimensional, evolving fingerprint of driving behavior rather than one mysterious overall score. Example dimensions include smoothness, braking control, acceleration control, cornering control, anticipation, consistency, and other validated traits.

### Explainable scoring
Every important score must be inspectable. The user can see which evidence influenced it, which algorithm/model version produced supporting evidence, what confidence applied, and how penalties/bonuses were derived.

### Telemetry confidence
Sensor quality is first-class. The application should communicate whether a measurement is trustworthy rather than presenting GPS/IMU noise as scientific certainty.

### Guardian / Partner Connect
An opt-in trusted-contact safety system based on explicit permissions and event-triggered alerts, not default surveillance.

### Integrity auditing
Trips can be evaluated for suspicious, inconsistent, low-quality, mock-location, or corrupted data before being ranked. Integrity outcomes should be cautious labels such as Verified / Questionable / Unranked rather than unsupported accusations.

### Animated telemetry replay
A synchronized route/map replay in which map marker, graphs, event markers, Drive DNA evidence, and optional animated road-commentary bubbles all share a single time axis.

### Road commentary
A fun optional narrative layer attached to real telemetry events. Commentary may be procedural, locally generated, or generated through a user-supplied cloud provider. Humor must not alter safety classification.

## 3. What Traelyx is not

- Not a TripRank clone.
- Not a navigation application.
- Not primarily a fleet-management tool.
- Not a racing application.
- Not a maximum-speed leaderboard.
- Not a cloud-first tracker that requires an account to function.
- Not a black-box "AI judges your driving" product.
- Not an app that sells or monetizes location history.
- Not an excuse to bundle a multi-gigabyte model into every installation.

## 4. Cost constraint

The MVP must be buildable and operable by the maintainer at **zero mandatory monetary cost**.

Preferred strategy:

- open-source frameworks;
- free-tier cloud services where online features require them;
- local processing wherever practical;
- user-supplied API keys for optional third-party generative features;
- no paid maps dependency;
- GitHub-hosted code and releases;
- no Google Play / App Store fees for the initial project era.

If a free cloud tier becomes inadequate, the system should degrade gracefully or remain self-hostable/replaceable rather than surprise the maintainer with mandatory billing.

## 5. Distribution

Primary distribution before later commercial/revenue-producing work:

- GitHub Releases;
- signed Android APKs;
- release notes and checksums;
- possible future independent landing page as a separate project.

No Play Store or App Store publication is required for the MVP.

## 6. Platform strategy

Primary platform: **Android**.

Future: iOS may be supported if justified, but Android reliability and quality take precedence in the MVP.

Flutter is used for portable application/UI logic. Native Kotlin is used where Android lifecycle, foreground tracking, sensor acquisition, and platform reliability require deeper control.

## 7. Product principles

### Local-first
The phone is the authoritative recorder for raw trip data. Cloud features enhance the product; they do not define whether it works.

### User ownership
Users can inspect, export, archive, or delete their own data. Location history is private by default.

### Earn trust before asking for an account
The application must allow a user to record and analyze a trip without signing up. Account creation is requested only when the user asks for online capabilities such as sync, social rankings, or Guardian Connect.

### Explain important numbers
Every consequential number should be tappable or otherwise inspectable to reveal its meaning and evidence.

### Fun without rewarding danger
The app may joke about a severe event, but it must not celebrate dangerous public-road behavior through scoring or ranking incentives.

### Replace providers
Models, map providers, cloud AI providers, and similar external services change unpredictably. Core logic must not depend on a single provider's permanent availability.

### Measured claims
Do not label telemetry "accurate" without basis. Communicate confidence, limitations, and calibration state.

## 8. Intellectual property boundary

Competitor observation may be used for high-level market understanding only.

Do not:

- copy interface layouts or distinctive visual identity;
- replicate proprietary text/copy;
- reproduce proprietary scoring formulas;
- reuse competitor assets;
- decompile or lift implementation details;
- present a confusingly similar name, icon, or brand.

Record original design reasoning and ADRs so the project has a clear first-principles development trail.

## 9. Success criteria for v0.1

A technically curious user can:

1. install a signed APK from GitHub;
2. use it without an account;
3. record a real drive reliably with the screen locked;
4. inspect a clean trip summary and Drive DNA breakdown;
5. replay the drive with synchronized route, graphs, and events;
6. understand why notable events/scores were assigned;
7. see telemetry confidence/integrity information;
8. optionally create an account for online functionality;
9. optionally connect a trusted contact;
10. optionally enable humorous procedural or AI commentary;
11. export/delete their data;
12. understand what data leaves the device.
