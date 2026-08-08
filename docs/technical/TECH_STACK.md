# TECH_STACK.md — Chosen Stack & Responsibilities

## When to read

Read during project bootstrap, dependency selection, major refactors, or when deciding where a new behavior belongs. Do not read for ordinary feature work once the relevant subsystem is clear.

## Validated bootstrap baseline

Validated on 2026-08-08:

- Flutter stable 3.44.9 with Dart 3.12.2; the package declares Dart `^3.12.2`.
- Android SDK 36.1 with accepted licenses; compile, target, minimum SDK, and NDK versions remain delegated to the compatible Flutter stable toolchain instead of being duplicated as stale constants.
- Android Gradle Plugin 9.0.1, Gradle 9.1.0, and Kotlin 2.3.20 from the generated Flutter Android project.
- Android Studio JDK 21 runs the build while Java/Kotlin source and bytecode targets remain JVM 17.
- Python remains the ML/training environment; an isolated, reproducible environment will be established when ML work begins rather than during application bootstrap.

This is a reproducible known-good baseline, not a permanent prohibition on upgrades. Toolchain changes require the relevant analysis, tests, and Android build to pass before the baseline is updated.

## App/UI

- **Flutter + Dart** — primary application/UI framework.
- **Riverpod** — state management, especially asynchronous/reactive recorder/analysis state.
- **go_router** — navigation/deep-link routing.
- **fl_chart or custom painters** — telemetry charts; final choice by prototype/performance.

## Local persistence

- **Drift + SQLite** — typed relational app data, migrations, reactive history.
- **Compact telemetry chunks** — high-frequency raw data, indexed by SQLite.
- **Platform secure storage** (e.g., a maintained Flutter secure-storage implementation) — API keys/session-sensitive local secrets where SDK does not already manage them securely.

## Native Android

- **Kotlin**.
- Foreground service for trip recording.
- Android location/GNSS APIs.
- `SensorManager` for IMU.
- Platform bridge to Flutter.

A tracking SDK may be evaluated for acceleration, but native ownership remains the architectural baseline until benchmarks prove otherwise.

## Cloud

- **Supabase** free tier for optional connected features.
- PostgreSQL + Row Level Security.
- Auth.
- Edge/server logic only where a connected feature actually requires it.

Raw telemetry remains local by default.

## Maps

- Provider-neutral abstraction.
- Evaluate **MapLibre Flutter** and/or **flutter_map**.
- Tile source must be replaceable and comply with provider policy.

## ML training

- Python.
- PyTorch.
- NumPy/Polars/Pandas as appropriate.
- SciPy.
- scikit-learn.
- Optuna only for disciplined, reproducible tuning where useful.

## ML edge deployment

- Quantized compact models.
- Candidate runtime: ExecuTorch; benchmark against alternatives before lock-in.
- CPU baseline must be sufficient; GPU/NPU acceleration optional.

## Commentary

- Built-in procedural engine.
- Optional downloadable local model provider.
- Optional cloud BYO-key provider adapters, beginning with Groq if still useful when implemented.
- Dynamic model discovery/recommendation rather than fixed permanent IDs.

## CI/release

- GitHub Actions for code quality/build validation.
- GitHub Releases for APK distribution.
- Maintainer-local final signing initially.
- SHA-256 checksums.

## Avoid by default

- paid mandatory APIs;
- Firebase-only architecture unless a future ADR replaces Supabase;
- proprietary map lock-in;
- cloud-only telemetry processing;
- giant bundled ML/LLM artifacts;
- custom authentication cryptography;
- business logic embedded in widgets.
