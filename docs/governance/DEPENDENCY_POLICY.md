# DEPENDENCY_POLICY.md — Third-Party Dependency Gate

## When to read

Read before adding/replacing a package, SDK, native library, hosted API, map service, model runtime, or cloud dependency.

## 1. Default preference

Prefer mature, maintained, open-source dependencies with permissive/project-compatible licenses and no mandatory paid service.

## 2. Required evaluation

For each meaningful dependency record/check:

- purpose and why built-in/existing code is insufficient;
- license compatibility;
- maintenance/activity;
- known security concerns;
- transitive dependencies;
- Android min/target SDK implications;
- native binary size impact;
- battery/performance impact if runtime-critical;
- network/data collected;
- paid tier/billing requirements;
- vendor lock-in risk;
- replacement strategy.

## 3. Zero-cost rule

A dependency cannot make a core MVP feature require payment.

Optional user-funded/BYO-key capabilities are allowed only if the core feature has a free/local fallback.

## 4. Telemetry/analytics SDKs

Avoid third-party tracking/analytics SDKs that collect user/device/location data merely for product analytics. Prefer no analytics or privacy-respecting self-controlled instrumentation.

## 5. Tracking SDK exception

An open-source background-location SDK such as Traccar's may be prototyped if it materially accelerates development, but production adoption versus our Kotlin service requires an ADR and reliability/control comparison.

## 6. AI/model dependencies

Do not couple app domain logic to one hosted model SDK when ordinary HTTP/provider abstraction is sufficient.

## 7. Dependency removal

Adapters should isolate optional providers so a provider/package can be removed without rewriting core telemetry/scoring logic.
