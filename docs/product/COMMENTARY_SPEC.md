# COMMENTARY_SPEC.md — Road Commentary System

## When to read

Read for procedural commentary, road bubbles, AI/local/cloud narration, provider prompts, tone settings, privacy of AI requests, or replay commentary selection.

## 1. Purpose

Commentary turns already-decided telemetry events into concise, entertaining narration. It is a presentation layer, not a measurement or scoring layer.

Pipeline:

```text
Telemetry / Event / Score evidence
            │
            ▼
Commentary event selector / interestingness
            │
            ▼
Sanitized Event Dossier
            │
   ┌────────┼──────────┐
   ▼        ▼          ▼
Procedural  Local AI   Cloud provider
   │        │          │
   └────────┴──────────┘
            ▼
Tone/safety filter
            ▼
Replay bubble / trip recap
```

## 2. Engines

### Engine A — Procedural narrator (default)

- bundled;
- fully offline;
- zero model download;
- deterministic/testable with seeded variation;
- fastest fallback;
- supports multiple tone packs.

The intelligence is in selecting noteworthy context and avoiding repetition, not generating every sentence from scratch.

### Engine B — Downloadable local model (optional)

- never required for core app;
- separately downloaded by user;
- target small quantized models appropriate for short style generation;
- delete/uninstall model independently from app;
- size displayed before download;
- provider/runtime abstracted.

Avoid bundling an 8B/70B-class model with the APK. A 1–3B-class quantized model may be more appropriate if quality is sufficient, but selection must be benchmark-driven rather than fixed here.

### Engine C — BYO cloud provider (optional/geek mode)

- user supplies own API key;
- credential stored securely on-device;
- direct request from device where architecture/security permits;
- project backend should not need to receive/store the user's provider key;
- dynamic model discovery when provider supports it;
- provider and model are replaceable.

Groq may be implemented first, but no particular Llama/GPT/Qwen model ID is permanent. Providers routinely deprecate models.

## 3. Event dossier

Cloud/local generators should receive structured interpreted context, not raw sensor firehose.

Example shape:

```json
{
  "event_type": "high_load_corner",
  "direction": "left",
  "speed_kmh": 84,
  "lateral_g": 0.71,
  "control_score": 91,
  "severity": 0.78,
  "confidence": 0.97,
  "personal_percentile": 0.96,
  "recent_context": ["hard_acceleration", "smooth_section"],
  "tone": "unhinged"
}
```

No precise GPS location is required for normal commentary.

## 4. Privacy

Default cloud request excludes:

- latitude/longitude;
- home/work labels;
- full route geometry;
- account email/name;
- vehicle registration/VIN;
- raw accelerometer/gyro stream;
- provider key from logs.

The UI must disclose what is transmitted before cloud commentary is enabled.

## 5. Tone packs

Initial candidates:

### Analyst
Short technical description.

### Chill
Casual and lightly expressive.

### Supportive
Highlights improvement/recovery without false praise.

### Roast
Playful criticism, no harassment or identity-based insult.

### Unhinged
More chaotic internet-style humor while still respecting safety rules.

### Silent
No bubbles.

## 6. Contextual continuity

The narrator may track recent event categories to avoid repetitive independent lines.

Example progression:

- first high-load event → "that was spicy"
- another shortly after → "again??"
- repeated pattern → "okay this is apparently a personality trait now"

This can be implemented procedurally before generative AI.

## 7. Commentary selection

Not every event deserves a bubble. Select based on:

- severity;
- control quality;
- confidence;
- novelty;
- personal-baseline deviation;
- spacing/cooldown;
- user tone preferences.

The selector may use an interpretable ranking model later, but a deterministic baseline is sufficient for MVP.

## 8. Safety rules

- Never encourage repeating dangerous behavior.
- Never claim the driver is dead/injured.
- Never instruct the driver to interact with the app while moving.
- Never let generated commentary alter event labels or scores.
- Severe crash/Guardian safety messaging uses separate trusted templates.
- Avoid "achievement" language for dangerous maxima.

## 9. Latency / failure

During replay, cloud text may stream word-by-word if provider supports it. The UI must handle:

- timeout;
- quota/rate limit;
- model removed;
- invalid key;
- network loss;
- malformed response.

Fallback chain:

```text
preferred cloud/local generation
   ↓ fail
alternate configured model/provider (if user enabled)
   ↓ fail
procedural narrator
```

## 10. Model quality evaluation

Commentary models should be evaluated for the actual task, not only benchmark capability.

Evaluate:

- naturalness;
- warmth/human conversational feel;
- short-form humor;
- context use;
- repetition;
- corny/assistant-like language leakage;
- safety adherence;
- latency/cost to user;
- output-length compliance.

Maintain a fixed commentary evaluation set across event/tone combinations.

## 11. M5.7 procedural baseline

M5.7 ships commentary version 1 as bundled deterministic presentation logic only. It has no LLM, model runtime, provider, API key, account, endpoint, dependency, or network fallback. Analyst, Chill, Supportive, Roast, and Unhinged select safe short-form copy; Silent emits no moments. Tone is session-only and defaults to Chill.

Only ten explicitly allowlisted persisted event types are eligible. Unknown types fail closed and their values are never echoed. Version 1 ranks candidates using event-type interestingness and category novelty, applies a ten-second spacing cooldown, uses a sixty-second recent-category window for repetition context, and displays at most six moments. Seeded variation may change copy but not event selection. Severity, control quality, confidence, or personal-baseline deviation may inform a future version only when those values are authoritatively persisted and governed; M5.7 never infers or fabricates them.

Visibility and reveal progress derive from the existing replay clock. A moment may draw on the route only when the persisted event midpoint resolves to a verified marker; otherwise it remains timeline-only. Bubble/evidence taps pause playback and reveal only the persisted event label and recorder-relative time range. Commentary never alters events, integrity, scores, safety transitions, or historical evidence, and it never exposes coordinates, trip identifiers, raw telemetry, paths, or provider metadata in copy, semantics, or logs.
