# ADR-0042 - Reviewed cloud wording and separate local credentials

**Status:** Accepted for M7.10
**Date:** 2026-11-16

## Decision

Use an optional direct Groq adapter behind provider/HTTP interfaces, the existing
secure-storage package and a separate no-backup credential namespace, excluding
the plugin's shared wrapped-key preferences as well. Default-off
permission and public model choices are non-secret local settings. Never tie keys
to a Traelyx account/backend. Key replacement resets permission; configuration/key
changes cancel/discard pending work. No migration or new package.

Use explicit discovery and a bundled model-family registry, not a permanent model
ID. Custom IDs remain capability-unverified. Every generation needs an exact
minimized-dossier review, known idle recorder and parked acknowledgment. Use fixed
HTTPS endpoints, no redirects, bounded bytes/time, one-use reviews, no retries or
background generation. Keep procedural narration fully available offline.

Version1 accepts indices into reviewed tone lines only. Prompts/keyword filters
cannot reliably make unrestricted model prose safe; fail-closed catalog output
prevents new facts/unsafe instructions entering replay. Preserve all deterministic
moment selection/timing/evidence. This is a deliberately limited first cloud
capability, not free-form quality acceptance. No scoring, Guardian, safety,
production ML or historical interpretation depends on the provider.

Exclude route, raw sensors, measurements, private IDs and times. Disclose provider
authentication/network metadata, categorical context and account-controlled costs/
retention; do not promise free usage, zero retention or recall of sent requests.
Future broader generation needs separate evaluated safety/output governance.

See [the versioned contract](../reference/CLOUD_COMMENTARY_V1.md).
