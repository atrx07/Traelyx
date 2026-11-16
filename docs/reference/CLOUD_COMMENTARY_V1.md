# Optional cloud commentary v1 - M7.10

## When to read

Use for Groq setup, key lifecycle, discovery, minimized requests, approved wording
and replay fallback. This does not authorize sending personal data during QA.

## Scope and versioned contract

The offline procedural narrator remains the default. Optional cloud uses the
user's own Groq credential directly, without a Traelyx account/backend. No new
package, model runtime or mandatory infrastructure cost is introduced.

Version1 lets the provider select among existing reviewed tone lines for already
selected moments. It does not display unrestricted model prose or claim measured
quality/value over procedural narration. No event, score, integrity/ranking,
Guardian state, historical result or production ML decision changes.

The typed dossier is at most8KiB UTF-8 and6 allowlisted moments:

```json
{
  "dossierVersion": 1,
  "wordingVersion": 1,
  "tone": "chill",
  "evidence": "persisted_categories_only_quality_not_assessed_by_narrator",
  "moments": [{
    "category": "Strong braking",
    "context": "first",
    "wordingChoices": ["Strong braking showed up here.", "Replay note: strong braking."]
  }]
}
```

Only trusted category labels, first/repeated context, tone and local catalog lines
are serialized. No route/location, raw sensor/feature/measurement, speed, score,
confidence percentage, private identifier, account/vehicle label, free text,
source snapshot or absolute/relative time. Ordered categories and repetition
context are disclosed; they are not claimed to be anonymous or non-sensitive.
The public provider model ID is separate configuration, not a private identifier.

The fixed system instruction requests only `{"choices":[0]}`: one in-range integer
per moment. Reject extra fields, wrong counts/types, prose, invalid indices,
tool calls, refusals, truncation and mismatched model. Display only the chosen
local lines. Preserve selection, timing/anchors/visibility and evidence indices.
Silent/empty plans send nothing. Choices remain session-only, reset on tone/source
changes, and never become persisted event evidence. Failure restores built-in copy.

## Credentials and consent

You > Commentary engine opens local settings without HTTP. Save/remove keys
explicitly through the existing secure-storage package, in the separate
`TraelyxCommentary` namespace with reset-on-error disabled. No plaintext fallback,
key redisplay, key logging or account sync. Obscure input; disable suggestions,
personalized IME learning and autofill. Clear input on save/backgrounding.
Exclude this namespace from legacy/cloud backup and device transfer, preserving
the Auth/configuration exclusions. Also exclude the plugin's shared
`FlutterSecureKeyStorage.xml` wrapped-key/IV preferences. The generic unavailable secure-store default
is unchanged. Existing local settings hold only enabled/mode/public model/revision;
no database migration. Reject common credential prefixes as custom model IDs.

Key save/replacement clears the catalog and resets permission/model selection.
Removal deletes the key before attempting settings cleanup; storage failure
never claims successful removal. Cloud permission defaults off. Connection/model
refresh is explicit and sends no trip dossier. Network actions require parked
acknowledgment and fresh known idle recorder status. The optional replay section
starts collapsed. Each generation separately shows provider, resolved model,
exact dossier and authentication/network-metadata/cost/retention disclosure,
then requires a checkbox and Send once.

Reviews bind service, configuration revision and generation and are one-use.
Recheck permission/source context before transmission and publication. Key/config
changes, cancellation, app backgrounding and replay-source changes cancel/discard
pending work; check other settings writers too. Do not hold DB write locks across
network/UI waits. These guards are checkpoints, not proof of physical driving
state or a way to recall transmitted data. No automatic retry, alternate-model
send, startup/live-drive/background/timer generation or replay-open request.

## Provider, models and transport

Replaceable `CommentaryProvider` and `CloudHttpTransport` interfaces isolate Groq.
Use only fixed HTTPS `api.groq.com/openai/v1/models` (GET) and
`api.groq.com/openai/v1/chat/completions` (POST). No custom URL, redirects,
tools/search/browsing, streaming output or user prompt extension. Bearer credential
is in the auth header, never URL/body. Bound request body16KiB, streamed response
64KiB, catalog256 entries, transport15 seconds, service action18 seconds. Cancel
and timeout close the client; one network action is pending at a time. Removal/
revocation can interrupt it. No untrusted provider body or raw exception is echoed.

Catalog parsing validates ID/active/context metadata and rejects duplicate IDs.
Bundled `provider-registry.json` recommendation version1 uses ordered text-family
patterns and minimum4,096 context; no permanent model ID. Automatic requires an
explicit catalog refresh in this session. Discovered/custom modes are available.
Family/catalog hints do not guarantee chat/JSON support, quality, price or future
availability; unsupported requests fail without retry. No remote registry is read.

Generation requests JSON-object output, no tools/stream, temperature0.3 and
max completion256. Credential, quota/rate, model unavailable, unsupported,
network/timeout/server, refusal/malformed, cancelled/busy/stale and local-storage
failures use bounded local messages. The original narrator stays available offline.

## Provider policy and validation limits

Groq receives authentication, network metadata and reviewed categorical context.
The user's Groq account controls availability, costs and retention. Do not promise
free usage, zero retention or recall of sent data. Core/offline use requires no
provider, credential, billing method or network.

Official references checked2026-11-16:
[API](https://console.groq.com/docs/api-reference),
[models](https://console.groq.com/docs/models),
[data controls](https://console.groq.com/docs/your-data).

Tests use synthetic credentials and mocked HTTP/providers. Separate-package
emulator QA preserves existing app/accounts/recordings; follow the
[Pixel runbook](ANDROID_EMULATOR_WORKFLOW.md). Record performed checks in aggregate
evidence. Mock/emulator checks do not establish live account/model availability,
natural-language quality, prices, vehicle/OEM/background or battery acceptance.
Prior model gates remain open/deferred. M7.11 needs separate authorization.
