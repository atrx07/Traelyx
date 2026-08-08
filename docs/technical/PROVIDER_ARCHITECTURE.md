# PROVIDER_ARCHITECTURE.md — External Provider & Model Abstraction

## When to read

Read when implementing/changing cloud AI providers, model discovery, map/network providers, API-key storage, provider fallback, or remotely updateable provider recommendations.

## 1. Problem

External providers change models, pricing, rate limits, endpoints, and availability frequently. Core app logic must not assume today's provider catalog is permanent.

## 2. Commentary interface

Conceptual contract:

```text
CommentaryProvider
- id / displayName
- credentialRequirements()
- validateCredential()
- listModels()
- capabilities()
- generateCommentary(EventDossier, GenerationOptions)
- normalizeError()
```

All providers return a common domain result or normalized error.

## 3. Dynamic model selection

UI modes:

- **Automatic / Recommended** — choose from available models based on project recommendation/capabilities.
- **User-selected discovered model**.
- **Advanced custom model ID** where provider supports it.

Do not hardcode one Llama/GPT/Qwen ID as permanent default.

## 4. Recommendation registry

A small non-secret registry may contain:

- provider ID;
- preferred model patterns;
- known deprecated IDs;
- capability hints;
- minimum context/output requirements;
- commentary quality notes.

The registry should be updateable without invasive code changes. If remotely fetched, it must be signed/validated or treated as untrusted configuration and have a bundled fallback.

## 5. User API keys

- stored only in platform secure storage;
- never in SQLite settings table if plaintext;
- never uploaded to Supabase by default;
- never logged;
- test connection masks credential;
- "Remove key" deletes locally.

## 6. Privacy boundary

Provider receives sanitized event dossier, not full raw telemetry/route, unless a future feature obtains specific consent.

## 7. Fallback

Normalized failure categories:

- invalid credential;
- rate limit/quota;
- model unavailable/deprecated;
- network timeout;
- provider server error;
- malformed response;
- policy/refusal;
- unsupported capability.

Fallback ultimately reaches procedural narrator.

## 8. Local model provider

Treat downloadable local inference as another provider implementation:

- model registry/manifest;
- size before install;
- checksum/signature;
- runtime capability;
- remove model;
- no network required.

## 9. Provider tests

Use mocked HTTP fixtures for contract/error behavior. Never place real API keys in CI fixtures.
